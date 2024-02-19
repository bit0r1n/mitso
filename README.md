# 🍉 MITSO Parser
Парсер данных из сервисов МИТСО

## Установка
Установка производится запуском `nimble install https://github.com/bit0r1n/mitso`

Для работы с библиотекой при компиляции необходимо добавить параметр `-d:ssl` для выполнения запросов через HTTPS

## Пример использования

### Получение расписания группы (модуль `schedule`)

```nim
import asyncdispatch, sequtils, strutils
import mitso/[schedule, helpers, typedefs]

proc main() {.async.} =
  let site = newScheduleSite()
  discard await site.loadGroups() #[ Выполняет инициализацию объекта сайта, т.е.
  загружает базовый контент страницы с сохранением куки, загружает все факультеты, группы ]#

  echo "Введи номер группы"
  let
    input = readLine(stdin)
    groups = site.groups.filter do (x: Group) -> bool: x.display.contains(input)

  echo if groups.len == 0: "Группы не нашлось =(" else: "Найдены группы: " & $groups

waitFor main()
```

Для работы с парсом занятий/групп используется многопоточность, что обязует использовать параметр `--threads:on` при компиляции

### Получение баланса студента (модуль `account`)

```nim
import asyncdispatch, options
import mitso/[account, helpers, typedefs]

proc main() {.async.} =
  echo "Введи номер счета"

  let
    account = newAccount()
    input = readLine(stdin)

  try:
    await account.login(input, input)

    echo account.fullName.get
    echo "Баланс: " & $account.balance.get

  except AccountFailedLoginError:
    echo "Не удалось войти в аккаунт"

waitFor main()
```
