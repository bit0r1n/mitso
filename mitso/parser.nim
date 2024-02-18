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
  htmlparser, xmltree, strtabs,
  uri, options, strformat,
  algorithm, sequtils, strutils,
  times, threadpool, json, nre
]
import private/[utils, constants], typedefs, helpers

proc loadPage*(site: Site): Future[string] {.async.} =
  ## Получение и сохранение контента сайта
  var client = newHttpClient(sslContext = newContext(verifyMode = CVerifyNone))

  debug "[loadPage]", "Получение контента базовой страницы"
  let response = client.requestWithRetry(SCHEDULE_BASE)

  debug "[loadPage]", "Контент получен, сохранение"
  site.content = some response.body

  debug "[loadPage]", "Получение куков"
  site.cookies = response.headers["Set-Cookie"]

  let
    doc = parseHtml(site.content.get)
    meta = doc.findAll("meta")
  for m in meta:
    if m.attrs.hasKey("name") and m.attrs["name"] == "csrf-token":
      debug "[loadPage]", "CSRF токен получен"
      site.csrfToken = some m.attrs["content"]
      break

  if site.csrfToken.isNone:
    raise newException(ValueError, "CSRF token not found")

  return site.content.get

proc getFaculties*(site: Site): seq[SelectOption] =
  ## Получение и сохранение факультетов
  debug "[getFaculties]", "Парс главной страницы"
  let html = parseHtml(site.content.get)
  site.faculties.setLen(0)
  for select in html.findAll("select"): # проход по пунктам селекта, они доступны при загрузке страницы
    if select.attrs.hasKey("id") and select.attrs["id"] == "faculty-id":
      for x in select.items:
        if x.kind == xnElement and x.attr("value") != "":
          let facult = (id: x.attr("value"), display: x.innerText)
          debug "[getFaculties]", "Найден факультет", $facult
          result.add(facult)
          site.faculties.add(facult)

proc threadParseCourse(site: Site, facult: string, form: string,
    course: string): seq[Group] =
  var client = newHttpClient(sslContext = newContext(verifyMode = CVerifyNone))
  client.headers = newHttpHeaders({"Content-Type": "application/x-www-form-urlencoded",
      "X-CSRF-Token": site.csrfToken.get, "Cookie": site.cookies.toFullString()})
  debug "[threadParseCourse]", fmt"Получение групп ({$course}, {$facult}, {$form})"
  let
    groupsRawJson = client.requestWithRetry(parseUri(SCHEDULE_GROUP), HttpPost,
      body = encodeQuery({
      "depdrop_parents[0]": facult,
      "depdrop_parents[1]": form,
      "depdrop_parents[2]": course,
      "depdrop_all_params[faculty-id]": facult,
      "depdrop_all_params[form-id]": form,
      "depdrop_all_params[course-id]": course
    }))
    groupsJson = parseJson(groupsRawJson.body)

  for groupElem in groupsJson["output"]:
    let group = Group(
      site: site,
      id: groupElem["id"].getStr(),
      display: groupElem["name"].getStr(),
      course: parseCourse(course),
      form: parseForm(form),
      faculty: parseFaculty(facult)
    )
    debug "[threadParseCourse]", "Найдена группа", $group
    result.add(group)

proc threadParseForm(site: Site, facult: string, form: string): seq[Group] =
  var client = newHttpClient(sslContext = newContext(verifyMode = CVerifyNone))
  client.headers = newHttpHeaders({"Content-Type": "application/x-www-form-urlencoded",
      "X-CSRF-Token": site.csrfToken.get, "Cookie": site.cookies.toFullString()})
  debug "[threadParseForm]", fmt"Получение курсов для факультета {$facult} ({$form})"
  var
    coursesRawJson = client.requestWithRetry(parseUri(SCHEDULE_COURSE),
        HttpPost,
      body = encodeQuery({
      "depdrop_parents[0]": facult,
      "depdrop_parents[1]": form,
      "depdrop_all_params[faculty-id]": facult,
      "depdrop_all_params[form-id]": form,
    }))
    coursesJson = parseJson(coursesRawJson.body)
    courses = newSeq[SelectOption]()

  # Парс курсов формы обучения
  for course in coursesJson["output"].getElems():
    courses.add((id: course["id"].getStr, display: course["name"].getStr))

  # Проход по курсам
  var groupsResponses = newSeq[FlowVar[seq[Group]]]()
  for course in courses.items:
    let groupsCourse = spawn threadParseCourse(site, facult, form, course.id)
    groupsResponses.add(groupsCourse)

  for response in groupsResponses:
    let groups = ^response
    for group in groups:
      result.add(group)

proc threadParseFaculty(site: Site, facult: string): seq[Group] =
  var client = newHttpClient(sslContext = newContext(verifyMode = CVerifyNone))
  client.headers = newHttpHeaders({"Content-Type": "application/x-www-form-urlencoded",
      "X-CSRF-Token": site.csrfToken.get, "Cookie": site.cookies.toFullString()})
  debug "[threadParseFaculty]", "Получение форм обучения для факультета", $facult
  var
    formsRawJson = client.requestWithRetry(parseUri(SCHEDULE_FORMS), HttpPost,
      body = encodeQuery({"depdrop_parents[0]": facult,
          "depdrop_all_params[faculty-id]": facult}))
    formsJson = parseJson(formsRawJson.body)
    forms = newSeq[SelectOption]()

  # Парс форм обучения
  for form in formsJson["output"].getElems():
    let form = (form["id"].getStr(), form["name"].getStr())
    debug "[threadParseFaculty]", "Найдена форма обучения", $form
    forms.add(form)

  # Проход по формам обучения
  var formsResponses = newSeq[FlowVar[seq[Group]]]()
  for form in forms.items:
    formsResponses.add(spawn threadParseForm(site, facult, form.id))
  for response in formsResponses:
    let groups = ^response
    for group in groups:
      result.add(group)

proc getGroups*(site: Site,
  form: seq[Form] = @[], course: seq[Course] = @[], faculty: seq[Faculty] = @[
      ]): Future[seq[Group]] {.async.} =
  # Получение, фильтрация и сохранение групп (перезаписывает ранее сохраненные группы)

  # Очистка списка групп
  site.groups.setLen(0)

  var facultiesResponses = newSeq[FlowVar[seq[Group]]]()

  # Проход по факультетам
  for facult in site.faculties:
    facultiesResponses.add(spawn threadParseFaculty(site, facult.id))

  for groupsChunk in facultiesResponses:
    let res = ^groupsChunk
    for group in res:
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
    var simGroups = site.groups.filter do (y: Group) -> bool: result = y.id ==
        x.id and y.faculty == x.faculty
    if simGroups.len == 1:
      result = true
    else:
      debug "[getGroups]", "Найдено несколько похожих групп", $simGroups
      simGroups.sort do (y, z: Group) -> int: result = cmp(y.course, z.course)
      return simGroups[^1] == x
  return site.groups

proc loadGroups*(site: Site): Future[Site] {.async.} =
  ## Хелпер, загружающий все данные с нуля
  debug "[loadGroups]", "Загрузка страницы"
  discard await site.loadPage()
  debug "[loadGroups]", "Парс факультетов"
  discard site.getFaculties()
  debug "[loadGroups]", "Парс групп"
  discard await site.getGroups()

  result = site

proc getWeeks*(group: Group): Future[seq[SelectOption]] {.async, gcsafe.} =
  ## Получение доступных недель для группы
  var client = newAsyncHttpClient(sslContext = newContext(
      verifyMode = CVerifyNone))
  client.headers = newHttpHeaders({"Content-Type": "application/x-www-form-urlencoded",
      "X-CSRF-Token": group.site.csrfToken.get,
      "Cookie": group.site.cookies.toFullString()})
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
    resp = await weeksRawJson.body()
    weeksJson = parseJson(resp)

  group.weeks.setLen(0)

  if (weeksJson["output"].len == 0):
    debug "[getWeeks]", "Не нашлось доступных недель для", $group
    group.weeks = @[]
    return group.weeks

  for week in weeksJson["output"]:
    let weekId = week["id"].getInt()
    group.weeks.add(($weekId, if weekId > 0: $(weekId + 1) &
        " неделя" else: "Текущая неделя"))

  debug "[getWeeks]", "Получены недели для группы",
      $group, $group.weeks

  return group.weeks

proc getSchedule*(group: Group, week: string): Future[seq[
    ScheduleDay]] {.async.} =
  # Получение расписания на неделю
  var client = newAsyncHttpClient(sslContext = newContext(
      verifyMode = CVerifyNone))
  client.headers = newHttpHeaders({"Content-Type": "application/x-www-form-urlencoded",
      "X-CSRF-Token": group.site.csrfToken.get,
      "Cookie": group.site.cookies.toFullString()})
  debug "[getSchedule]", fmt"Получение расписания для группы {$group} для {$week}"
  let
    sheldueRawHtml = await client.requestWithRetry(SCHEDULE_BASE, HttpPost,
      body = encodeQuery({
        "ScheduleSearch[fak]": %group.faculty,
        "ScheduleSearch[form]": %group.form,
        "ScheduleSearch[kurse]": %group.course,
        "ScheduleSearch[group_class]": group.id,
        "ScheduleSearch[week]": week,
      }))
    resp = await sheldueRawHtml.body()
    scheduleHtml = parseHtml(resp)

  for el in scheduleHtml.findAll("div"):
    if el.attr("class") != "container" and el.child("table") != nil: continue

    var lessons = newSeq[Lesson]()
    var day: ScheduleDay
    var eI = -1 # индекс блока дня
    for item in el.items:
      if item.kind == xnElement:
        if item.tag == "h2": # блок дня начинается с заголовка - даты
          eI += 1

          day = ScheduleDay()
          day.displayDate = item.innerText
          day.day = parseDay(eI)
          let
            scheduleDayMonth = parseMonth(item.innerText.split(" ")[1])
            dayTime = dateTime(
              now().year + (if scheduleDayMonth == mJan and now().month ==
                  mDec: 1 else: 0),
              scheduleDayMonth,
              parseInt(item.innerText.split(" ")[0]),
              zone = utc()
            )
          day.date = dayTime
          lessons.setLen(0)
        elif item.tag == "table": # таблица занятий
          let trs = item.findAll("tr").filter do (x: XmlNode) -> bool: x.kind == xnElement
          for i, trDay in trs: # проход по строкам занятий
            if trDay.kind != xnElement: continue
            if i == 0: continue # игнор из thead
            var lesson = Lesson()
            let tds = trDay.findAll("td").filter do (x: XmlNode) ->
                bool: x.kind == xnElement
            if tds[1].innerText.contains("(нет занятий)") or tds[
                1].innerText.replace("\n", " ").match(
                re"^\d\. -$").isSome: continue # игнор лаб/прак для одной части

            var
              ls = parseLessonName(tds[1].innerText.replace("\n", " "))
              classrooms = if tds[2].innerText.len > 0: parseClassrooms(tds[
                  2].innerText) else: @[]
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
          if day.lessons.len > 0: result.add(day)

proc getSchedule*(group: Group, week: SelectOption): Future[seq[
    ScheduleDay]] {.async.} =
  result = await group.getSchedule(week.id)
