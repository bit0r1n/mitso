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

const
  SCHEDULE_BASE* = "https://apps.mitso.by/frontend/web/schedule"
  SCHEDULE_MAIN_PAGE* = SCHEDULE_BASE & "/group-schedule"
  SCHEDULE_FORMS* = SCHEDULE_BASE & "/education"
  SCHEDULE_COURSE* = SCHEDULE_BASE & "/course"
  SCHEDULE_GROUP* = SCHEDULE_BASE & "/group"
  SCHEDULE_WEEK* = SCHEDULE_BASE & "/week"

  SCHEDULE_API_FORMS* = SCHEDULE_BASE & "/forms"
  SCHEDULE_API_COURSES* = SCHEDULE_BASE & "/courses"
  SCHEDULE_API_GROUPS* = SCHEDULE_BASE & "/groups"
  SCHEDULE_API_LESSONS* = SCHEDULE_BASE & "/group-schedules"
  SCHEDULE_API_TEACHERS* = SCHEDULE_BASE & "/teachers-list"
  SCHEDULE_API_TEACHER_SUBJECTS* = SCHEDULE_BASE & "/teacher-subjects"
  SCHEDULE_API_TEACHER_LESSONS* = SCHEDULE_BASE & "/teacher-schedules"
  SCHEDULE_API_TEACHER_SUBJECT_LESSONS* = SCHEDULE_BASE & "/teacher-subject-schedules"

  INVALID_GROUP_ID* = "Auditoriya" # ???
  INVALID_TEACHERS* = @[ "Преподаватель 0. 0.", "Преподаватель к.", "_Вакансия" ] # =((
  LESSON_DURATION* = (1_000 * 60) * 85

  ACCOUNT_LOGIN* = "https://student.mitso.by/login_stud.php"
