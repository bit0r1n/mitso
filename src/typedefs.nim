import options, times

type
  Site* = ref object
    content*: Option[string]
    faculties*: seq[SelectOption]
    groups*: seq[Group]
  Group* = ref object
    site*: Site
    id*: string
    display*: string
    course*: Course
    form*: Form
    faculty*: Faculty
    weeks*: seq[SelectOption]
  Lesson* = ref object
    date*: DateTime
    name*: string
    teachers*: seq[string]
    lessonTime*: LessonTime
    lType*: LessonType
    classrooms*: seq[string]
  ScheldueDay* = ref object
    date*: DateTime
    displayDate*: string
    day*: WeekDay
    lessons*: seq[Lesson]
  TimeTuple* = tuple
    hours: int
    minutes: int
  SelectOption* = tuple
    id: string
    display: string
  Form* = enum
    foFullTime
    foPartTime
    foPartTimeReduced
  Course* = enum
    cFirst
    cSecond
    cThird
    cFourth
    cFifth
  Faculty* = enum
    faMagistracy
    faEconomical
    faLegal
  LessonTime* = enum
    ltFirst
    ltSecond
    ltThird
    ltFourth
    ltFifth
    ltSixth
    ltSeventh
    ltEighth
  LessonType* = enum
    ltpLecture
    ltpPractice
    ltpCreditCourse
    ltpConsultation
    ltpExam