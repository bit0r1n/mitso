# 🍉 MITSO Scheldue Parser
Парсер расписания занятий МИТСО

### TODO
 * Исправление SIGSEGV в некоторых случаях (а каких .)

## Установка
Установка производится запуском `nimble install https://github.com/bit0r1n/mitso`

## Пример использования
```nim
import asyncdispatch, sequtils, strutils
import mitso

proc main() {.async.} =
  let site = newSite()
  discard await site.loadGroups()

  echo "Введи номер группы"
  let
    input = readLine(stdin)
    groups = site.groups.filter do (x: Group) -> bool: x.display.contains(input)

  echo if groups.len == 0: "Группы не нашлось =(" else: "Найдены группы: " & $groups

waitFor main()
```

**Для запуска необходимы параметры `--threads:on -d:ssl` Эти параметры необходимо указать для поддержки многопоточности при парсинге и SSL**