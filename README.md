# storozh

Внешний сторож: раз в ~5 минут GitHub Actions проверяет сервер (TCP) и бота (HTTP) и пишет в Telegram только при смене состояния. Адреса и токены — в секретах репозитория.

Проверочное сообщение: Actions → storozh → Run workflow → test = 1.
