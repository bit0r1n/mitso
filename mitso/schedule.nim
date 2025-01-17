#[
  MITSO Parser - парсер расписания занятий МИТСО
  Copyright (C) 2022 bit0r1n

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]#

import std/[
  asyncdispatch, httpclient, net,
  xmltree, strtabs,
  uri, options, strformat,
  algorithm, sequtils, strutils,
  times, json, nre, base64,
  os
]
import private/[utils, constants], typedefs, helpers
import malebolgia, pkg/htmlparser

proc loadPage*(site: ScheduleSite) {.async.} =
  ## Получение и сохранение контента сайта, обновление CSRF токена
  let client = newAsyncHttpClient()

  debug "[loadPage]", "Получение контента базовой страницы"
  let response = await client.requestWithRetry(SCHEDULE_MAIN_PAGE)

  debug "[loadPage]", "Контент получен, сохранение"
  site.content = some await response.body

  debug "[loadPage]", "Получение куков"
  site.cookies = response.headers["Set-Cookie"]

  var doc = parseHtml(site.content.get)
  for m in doc.findAll("meta"):
    if m.attrs.hasKey("name") and m.attrs["name"] == "csrf-token":
      debug "[loadPage]", "CSRF токен получен"
      site.csrfToken = some m.attrs["content"]
      break

  doc.clear()

  if site.csrfToken.isNone:
    raise newException(ValueError, "CSRF token not found")

proc getFaculties*(site: ScheduleSite): seq[SelectOption] =
  ## Получение факультетов
  debug "[getFaculties]", "Парс главной страницы"
  var  html = parseHtml(site.content.get)
  for select in html.findAll("select"): # проход по пунктам селекта, они доступны при загрузке страницы
    if select.attrs.hasKey("id") and select.attrs["id"] == "faculty-id":
      for x in select.items:
        if x.kind == xnElement and x.attr("value") != "":
          let facult = (id: x.attr("value"), display: x.innerText)
          debug "[getFaculties]", "Найден факультет", $facult
          result.add(facult)
  html.clear()

proc threadParseCourse(faculty, form, course, csrfToken, cookies: string): seq[Group] =
  let client = newHttpClient(headers = newHttpHeaders({
      "Content-Type": "application/x-www-form-urlencoded",
      "X-CSRF-Token": csrfToken,
      "Cookie": cookies
    })
  )

  debug "[threadParseCourse]", fmt"Получение групп ({$course}, {faculty}, {$form})"
  let groupsRawJson = client.requestWithRetry(parseUri(SCHEDULE_GROUP), HttpPost,
      body = encodeQuery({
      "depdrop_parents[0]": faculty,
      "depdrop_parents[1]": form,
      "depdrop_parents[2]": course,
      "depdrop_all_params[faculty-id]": faculty,
      "depdrop_all_params[form-id]": form,
      "depdrop_all_params[course-id]": course
    }))

  if "application/json" notin groupsRawJson.headers["content-type", 0]:
    debug "[threadParseCourse]", "Сервер отправил контент не с ожидаемым типом контента",
      " ", groupsRawJson.status, " ", groupsRawJson.body
    raise newException(ScheduleServiceError, "Schedule service (groups) responded with wrong Content-Type")

  let groupsJson = parseJson(groupsRawJson.body)

  for groupElem in groupsJson["output"]:
    result.add(Group(
      id: groupElem["id"].getStr(),
      display: groupElem["name"].getStr(),
      course: parseCourse(course),
      form: parseForm(form),
      faculty: parseFaculty(faculty)
    ))
    debug "[threadParseCourse]", "Найдена группа", $result[^1]

proc threadParseForm(faculty, form, csrfToken, cookies: string, sleepTime: int): seq[Group] =
  let client = newHttpClient(headers = newHttpHeaders({
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": csrfToken,
        "Cookie": cookies
      })
    )

  debug "[threadParseForm]", fmt"Получение курсов для факультета {faculty} ({$form})"
  let coursesRawJson = client.requestWithRetry(parseUri(SCHEDULE_COURSE),
        HttpPost,
      body = encodeQuery({
      "depdrop_parents[0]": faculty,
      "depdrop_parents[1]": form,
      "depdrop_all_params[faculty-id]": faculty,
      "depdrop_all_params[form-id]": form,
    }))

  if "application/json" notin coursesRawJson.headers["content-type", 0]:
    debug "[threadParseForm]", "Сервер отправил контент не с ожидаемым типом контента",
      " ", coursesRawJson.status, " ", coursesRawJson.body
    raise newException(ScheduleServiceError, "Schedule service (courses) responded with wrong Content-Type")

  let coursesJson = parseJson(coursesRawJson.body)
  var courses = newSeq[SelectOption]()

  # Парс курсов формы обучения
  for course in coursesJson["output"].getElems():
    courses.add((id: course["id"].getStr, display: course["name"].getStr))

  # Проход по курсам
  var
    coursesGroups = newSeq[seq[Group]](courses.len)
    m = createMaster()

  m.awaitAll:
    for i, course in courses:
      m.spawn threadParseCourse(faculty = faculty, form = form, course = course.id,
        csrfToken = csrfToken, cookies = cookies) -> coursesGroups[i]
      if sleepTime > 0: sleep(sleepTime)

  courses.setLen(0)

  for groups in coursesGroups:
    result.add(groups)

  coursesGroups.setLen(0)

proc threadParseFaculty(faculty, csrfToken, cookies: string, sleepTime: int): seq[Group] =
  let client = newHttpClient(headers = newHttpHeaders({
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": csrfToken,
        "Cookie": cookies
      })
    )

  debug "[threadParseFaculty]", "Получение форм обучения для факультета", $faculty
  let formsRawJson = client.requestWithRetry(parseUri(SCHEDULE_FORMS), HttpPost,
    body = encodeQuery({ "depdrop_parents[0]": faculty,
      "depdrop_all_params[faculty-id]": faculty }))

  if "application/json" notin formsRawJson.headers["content-type", 0]:
    debug "[threadParseFaculty]", "Сервер отправил контент не с ожидаемым типом контента",
      " ", formsRawJson.status, " ", formsRawJson.body
    raise newException(ScheduleServiceError, "Schedule service (forms) responded with wrong Content-Type")

  let formsJson = parseJson(formsRawJson.body)
  var forms = newSeq[SelectOption]()

  # Парс форм обучения
  for form in formsJson["output"].getElems():
    forms.add((form["id"].getStr(), form["name"].getStr()))

  # Проход по формам обучения
  var
    formsGroups = newSeq[seq[Group]](forms.len)
    m = createMaster()

  m.awaitAll:
    for i, form in forms:
      m.spawn threadParseForm(faculty = faculty, form = form.id,
        csrfToken = csrfToken, cookies = cookies, sleepTime = sleepTime) -> formsGroups[i]
      if sleepTime > 0: sleep(sleepTime)

  forms.setLen(0)

  for groups in formsGroups:
    result.add(groups)

  formsGroups.setLen(0)

proc getGroups*(site: ScheduleSite, faculties: seq[SelectOption], sleepTime = 6000): seq[Group] {.gcsafe.} =
  ## Получение групп

  # Проход по факультетам
  var
    facultiesGroups = newSeq[seq[Group]](faculties.len)
    m = createMaster()

  m.awaitAll:
    for i, faculty in faculties:
      m.spawn threadParseFaculty(faculty = faculty.id,
        csrfToken = site.csrfToken.get, cookies = site.cookies.toFullString, sleepTime = sleepTime) -> facultiesGroups[i]

  var resultGroups = newSeq[Group]()
  for groups in facultiesGroups:
    resultGroups.add(groups)

  facultiesGroups.setLen(0)

  # Сортировка групп по курсам/номерам
  debug "[getGroups]", "Сортировка групп по курсам и номерам"
  resultGroups.sort do (x, y: Group) -> int:
    result = cmp(x.course, y.course)
    if result == 0:
      result = cmp(x.id, y.id)

  #[
    Фильтрация групп
    В расписании почему-то дублируются группы, оставаясь на предыдущих курсах.
    Если находятся дублирующие группы - остается только из последнего возможного курса
  ]#
  debug "[getGroups]", "Фильтрация групп"
  result = resultGroups.filter do (x: Group) -> bool:
    if x.id == INVALID_GROUP_ID: # ???
      debug "[getGroups]", "omgomg😱 its fkin AUDITORIYA group, group of my dreams 😍🤩♥"
      return false # 👎 btw
    var simGroups = resultGroups.filter do (y: Group) -> bool: result = y.id ==
        x.id and y.faculty == x.faculty
    if simGroups.len == 1:
      result = true
    else:
      debug "[getGroups]", "Найдено несколько похожих групп", $simGroups
      simGroups.sort do (y, z: Group) -> int: result = cmp(y.course, z.course)
      result = simGroups[^1] == x

  resultGroups.setLen(0)

proc loadGroups*(site: ScheduleSite, sleepTime = 6000): Future[seq[Group]] {.async.} =
  ## Хелпер, загружающий все группы с нуля
  debug "[loadGroups]", "Загрузка страницы"
  await site.loadPage()
  debug "[loadGroups]", "Парс факультетов"
  let faculties = site.getFaculties()
  debug "[loadGroups]", "Парс групп"
  result = site.getGroups(faculties, sleepTime)

proc getWeeks*(site: ScheduleSite, group: Group): Future[seq[SelectOption]] {.async, gcsafe.} =
  ## Получение доступных недель для группы
  let client = newAsyncHttpClient(headers = newHttpHeaders({
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": site.csrfToken.get,
        "Cookie": site.cookies.toFullString
      })
    )

  debug "[getWeeks]", "Получение доступных недель для группы", $group
  let
    weeksRawJson = await client.requestWithRetry(parseUri(SCHEDULE_WEEK),
        HttpPost,
      body = encodeQuery({
      "depdrop_parents[0]": %group.faculty,
      "depdrop_parents[1]": %group.form,
      "depdrop_parents[2]": %group.course,
      "depdrop_parents[3]": group.id,
      "depdrop_all_params[faculty-id]": %group.faculty,
      "depdrop_all_params[form-id]": %group.form,
      "depdrop_all_params[course-id]": %group.course,
      "depdrop_all_params[group-id]": group.id,
    }))

  if "application/json" notin weeksRawJson.headers["content-type", 0]:
    debug "[getWeeks]", "Сервер отправил контент не с ожидаемым типом контента",
      " ", weeksRawJson.status, " ", await  weeksRawJson.body
    raise newException(ScheduleServiceError, "Schedule service (weeks) responded with wrong Content-Type")

  let
    resp = await weeksRawJson.body()
    weeksJson = parseJson(resp)

  if weeksJson["output"].len == 0:
    debug "[getWeeks]", "Не нашлось доступных недель для", $group
    return @[]

  for week in weeksJson["output"]:
    let weekId = week["id"].getInt()
    result.add(($weekId, if weekId > 0: $(weekId + 1) &
        " неделя" else: "Текущая неделя"))

  debug "[getWeeks]", "Получены недели для группы",
      $group, $result

proc getSchedule*(site: ScheduleSite, group: Group, week: string): Future[seq[
    ScheduleDay]] {.async.} =
  # Получение расписания на неделю
  let client = newAsyncHttpClient(headers = newHttpHeaders({
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": site.csrfToken.get,
        "Cookie": site.cookies.toFullString
      })
    )
  debug "[getSchedule]", fmt"Получение расписания для группы {$group} для {$week}"
  var
    sheldueRawHtml = await client.requestWithRetry(SCHEDULE_MAIN_PAGE, HttpPost,
      body = encodeQuery({
        "ScheduleSearch[fak]": %group.faculty,
        "ScheduleSearch[form]": %group.form,
        "ScheduleSearch[kurse]": %group.course,
        "ScheduleSearch[group_class]": group.id,
        "ScheduleSearch[week]": week,
      }))
    resp = await sheldueRawHtml.body()
    scheduleHtml = parseHtml(resp)

  var weeksContainer = scheduleHtml.findAll("div").filterIt(it.attr("id") == "schedule-content")[0]

  var weekContainerIndex = -1
  for el in weeksContainer.items:
    weekContainerIndex += 1

    if weekContainerIndex != parseInt(week): continue # для обратной совместимости сохраняется логика: один вызов - получение одной недели

    var day: ScheduleDay
    var eI = -1 # индекс блока дня
    for item in el.items:
      if item.kind != xnElement: continue

      if item.tag == "h2": # блок дня начинается с заголовка - даты
        eI += 1

        day = ScheduleDay(
          displayDate: item.innerText,
          day: parseDay(eI),
          lessons: newSeq[Lesson]()
        )

        let
          scheduleDayMonth = parseMonth(item.innerText.split(" ")[^1])
          yearOffset = if scheduleDayMonth == mJan and
            result.filterIt(it.date.month == mDec).len != 0: 1 else: 0
          dayTime = dateTime(
            year = now().year + yearOffset,
            month = scheduleDayMonth,
            monthday = parseInt(item.innerText.split(" ")[1]),
            zone = utc()
          )
        day.date = dayTime
      elif item.tag == "div" and item.attr("class") == "table-responsive": # таблица занятий
        let lessonsTable = item.findAll("table")[0]
        let trs = lessonsTable.findAll("tr").filter do (x: XmlNode) -> bool: x.kind == xnElement
        for i, trDay in trs: # проход по строкам занятий
          if trDay.kind != xnElement: continue
          if i == 0: continue # игнор из thead
          var lesson = Lesson()
          let tds = trDay.findAll("td").filter do (x: XmlNode) ->
              bool: x.kind == xnElement
          if tds[1].innerText.contains("(нет занятий)") or tds[
              1].innerText.replace("\n", " ").match(
              re"^\d\. -[ ]?$").isSome: continue # игнор лаб/прак для одной части

          var
            ls = parseLessonName(tds[1].innerText.replace("\n", " "))
            classrooms = if tds[2].innerText.len > 0 and encode(tds[2].innerText) != "wqA=":
              parseClassrooms(tds[2].innerText) else: @[]
            time: LessonTime

          try:
            time = parseTime(tds[0].innerText) # =))
          except ValueError:
            continue

          if day.lessons.len != 0 and ls.lessonName == day.lessons[
              ^1].name and
            ls.lessonType == day.lessons[^1].lType and time == day.lessons[
                ^1].lessonTime: # занятие разделено на группы
            for classroom in classrooms:
              if classroom notin day.lessons[^1].classrooms:
                day.lessons[^1].classrooms.add(classroom)
            if ls.teacher notin INVALID_TEACHERS and ls.teacher notin day.lessons[^1].teachers:
              day.lessons[^1].teachers.add(ls.teacher)
          else:
            lesson.name = ls.lessonName
            lesson.lType = ls.lessonType
            if ls.teacher notin INVALID_TEACHERS: lesson.teachers.add(ls.teacher)
            if classrooms.len > 0: lesson.classrooms.add(
                classrooms)
            lesson.lessonTime = time

            var lessonDate = day.date
            lessonDate += initDuration(hours = ($%lesson.lessonTime).hours -
                3, minutes = ($%lesson.lessonTime).minutes)

            lesson.date = lessonDate

            day.lessons.add(lesson)
        if day.lessons.len > 0:
          day.lessons.sort do (x, y: Lesson) -> int: cmp(x.lessonTime, y.lessonTime)
          result.add(day)

proc getSchedule*(site: ScheduleSite, group: Group, week: SelectOption): Future[seq[
    ScheduleDay]] {.async.} =
  result = await site.getSchedule(group, week.id)
