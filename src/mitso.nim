import mitsopkg/[parser, typedefs, helpers]

when not isMainModule:
  export parser, typedefs, helpers
else:
  import asyncdispatch, os, strutils, options
  import telebot, redis
  import database

  proc main() {.async.} =
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

    proc startCommand(b: Telebot, c: Command): Future[bool] {.async, gcsafe.} =
      let uExists = await redisClient.stateExists(c.message.chat.id)
      if not uExists:
        await redisClient.setState(c.message.chat.id, usAskingGroup)
        discard await b.sendMessage(c.message.chat.id, "🍉 Привет, я могу тебе показывать расписание!\nТолько мне сначала нужно указать группу 😫")
        discard await b.sendMessage(c.message.chat.id, "🍳 Давай найдем твою группу. Напиши её номер.")
      else:
        #[ 
          check for state and respond with required content
            usAskingGroup - we still searching for group
            usChoosingGroup - hey, choose group, or click cancel (set keyboard ["cancel"])
            usMainMenu - here is your menu (set keyboard [[...scheldue], ["change group", ...idk]])
        ]#
        return true

    proc updateHandler(b: Telebot, u: Update): Future[bool] {.async, gcsafe.} =
      if u.message.isSome:
        let state = await redisClient.getState(u.message.get().chat.id)
        discard await b.sendMessage(u.message.get().chat.id, "test")

    bot.onCommand("start", startCommand)
    bot.onUpdate(updateHandler)
    bot.poll(timeout = 300)

  waitFor main()