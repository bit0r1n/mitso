# 🍉 MITSO Schedule Parser
Парсер расписания занятий МИТСО

## Установка
Установка производится запуском `nimble install https://github.com/bit0r1n/mitso`

## Пример использования
```nim
import asyncdispatch, sequtils, strutils
import mitso/[parser, typedefs]

proc main() {.async.} =
  let site = Site()
  discard await site.loadGroups() # Выполняет инициализацию объекта сайта, т.е. загружает базовый контент страницы с сохранением куки, загружает все факультеты, группы

  echo "Введи номер группы"
  let
    input = readLine(stdin)
    groups = site.groups.filter do (x: Group) -> bool: x.display.contains(input)

  echo if groups.len == 0: "Группы не нашлось =(" else: "Найдены группы: " & $groups

waitFor main()
```

**Для улучшения производительности при инициализации используется многопоточность, т.е. при компиляции сразу же добавится паратетр `--threads:on`, а также для работы с запросами добавляется параметр `-d:ssl`**
