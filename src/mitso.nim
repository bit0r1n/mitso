import mitsopkg/[parser, typedefs, helpers]

when not isMainModule:
  export parser, typedefs, helpers
else:
  import asyncdispatch, os, strutils, options
  import telebot, redis
  let
    bot = newTeleBot(getEnv("BOT_TOKEN"))
    redisClient = await openAsync(
      getEnv("DB_HOST"),
      parseInt(getEnv("DB_PORT")).Port
    )

  if getEnv("DB_AUTH").len != 0:
    if getEnv("DB_USER").len != 0:
      await redisClient.auth(getEnv("DB_USER"), getEnv("DB_AUTH"))
    else:
      await redisClient.auth(getEnv("DB_AUTH"))

  proc updateHandler(b: Telebot, u: Update): Future[bool] {.gcsafe, async.} =
    if u.message.isSome:
      discard await b.sendMessage(u.message.get().chat.id, "test")

  bot.onUpdate(updateHandler)
  bot.poll(timeout = 300) 