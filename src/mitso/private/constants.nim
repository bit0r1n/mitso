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

const SCHELDUE_BASE* = "https://apps.mitso.by/schedule"
const SCHELDUE_FORMS* = SCHELDUE_BASE & "/education"
const SCHELDUE_COURSE* = SCHELDUE_BASE & "/course"
const SCHELDUE_GROUP* = SCHELDUE_BASE & "/group"
const SCHELDUE_WEEK* = SCHELDUE_BASE & "/week"
const INVALID_GROUP_ID* = "Auditoriya" # ???
const INVALID_TEACHER* = "Преподаватель 0. 0." # =((
const LESSON_DURATION* = (1_000 * 60) * 80