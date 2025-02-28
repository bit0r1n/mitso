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

import typedefs, helpers, private/[ utils, constants ]
import asyncdispatch, httpclient, uri, json, times, strutils, algorithm, sequtils

proc newMitsoWrapper*(): MitsoWrapper =
  new(result)
  result.client = newAsyncHttpClient(userAgent =
      "MITSO Wrapper (https://github.com/bit0r1n/mitso, 0.3.0)")

proc getApiJsonResponse(wrapper: MitsoWrapper, url, debugEndpoint: string): Future[JsonNode] {.async.} =
  let response = await wrapper.client.requestWithRetry(url)
  await response.handleNonJsonResponse(debugEndpoint)

  result = parseJson(await response.body)

proc parseLessons(rawLessons: JsonNode): seq[ScheduleDay] =
  for weekSchedule in rawLessons.keys:
    for daySchedule in rawLessons[weekSchedule].keys:
      let
        day = daySchedule.parse("yyyy-MM-dd", zone = utc())
        scheduleDay = ScheduleDay(
          date: day,
          displayDate: daySchedule
        )
      for rawLesson in rawLessons[weekSchedule][daySchedule].getElems():
        let lessonName = rawLesson["subject"].getStr().strip()
        if lessonName.len < 4 or lessonName.endsWith(". -"): continue

        let
          lessonTime = parseTime(rawLesson["time"].getStr())
          startTime = $%lessonTime
          parsedName = parseLessonName(lessonName, parseTeacher = false)

        let lesson = Lesson(
          date: day + initDuration(hours = startTime[0] - 3, minutes = startTime[1]),
          name: parsedName.lessonName,
          lType: parsedName.lessonType,
          lessonTime: lessonTime
        )

        let
          teacher = rawLesson["teacher"].getStr()
          classroom = rawLesson["auditorium"].getStr().strip()

        if teacher.len != 0 and teacher notin INVALID_TEACHERS: lesson.teachers.add(teacher)
        if classroom.len != 0: lesson.classrooms.add(classroom)

        if scheduleDay.lessons.len != 0 and
          lesson.name == scheduleDay.lessons[^1].name and
            lesson.lType == scheduleDay.lessons[^1].lType and
              lesson.lessonTime == scheduleDay.lessons[^1].lessonTime:
          var lastLesson = scheduleDay.lessons[^1]
          if lesson.classrooms[0] notin lastLesson.classrooms:
            lastLesson.classrooms.add(lesson.classrooms[0])

          if lesson.teachers[0] notin lastLesson.teachers:
            lastLesson.teachers.add(lesson.teachers[0])
        else:
          scheduleDay.lessons.add(lesson)
      
      if scheduleDay.lessons.len != 0:
        scheduleDay.lessons.sort do (x, y: Lesson) -> int: cmp(x.lessonTime, y.lessonTime)
        result.add(scheduleDay)

proc getFacultyForms*(wrapper: MitsoWrapper, faculty: Faculty): Future[seq[Form]] {.async.} =
  let formsJson = await wrapper.getApiJsonResponse(
    SCHEDULE_API_FORMS & "?" & encodeQuery({ "faculty": %faculty }),
    "facultyForms"
  )
  result = formsJson.getElems().mapIt(parseForm(it["id"].getStr()))

proc getFormCourses*(wrapper: MitsoWrapper, faculty: Faculty, form: Form): Future[seq[Course]] {.async.} =
  let coursesJson = await wrapper.getApiJsonResponse(
    SCHEDULE_API_COURSES & "?" & encodeQuery({ "faculty": %faculty, "form": %form }),
    "formCourses"
  )
  result = coursesJson.getElems().mapIt(parseCourse(it["id"].getStr()))

proc getGroups*(wrapper: MitsoWrapper, faculty: Faculty, form: Form, course: Course): Future[seq[Group]] {.async.} =
  let groupsJson = await wrapper.getApiJsonResponse(
    SCHEDULE_API_GROUPS & "?" & encodeQuery({
      "faculty": %faculty,
      "form": %form,
      "course": %course },
      usePlus = false
    ),
    "courseGroups"
  )

  for group in groupsJson:
    if group["id"].getStr() == INVALID_GROUP_ID: continue

    result.add(Group(
      id: group["id"].getStr(),
      display: group["name"].getStr(),
      course: course,
      form: form,
      faculty: faculty
    ))

proc getAllGroups*(wrapper: MitsoWrapper): Future[seq[Group]] {.async.} =
  for faculty in Faculty:
    let forms = await wrapper.getFacultyForms(faculty)
    for form in forms:
      let courses = await wrapper.getFormCourses(faculty, form)
      for course in courses:
        let groups = await wrapper.getGroups(faculty, form, course)
        result.add(groups)

proc getSchedule*(wrapper: MitsoWrapper, group: Group): Future[seq[ScheduleDay]] {.async.} =
  let scheduleJson = await wrapper.getApiJsonResponse(
    SCHEDULE_API_LESSONS & "?" & encodeQuery({
      "faculty": $group.faculty,
      "form": $group.form,
      "course": $group.course,
      "group": group.display },
      usePlus = false
    ),
    "groupSchedule"
  ) # { "названиеНедели": { "гггг-мм-дд": занятие[] } }
  result = scheduleJson.parseLessons()

proc getTeachers*(wrapper: MitsoWrapper): Future[seq[string]] {.async.} =
  let teachersJson = await wrapper.getApiJsonResponse(SCHEDULE_API_TEACHERS, "teachers")
  result = teachersJson.getElems().mapIt(it.getStr())

proc getTeacherSubjects*(wrapper: MitsoWrapper, name: string): Future[seq[SelectOption]] {.async.} =
  let teachersJson = await wrapper.getApiJsonResponse(
    SCHEDULE_API_TEACHER_SUBJECTS & "?" & encodeQuery({ "teacher": name }, usePlus = false),
    "teacherSubjects"
  )
  result = teachersJson.getElems().mapIt((id: it["id"].getStr(), display: it["name"].getStr()))

proc getTeacherSchedule*(wrapper: MitsoWrapper, name: string): Future[seq[ScheduleDay]] {.async.} =
  let scheduleJson = await wrapper.getApiJsonResponse(
    SCHEDULE_API_TEACHER_LESSONS & "?" & encodeQuery({ "teacher": name }, usePlus = false),
    "teacherSchedule"
  )
  result = scheduleJson.parseLessons()

proc getTeacherSubjectSchedule*(wrapper: MitsoWrapper, name, subject: string): Future[seq[ScheduleDay]] {.async.} =
  let scheduleJson = await wrapper.getApiJsonResponse(
    SCHEDULE_API_TEACHER_SUBJECT_LESSONS & "?" & encodeQuery({ "teacher": name, "subject": subject }, usePlus = false),
    "teacherSubjectSchedule"
  )
  result = scheduleJson.parseLessons()
