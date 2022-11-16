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
    ltpLaboratory
    ltpCreditCourse
    ltpConsultation
    ltpExam
    ltpCourseProject
