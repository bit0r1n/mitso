import strutils, redis, asyncdispatch
type
  DatabaseUserState* = enum
    usAskingGroup
    usChoosingGroup
    usMainMenu

proc state(id: int64): string = "user_state:" & $id
proc group(id: int64): string = "user_group:" & $id

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