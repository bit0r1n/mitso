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

import strutils, strformat, times, options, nre
import typedefs
import private/constants

proc parseTeachers*(rawString: string): seq[string] =
  let strings = rawString.split("\n")
  if strings.len == 5:
    # нормально разделить можно только с исходным кодом, в преобразованной строке аудитории объединяются в одну строку. пр. "Ауд. 62 (к)Ауд. 63 (к)"
    let endIndex = strings[2].find("<br />")
    result.add(strings[2][0..(endIndex - 1)])
    result.add(strings[4][0..^7]) # убирается "</div>"
  else:
    let str = strings[2][0..^7]
    if str notin INVALID_TEACHERS: result.add(str)

proc parseClassrooms*(rawString: string): seq[string] =
  if rawString == "Ауд. " or rawString.len == 0: return @[] # актуально для занятий по физкультуре, по другим не видел
  for aud in rawString.split("Ауд. "):
    if aud.len != 0: result.add(if aud.contains("БАЗ"): "БАЗ" else: aud)

  if result.len == 1 and result[0].contains("-"): # пр. "Ауд 22-23"
    result = result[0].split("-")

proc parseForm*(form: string): Form =
  case form:
  of "Dnevnaya":
    return foFullTime
  of "Zaochnaya":
    return foPartTime
  of "Zaochnaya sokrashhennaya":
    return foPartTimeReduced
  else:
    raise newException(ValueError, "Invalid form")

proc parseCourse*(course: string): Course =
  case course:
  of "1 kurs":
    return cFirst
  of "2 kurs":
    return cSecond
  of "3 kurs":
    return cThird
  of "4 kurs":
    return cFourth
  of "5 kurs":
    return cFifth
  else:
    raise newException(ValueError, "Invalid course")

proc parseFaculty*(faculty: string): Faculty =
  case faculty:
  of "Magistratura":
    return faMagistracy
  of "E`konomicheskij":
    return faEconomical
  of "YUridicheskij":
    return faLegal
  else:
    raise newException(ValueError, "Invalid faculty")

proc parseTime*(time: string): LessonTime =
  case time:
  of "8.00-8.40, 8.45-9.25", "08.00-08.40, 08.45-09.25", "8.00-9.25", "08.00-09.25", "08.00-9.25":
    return ltFirst
  of "09:35-10.15,10.20-11.00", "09.35- 11.00", "09.35-11.00":
    return ltSecond
  of "11:10-11.15,11.55-12.35", "11:10-11.50,11.55-12.35", "11.10-12.35":
    return ltThird
  of "13:05-13.45,13.50-14.30", "13.05-14.30":
    return ltFourth
  of "14:40-15.20,15.25-16.05", "14.40-16.05":
    return ltFifth
  of "16:35-17.15,17.20-18.00", "16.35-18.00":
    return ltSixth
  of "18:10-18.50,18.55-19.15", "18.10-19.35":
    return ltSeventh
  of "19.45-20.25,20.30-21.10", "19.45-21.10":
    return ltEighth
  else:
    raise newException(ValueError, "Invalid time")

proc parseDay*(day: string): WeekDay =
  case day:
  of "Понедельник":
    return dMon
  of "Вторник":
    return dTue
  of "Среда":
    return dWed
  of "Четверг":
    return dThu
  of "Пятница":
    return dFri
  of "Суббота":
    return dSat
  of "Воскресенье":
    return dSun

proc parseDay*(dayOfWeek: int): WeekDay =
  case dayOfWeek:
  of 0:
    return dMon
  of 1:
    return dTue
  of 2:
    return dWed
  of 3:
    return dThu
  of 4:
    return dFri
  of 5:
    return dSat
  of 6:
    return dSun
  else:
    raise newException(ValueError, "Invalid day of week")

proc parseLessonType*(lType: string): LessonType =
  case lType:
  of "лек", "нач":
    return ltpLecture
  of "лаб":
    return ltpLaboratory
  of "практическое", "практ/сем":
    return ltpPractice
  of "диф/зачет", "зач", "зачет":
    return ltpCreditCourse
  of "конс":
    return ltpConsultation
  of "экзамен":
    return ltpExam
  of "курс/проект", "курс/работа", "курс/ работа":
    return ltpCourseProject

proc parseMonth*(month: string): Month =
  case month:
  of "января":
    return mJan
  of "февраля":
    return mFeb
  of "марта":
    return mMar
  of "апреля":
    return mApr
  of "мая":
    return mMay
  of "июня":
    return mJun
  of "июля":
    return mJul
  of "августа":
    return mAug
  of "сентября":
    return mSep
  of "октября":
    return mOct
  of "ноября":
    return mNov
  of "декабря":
    return mDec

proc parseLessonName*(name: string, parseTeacher = true): tuple[lessonName: string, lessonType: LessonType, teacher: string] =
  var
    r = re"(\d\. )?(.*)(?!\S)?\((.*)\)(?: (.*))?$"
    m = name.find(r).get().captures
  result.lessonName = m[1]
  result.lessonType = parseLessonType(m[2])
  result.teacher = if parseTeacher: m[3] else: ""

proc `$`*(form: Form): string =
  case form:
  of foFullTime:
    return "Дневная"
  of foPartTime:
    return "Заочная"
  of foPartTimeReduced:
    return "Заочная сокращенная"

proc `$`*(course: Course): string =
  case course:
  of cFirst:
    return "1 курс"
  of cSecond:
    return "2 курс"
  of cThird:
    return "3 курс"
  of cFourth:
    return "4 курс"
  of cFifth:
    return "5 курс"

proc `$`*(faculty: Faculty): string =
  case faculty:
  of faMagistracy:
    return "Магистратура"
  of faEconomical:
    return "Экономический"
  of faLegal:
    return "Юридический"

proc `$`*(group: Group): string = &"{group.display} ({$group.course}, {$group.faculty})"

proc `$`*(lt: LessonTime): string =
  case lt:
  of ltFirst:
    return "08:00 - 9:25"
  of ltSecond:
    return "09:35 - 11:00"
  of ltThird:
    return "11:10 - 12:35"
  of ltFourth:
    return "13:05 - 14:30"
  of ltFifth:
    return "14:40 - 16:05"
  of ltSixth:
    return "16:35 - 18:00"
  of ltSeventh:
    return "18:10 - 19:35"
  of ltEighth:
    return "19:45 - 21:10"

proc `$%`*(lt: LessonTime): TimeTuple =
  case lt:
  of ltFirst:
    return (8, 0)
  of ltSecond:
    return (9, 35)
  of ltThird:
    return (11, 10)
  of ltFourth:
    return (13, 5)
  of ltFifth:
    return (14, 40)
  of ltSixth:
    return (16, 35)
  of ltSeventh:
    return (18, 10)
  of ltEighth:
    return (19, 45)

proc `$`*(lesson: LessonType): string =
  case lesson:
  of ltpLecture:
    return "Лекция"
  of ltpPractice:
    return "Практика"
  of ltpLaboratory:
    return "Лабораторная"
  of ltpCreditCourse:
    return "Зачет"
  of ltpConsultation:
    return "Консультация"
  of ltpExam:
    return "Экзамен"
  of ltpCourseProject:
    return "Курсовая"

proc `$`*(lesson: Lesson): string =
  var items = @[$lesson.lessonTime]
  if lesson.classrooms.len != 0: items.add("Ауд. " & lesson.classrooms.join(", "))
  items.add(lesson.name & " (" & $lesson.lType & ")")
  # items.add($lesson.lType)
  if lesson.teachers.len != 0: items.add(lesson.teachers.join(", "))

  return items.join(" | ")

proc `$`*(day: WeekDay): string =
  case day:
  of dMon:
    return "Понедельник"
  of dTue:
    return "Вторник"
  of dWed:
    return "Среда"
  of dThu:
    return "Четверг"
  of dFri:
    return "Пятница"
  of dSat:
    return "Суббота"
  of dSun:
    return "Воскресенье"

proc `$`*(account: Account): string =
  result = &"{account.fullName}, {account.balance}"

proc `$`*(select: SelectOption): string =
  result = &"{select.display} [{select.id}]"

proc `%`*(form: Form): string =
  case form:
  of foFullTime:
    return "Dnevnaya"
  of foPartTime:
    return "Zaochnaya"
  of foPartTimeReduced:
    return "Zaochnaya sokrashhennaya"

proc `%`*(course: Course): string =
  case course:
  of cFirst:
    return "1 kurs"
  of cSecond:
    return "2 kurs"
  of cThird:
    return "3 kurs"
  of cFourth:
    return "4 kurs"
  of cFifth:
    return "5 kurs"

proc `%`*(faculty: Faculty): string =
  case faculty:
  of faMagistracy:
    return "Magistratura"
  of faEconomical:
    return "E`konomicheskij"
  of faLegal:
    return "YUridicheskij"

proc newScheduleSite*(): ScheduleSite =
  new(result)

proc newGroup*(id, display: string,
  course: Course, form: Form, faculty: Faculty): Group =
  result = Group(
    id: id,
    display: display,
    course: course,
    form: form,
    faculty: faculty
  )

proc newLesson*(name: string,
  teachers = newSeq[string](), classrooms = newSeq[string](),
  date: DateTime, lessonTime: LessonTime, lType: LessonType): Lesson =
  result = Lesson(
    date: date,
    name: name,
    teachers: teachers,
    lessonTime: lessonTime,
    lType: lType,
    classrooms: classrooms
  )
