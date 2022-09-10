import std/[
  asyncdispatch, httpclient, net,
  htmlparser, xmltree, strtabs,
  uri, options, strformat,
  algorithm, sequtils, strutils,
  times
]
import utils, typedefs, helpers, constants

proc newSite*(): Site = Site()

proc loadPage*(site: Site): Future[string] {.async.} =
  # Получение и сохранение контента сайта
  var client = newAsyncHttpClient(sslContext=newContext(verifyMode=CVerifyNone))
  debug "[loadPage]", "Получение контента базовой страницы"
  let content = await client.getContent(SCHELDUE_URL)
  debug "[loadPage]", "Контент получен, сохранение"
  site.content = some content
  return content

proc getFaculties*(site: Site): seq[SelectOption] =
  # Получение и сохранение факультетов
  debug "[getFaculties]", "Парс главной страницы"
  let html = parseHtml(site.content.get)
  result = @[]
  site.faculties.setLen(0)
  for select in html.findAll("select"):
    if select.attrs.hasKey("id") and select.attrs["id"] == "fak_select":
      for x in select.items:
        if x.kind == xnElement:
          let facult = (id: x.attr("value"), display: x.innerText)
          debug "[getFaculties]", "Найден факультет", $facult
          result.add(facult)
          site.faculties.add(facult)

proc getGroups*(site: Site): Future[seq[Group]] {.async.} =
  # Получение, фильтрация и сохранение групп
  var client = newAsyncHttpClient(sslContext=newContext(verifyMode=CVerifyNone))

  # Очистка списка групп
  site.groups.setLen(0)

  # Проход по факультетам
  for facult in site.faculties:
    debug "[getGroups]", "Получение форм обучения для факультета", $facult
    var
      formsRawHtml = await client.getContent(parseUri(SCHELDUE_DATA_URL) ? {
        "type": "form",
        "kaf": KAF_QUERY,
        "fak": facult.id
      })
      formsHtml = parseHtml(formsRawHtml)
      forms = newSeq[SelectOption]()

    # Парс форм обучения
    for formElement in formsHtml.findAll("option"):
      let form = (formElement.attr("value"), formElement.innerText)
      debug "[getGroups]", fmt"Найдена форма обучения: {$form} ({$facult})"
      forms.add(form)

    # Проход по формам обучения
    for form in forms.items:
      debug "[getGroups]", fmt"Получение курсов для факультета {$facult} ({$form})"
      var
        coursesRawHtml = await client.getContent(parseUri(SCHELDUE_DATA_URL) ? {
          "type": "kurse",
          "kaf": KAF_QUERY,
          "fak": facult.id,
          "form": form[0]
        })
        coursesHtml = parseHtml(coursesRawHtml)
        courses = newSeq[SelectOption]()

      # Парс курсов формы обучения
      for courseElement in coursesHtml.findAll("option"):
        let course = (courseElement.attr("value"), courseElement.innerText)
        debug "[getGroups]", fmt"Найден курс: {$course} ({$facult}, {$form})"
        courses.add(course)

      # Проход по курсам
      for course in courses.items:
        debug "[getGroups]", fmt"Получение групп ({$course}, {$facult}, {$form})"
        let
          groupsRawHtml = await client.getContent(parseUri(SCHELDUE_DATA_URL) ? {
            "type": "group_class",
            "kaf": KAF_QUERY,
            "fak": facult.id,
            "form": form[0],
            "kurse": course[0]
          })
          groupsHtml = parseHtml(groupsRawHtml)

        # Парс групп и сохранение
        for groupElement in groupsHtml.findAll("option"):
          let group = Group(
            site: site,
            id: groupElement.attr("value"),
            display: groupElement.innerText,
            course: parseCourse(course[0]),
            form: parseForm(form[0]),
            faculty: parseFaculty(facult.id)
          )
          debug "[getGroups]", "Найдена группа", $group
          site.groups.add(group)

  # Сортировка групп по курсам/номерам
  debug "[getGroups]", "Сортировка групп по курсам и номерам"
  site.groups.sort do (x, y: Group) -> int:
    result = cmp(x.course, y.course)
    if result == 0:
      result = cmp(x.id, y.id)

  #[ 
    Фильтрация групп
    В расписании почему-то дублируются группы, оставаясь на предыдущих курсах.
    Если находятся дублирующие группы - остается только из последнего возможного курса
  ]#
  debug "[getGroups]", "Фильтрация групп"
  site.groups = site.groups.filter do (x: Group) -> bool:
    if x.id == INVALID_GROUP_ID: # ???
      debug "[getGroups]", "omgomg😱 its fkin AUDITORIYA group, group of my dreams 😍🤩♥"
      return false # 👎 btw
    var simGroups = site.groups.filter do (y: Group) -> bool: result = y.id == x.id
    if simGroups.len == 1:
      result = true
    else:
      debug "[getGroups]", "Найдено несколько похожих групп", $simGroups
      simGroups.sort do (y, z: Group) -> int: result = cmp(y.course, z.course)
      return simGroups[0] != x
  return site.groups

proc getWeeks*(group: Group): Future[seq[SelectOption]] {.async.} =
  # Получение доступных недель для группы
  var client = newAsyncHttpClient(sslContext=newContext(verifyMode=CVerifyNone))
  debug "[getWeeks]", "Получение доступных недель для группы", $group
  let
    weeksRawHtml = await client.getContent(parseUri(SCHELDUE_DATA_URL) ? {
      "type": "date",
      "fak": %group.faculty,
      "kaf": KAF_QUERY,
      "form": %group.form,
      "kurse": %group.course,
      "group_class": group.id
    })
    weeksHtml = parseHtml(weeksRawHtml)

  group.weeks.setLen(0)

  if (weeksRawHtml.len == 1):
    debug "[getWeeks]", "Не нашлось доступных недель для", $group
    group.weeks = @[]
    return group.weeks

  for weekElement in weeksHtml.findAll("option"):
    group.weeks.add((weekElement.attr("value"), weekElement.innerText))

  debug "[getWeeks]", "Получены недели для группы", $group, $group.weeks

  return group.weeks

proc getScheldue*(group: Group, week: SelectOption): Future[seq[ScheldueDay]] {.async.} =
  var client = newAsyncHttpClient(sslContext=newContext(verifyMode=CVerifyNone))
  debug "[getScheldue]", fmt"Получение расписания для группы {$group} для {$week}"
  let
    sheldueRawHtml = await client.getContent(parseUri(SCHELDUE_BASE) / %group.form / %group.faculty / %group.course / group.id / week.id)
    scheldueHtml = parseHtml(sheldueRawHtml)
  var days = newSeq[ScheldueDay]()

  for divElement in scheldueHtml.findAll("div"):
    if divElement.attr("class") == "rp-ras": # блок недели
      for dayElem in divElement.items: # прохождение по дням
        if dayElem.kind == xnElement:
          let dayElements = dayElem.findAll("div").filter do (x: XmlNode) -> bool:
            x.kind == xnElement

          let
            dateString = dayElements[0].innerText
            dayString = dayElements[1].innerText
            lessonsElements = dayElements[2].findAll("div")
            scheldueDayMonth = parseMonth(dateString.split(" ")[1])
            dayTime = dateTime(
              now().year + (if scheldueDayMonth == mJan and now().month == mDec: 1 else: 0),
              scheldueDayMonth,
              parseInt(dateString.split(" ")[0]),
              3, 0, 0,
              zone = utcMinsk
            )

          var day = ScheldueDay(
            date: dayTime,
            displayDate: dateString,
            day: parseDay(dayString),
            lessons: newSeq[Lesson]()
          )

          debug "[getScheldue]", "Парс расписания для " & dateString
          
          for lessonElement in lessonsElements.items: # прохождение по занятиям
            let lessonElements = lessonElement.findAll("div")

            if (lessonElements.filter do (x: XmlNode) -> bool:
              x.attr("class") == "rp-r-aud").len == 0: continue # нету элемента с аудиторией = нету занятия

            let
              timeString = lessonElements[0].innerText
              lessonStrings = lessonElements[1].child("div").innerText.split("\n")
              classroomString = lessonElements[3].innerText

              # если элементов 5 - занятие проходит в двух аудитория с двумя преподавателями (лаба короче), в начале названий занятия есть пункт "N. "
              lessonName = if lessonStrings.len == 5: lessonStrings[0][3..^1] else: lessonStrings[0]
              teachers = parseTeachers($lessonElements[1].child("div"))
              classrooms = parseClassrooms(classroomString)
              lessonTime = parseTime(timeString)

            var lessonDateTime = dayTime
            lessonDateTime += initDuration(hours = ($%lessonTime).hours, minutes = ($%lessonTime).minutes)

            var lesson = Lesson(
                date: lessonDateTime,
                lessonTime: lessonTime,
                name: lessonName,
                lType: parseLessonType(lessonStrings[1])
              )

            if teachers.len != 0:
              lesson.teachers = teachers

            if classrooms.len != 0:
              lesson.classrooms = classrooms

            day.lessons.add(lesson)
          if day.lessons.len != 0: days.add(day)

  return days