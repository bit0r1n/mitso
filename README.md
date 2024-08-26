# 🍉 MITSO Parser
Парсер данных из сервисов МИТСО

## Установка
Установка производится запуском `nimble install https://github.com/bit0r1n/mitso`

Для работы с библиотекой при компиляции необходимо добавить параметр `-d:ssl` для выполнения HTTPS запросов

## Пример использования

### Получение расписания группы (модуль `schedule`)

```nim
import asyncdispatch, sequtils, strutils
import mitso/[schedule, helpers, typedefs]

proc main() {.async.} =
  let
    site = newScheduleSite() # Создание объекта сайта
    fetchedGroups = await site.loadGroups() # Выполняет инициализацию объекта сайта и загрузку групп
    # Может вылезти ошибка рейтлимита, так что стоит также отлавливать `ScheduleServiceError`
    #[
      Что делает loadGroups(site):
        
      await site.loadPage() # обновление базового контента (с него читаются факультеты) и CSRF токена
      let
        faculties = site.getFaculties() # Получение факультетов с полученного контента
      result = site.getGroups(faculties) # Получение групп из указанных факультетов
    ]#

  echo "Введи номер группы"
  let
    input = readLine(stdin)
    groups = fetchedGroups.filter do (x: Group) -> bool: x.display.contains(input)

  echo if groups.len == 0: "Группы не нашлось =(" else: "Найдены группы: " & $groups

waitFor main()
```

### Получение баланса студента (модуль `account`)

```nim
import asyncdispatch
import mitso/[account, typedefs]

proc main() {.async.} =
  echo "Введи номер счета"
  let input = readLine(stdin)

  try:
    let account = await fetchAccount(input, input)

    echo account.fullName
    echo "Баланс: ", account.balance

  except AccountFailedLoginError:
    echo "Не удалось войти в аккаунт"

waitFor main()
```
