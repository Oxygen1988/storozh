#!/bin/bash
# Внешний сторож: снаружи проверяет сервер и бота, при смене состояния пишет в Telegram.
# Адрес, путь и токен — только в секретах репозитория (HOST, URL, TG_TOKEN, TG_CHAT).
set -u
FILE=sostoyanie.txt
POPYTOK=3
PAUZA=15

server_zhiv() {
  timeout 10 bash -c "</dev/tcp/$HOST/22" 2>/dev/null
}

# Вебхук отвечает 405 на GET, пока бот жив; 502/504 — бот лежит, nginx жив; 000 — нет ответа.
kod_bota() {
  curl -s -o /dev/null -m 15 -w '%{http_code}' "$URL" 2>/dev/null || true
}

proverit() {
  if ! server_zhiv; then echo "server"; return; fi
  local k; k=$(kod_bota)
  if [[ "$k" =~ ^[234][0-9][0-9]$ ]]; then echo "ok"; else echo "bot:$k"; fi
}

tg() {
  curl -s -m 30 --data-urlencode "chat_id=$TG_CHAT" --data-urlencode "text=$1" \
    "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" -o /dev/null -w 'telegram %{http_code}\n'
}

if [ "${TEST:-}" = "1" ]; then
  tg "🛡 Сторож VPN подключён. Сейчас: $(proverit). Проверка раз в ~5 мин, пишу только при смене состояния."
  exit 0
fi

# Повторы: тревога, только если плохо во всех попытках подряд.
sejchas=""
for i in $(seq 1 $POPYTOK); do
  sejchas=$(proverit)
  [ "$sejchas" = "ok" ] && break
  [ "$i" -lt "$POPYTOK" ] && sleep $PAUZA
done
echo "состояние: $sejchas"

bylo="ok"; s_kakih=$(date +%s)
[ -f "$FILE" ] && read -r bylo s_kakih < "$FILE"
seychas_t=$(date +%s)
izm=0

if [ "${sejchas%%:*}" != "${bylo%%:*}" ]; then
  dlit=$(( (seychas_t - s_kakih) / 60 ))
  case "$sejchas" in
    server) tg "🔴 VPN-СЕРВЕР НЕ ОТВЕЧАЕТ ($POPYTOK попытки). Клиенты без VPN. Если пропал интернет на ПК — выключи туннель Dom2." ;;
    bot:*)  tg "🟠 Сервер жив, но бот VPN не отвечает (HTTP ${sejchas#bot:}). VPN у клиентов работает, оплаты и выдача ключей — нет." ;;
    ok)     tg "🟢 Всё снова работает. Было: $bylo, примерно $dlit мин." ;;
  esac
  echo "$sejchas $seychas_t" > "$FILE"
  izm=1
fi

# GitHub выключает расписание через 60 дней без коммитов — раз в 20 дней отметка жизни.
posledniy=$(git log -1 --format=%ct 2>/dev/null || echo 0)
if [ $izm = 0 ] && [ $(( seychas_t - posledniy )) -gt $(( 20 * 86400 )) ]; then
  date -u +%FT%TZ > zhiv.txt
  izm=1
fi

if [ $izm = 1 ]; then
  git config user.name storozh
  git config user.email storozh@users.noreply.github.com
  git add -A && git commit -qm "состояние: $sejchas" && git push -q
fi
exit 0
