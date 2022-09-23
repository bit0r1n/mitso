# 🍉 MITSO Scheldue Bot
[Telegram бот](https://t.me/mitsoScheldueBot) для просмотра расписания занятий университета МИТСО

### TODO
 * [Bot] Сохранение и использование дней в БД
 * [Lib] Исправление SIGSEGV в некоторых случаях (а каких .)

# Запуск
**Для работы бота необходима база данных Redis**
## В своем окружении
### Установка Nim
Требуется установить язык [Nim](https://nim-lang.org/install.html)
### Сборка приложения
Сборка производится командой `nimble build` в директории проекта. Все аругменты автоматически подставляются (посмотреть их можно в [mitso.nims](src/mitso.nims))
### Запуск
Запуск производится запуском скомпилированной программы
**Для запуска программы необходимо указать переменные среды**
 * `BOT_TOKEN` - токен Telegram бота
 * `DB_HOST` - хост базы Redis
 * `DB_PORT` - порт базы Redis
 * `DB_AUTH` (опционально) - пароль для доступа к Redis базе
 * `DB_USER` (опционально) - имя пользователя для доступа к Redis базе
## Docker
### Сборка образа
Собрать контейнер можно с помощью команды `docker build -t mitso .`
### Запуск
Простой запуск контейнера с приложением производится командой `docker run -e BOT_TOKEN=... -e DB_HOST=... -e DB_PORT=... mitso`

# Использование в своем приложении
## Установка
Для установки пакета используй `nimble install https://github.com/bit0r1n/mitso`
## Пример использования
```nim
import asyncdispatch, sequtils, strutils
import mitso

proc main() {.async.} =
  let site = newSite()
  discard await site.init()

  echo "Введи номер группы"
  let
    input = readLine(stdin)
    groups = site.groups.filter do (x: Group) -> bool: x.display.contains(input)

  echo if groups.len == 0: "Группы не нашлось =(" else: "Найдены группы: " & $groups

waitFor main()
```

**Для запуска необходимы параметры `--threads:on -d:ssl` Эти параметры необходимо указать для поддержки многопоточности при парсинге и SSL**