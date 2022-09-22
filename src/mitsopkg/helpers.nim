import strutils, strformat, times, options
import typedefs, constants

proc parseTeachers*(rawString: string): seq[string] =
  let strings = rawString.split("\n")
  if strings.len == 5:
    # нормально разделить можно только с исходным кодом, в преобразованной строке аудитории объединяются в одну строку. пр. "Ауд. 62 (к)Ауд. 63 (к)"
    let endIndex = strings[2].find("<br />")
    result.add(strings[2][0..(endIndex - 1)])
    result.add(strings[4][0..^7]) # убирается "</div>"
  else:
    let str = strings[2][0..^7]
    if str != INVALID_TEACHER: result.add(str)

proc parseClassrooms*(rawString: string): seq[string] =
  if rawString.len == "Ауд. ".len: return @[] # актуально для занятий по физкультуре, по другим не видел
  for aud in rawString.split("Ауд. "):
    if aud.len != 0: result.add(aud)

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
  of "ME`OiM":
    return faEconomical
  of "YUridicheskij":
    return faLegal
  else:
    raise newException(ValueError, "Invalid faculty")

proc parseTime*(time: string): LessonTime =
  case time:
  of "8.00-9.20":
    return ltFirst
  of "09:35-10:55":
    return ltSecond
  of "11:05-12:25":
    return ltThird
  of "13:00-14:20":
    return ltFourth
  of "14:35-15:55":
    return ltFifth
  of "16:25-17:45":
    return ltSixth
  of "17:55-19:15":
    return ltSeventh
  of "19.25-20.45":
    return ltEighth

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

proc parseLessonType*(lType: string): LessonType =
  case lType:
  of "(лек)":
    return ltpLecture
  of "(лаб)":
    return ltpLaboratory
  of "(практическое)", "(практ/сем)":
    return ltpPractice
  of "(диф/зачет)", "(зач)", "(зачет)":
    return ltpCreditCourse
  of "(конс)":
    return ltpConsultation
  of "(экзамен)":
    return ltpExam

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
    return "08:00 - 9:20"
  of ltSecond:
    return "09:35 - 10:55"
  of ltThird:
    return "11:05 - 12:25"
  of ltFourth:
    return "13:00 - 14:20"
  of ltFifth:
    return "14:35 - 15:55"
  of ltSixth:
    return "16:25 - 17:45"
  of ltSeventh:
    return "17:55 - 19:15"
  of ltEighth:
    return "19.25 - 20.45"

proc `$%`*(lt: LessonTime): TimeTuple =
  case lt:
  of ltFirst:
    return (8, 0)
  of ltSecond:
    return (9, 35)
  of ltThird:
    return (11, 5)
  of ltFourth:
    return (13, 0)
  of ltFifth:
    return (14, 35)
  of ltSixth:
    return (16, 25)
  of ltSeventh:
    return (17, 55)
  of ltEighth:
    return (19, 25)

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

proc `$`*(lesson: Lesson): string =
  var items = @[$lesson.lessonTime]
  if lesson.classrooms.len != 0: items.add("Ауд. " & lesson.classrooms.join(", "))
  items.add(lesson.name)
  items.add($lesson.lType)
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
    return "ME`OiM"
  of faLegal:
    return "YUridicheskij"

proc newSite*(): Site =
  new(result)
  result.faculties = newSeq[SelectOption]()
  result.groups = newSeq[Group]()

proc newGroup*(site: Site, id, display: string,
  course: Course, form: Form, faculty: Faculty,
  weeks: Option[seq[SelectOption]]): Group =
  result = Group(
    site: site,
    id: id,
    display: display,
    course: course,
    form: form,
    faculty: faculty,
    weeks: newSeq[SelectOption]()
  )
  if weeks.isSome: result.weeks = weeks.get

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