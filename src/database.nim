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

import strutils, redis, asyncdispatch, jsony, strformat, times
import mitsopkg/typedefs
type
  DatabaseUserState* = enum
    usAskingGroup
    usChoosingGroup
    usMainMenu

proc state(id: int64): string = "user_state:" & $id
proc group(id: int64): string = "user_group:" & $id
proc dayKey(group: Group, day: ScheldueDay): string =
  fmt"scheldue_day:{$group.id}.{$day.date}"

proc parseHook*(s: string, i: var int, v: var DateTime) =
  var str: string
  parseHook(s, i, str)
  v = parse(str, "yyyy-MM-dd hh:mm:ss")

var dt = """ "2020-01-01 00:00:00" """.fromJson(DateTime)

proc stateExists*(r: Redis | AsyncRedis, user: int64): Future[bool] {.multisync.} =
  result = await r.exists(user.state)

proc setState*(r: Redis | AsyncRedis, user: int64, state: DatabaseUserState): Future[void] {.multisync.} =
  await r.setK(user.state, $state)

proc getState*(r: Redis | AsyncRedis, user: int64): Future[DatabaseUserState] {.multisync.} =
  let res = await r.get(user.state)
  if res == redisNil:
    raise newException(CatchableError, "User state not found")
  else:
    result = parseEnum[DatabaseUserState](res)

proc getGroup*(r: Redis | AsyncRedis, user: int64): Future[string] {.multisync.} =
  let res = await r.get(user.group)
  if res == redisNil:
    raise newException(CatchableError, "Group for user not found")
  else:
    result = res

proc setGroup*(r: Redis | AsyncRedis, user: int64, group: string): Future[void] {.multisync.} =
  await r.setK(user.group, group)
#[
proc setDay*(r: Redis | AsyncRedis, group: Group, day: ScheldueDay): Future[void] {.multisync.} = 
  let dayJson = day.toJson()
  await r.setK(dayKey(group, day), dayJson)

proc dayExists*(r: Redis | AsyncRedis, group: Group, day: ScheldueDay): Future[bool] {.multisync.} =
  result = await r.exists(dayKey(group, day))

proc getDay*(r: Redis | AsyncRedis, group: Group, day: ScheldueDay): Future[ScheldueDay] {.multisync.} =
  let res = await r.get(dayKey(group, day))
  if res == redisNil:
    raise newException(CatchableError, "Day not found")
  else:
    result = res.fromJson(ScheldueDay)
]#