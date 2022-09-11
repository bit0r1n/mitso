import mitsopkg/[parser, typedefs, helpers]

when not isMainModule:
  export parser, typedefs, helpers
else:
  import sequtils, strutils, asyncdispatch
  proc main(): Future[void] {.async.} =
    let parser = newSite()

    echo "Получение групп.."
    discard await parser.init()

    echo "Поиск группы \"2121\" второго курса"
    let groups = parser.groups.filter do (x: Group) -> bool: x.display.contains("2121") and x.course == cSecond

    if groups.len == 0:
      echo "Группа не найдена"
    else:
      echo "Поиск доступных недель расписания"
      let weeks = await groups[0].getWeeks()
      
      if weeks.len == 0:
        echo "Расписания нету"
      else:
        echo "Получение расписания первой недели"

        let scheldue = await groups[0].getScheldue(weeks[0])

        for day in scheldue:
          echo day.displayDate & ", " & $day.day
          for lesson in day.lessons:
            echo "\t" & $lesson

  waitFor main()