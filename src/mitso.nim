import mitsopkg/[parser, typedefs, helpers]

when not isMainModule:
  export parser, typedefs, helpers
else:
  import asyncdispatch, os, strutils, options, tables, sequtils, unicode, re
  import telebot, redis
  import database

  proc main() {.async.} =
    let
      bot = newTeleBot(getEnv("BOT_TOKEN"))
      site = newSite()
      redisClient = await openAsync(
        getEnv("DB_HOST"),
        parseInt(getEnv("DB_PORT")).Port
      )
      keyboards = {
        usAskingGroup: ReplyKeyboardMarkup(
          keyboard: @[]
        ),
        usChoosingGroup: ReplyKeyboardMarkup(
          keyboard: @[
            @[KeyboardButton(text: "Отмена")]
          ],
          resizeKeyboard: some true
        ),  
        usMainMenu: ReplyKeyboardMarkup(
          keyboard: @[
            @[
              KeyboardButton(text: "Сегодня"),
              KeyboardButton(text: "Завтра"),
              KeyboardButton(text: "Неделя")
            ],
            @[
              KeyboardButton(text: "Сменить группу")
            ]
          ],
          resizeKeyboard: some true
        )
      }.toTable

    echo "Parsing site"
    discard await site.init()
    echo "Done"

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
        let state = await redisClient.getState(c.message.chat.id)
        var content: string;
        case state:
        of usAskingGroup:
          content = "🍆 Погоди, я пока жду от тебя номер группы"
        of usChoosingGroup:
          content = "🙄 Где-то выше есть сообщение с группами. Выбери из того сообщения группу"
        of usMainMenu:
          content = "🍉 Хватай меню"

        if keyboards.hasKey(state):
          discard await b.sendMessage(c.message.chat.id, content, replyMarkup = keyboards[state])
        else:
          discard await b.sendMessage(c.message.chat.id, content)
        return true

    proc updateHandler(b: Telebot, u: Update): Future[bool] {.async, gcsafe.} =
      if u.callbackQuery.isSome:
        if u.callbackQuery.get().data.get().startsWith("selectgroup."):
          let
            uID = u.callbackQuery.get().fromUser.id
            gID = u.callbackQuery.get().data.get()["selectgroup.".len..^1]

          await redisClient.setGroup(uID, gID)
          await redisClient.setState(uID, usMainMenu)

          discard await b.sendMessage(
            u.callbackQuery.get().message.get().chat.id,
            "💀 Выбрана группа " & (site.groups.filter do (x: Group) -> bool: x.id == gID)[0].display,
            replyMarkup = keyboards[usMainMenu]
          )
          return true
      if u.message.isSome and u.message.get().text.isSome and not u.message.get().text.get().startsWith('/'):
        let
          uID = u.message.get().chat.id
          uExists = await redisClient.stateExists(uID)
          content = u.message.get().text.get()

        if content.toLower().match(re"^иди|пош(е|ё)л нахуй"): # @KrosBite
          discard await b.sendMessage(uID, "сам иди")
          return true
        if not uExists:
          discard await b.sendMessage(uID, "🤔 Что-то я тебя не припоминаю. Пропиши /start для начала")
          return true

        let state = await redisClient.getState(uID)
        case state:
        of usAskingGroup:
          let groups = site.groups.filter do (x: Group) -> bool: x.display.contains(content)
          if groups.len == 0:
            discard await b.sendMessage(uID, "💀 Такая группа не нашлась =(\nПопробуй отправить другой номер группы")
            return true
          else:
            await redisClient.setState(uID, usChoosingGroup)
            discard await b.sendMessage(uID, "👢 Выбери группу",
              replyMarkup = newInlineKeyboardMarkup(groups.map do (x: Group) -> InlineKeyboardButton:
                result = initInlineKeyboardButton(x.display)
                result.callbackData = some("selectgroup." & x.id)
              )
            )
            return true
        of usChoosingGroup:
          discard await b.sendMessage(uID, "🙄 Где-то выше есть сообщение с группами. Выбери из того сообщения группу")
        of usMainMenu:
          case content:
          of "Сегодня":
            discard await b.sendMessage(uID, "Нет блин завтра")
          of "Завтра":
            discard await b.sendMessage(uID, "Нет блин сегодня")
          of "Неделя":
            discard await b.sendMessage(uID, "жоска")
          of "Сменить группу":
            discard await b.sendMessage(uID, "не")

    bot.onCommand("start", startCommand)
    bot.onUpdate(updateHandler)
    bot.poll(timeout = 300)

  waitFor main()