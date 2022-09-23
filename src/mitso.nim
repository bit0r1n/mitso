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
    along with this program.  If not, see <https://www.gnu.org/licenses/
]#

import mitsopkg/[parser, typedefs, helpers]

when not isMainModule:
  export parser, typedefs, helpers
else:
  import asyncdispatch, os, strutils, options, tables, sequtils, unicode, re, times
  import telebot, redis
  import database

  proc msgLesson(lesson: Lesson): string =
    var items = @["🍤 " & $lesson.lessonTime, $lesson.lType]
    if lesson.classrooms.len != 0: items.add("Ауд. " & lesson.classrooms.join(", "))
    items.add(lesson.name)
    if lesson.teachers.len != 0: items.add(lesson.teachers.join(", "))
    result = items.join(" | ")

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

    proc startCommand(b: Telebot, c: Command): Future[bool] {.async gcsafe.} =
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

    proc updateHandler(b: Telebot, u: Update): Future[bool] {.async gcsafe.} =
      if u.callbackQuery.isSome:
        let
          message = u.callbackQuery.get().message.get()
          callbackRawCommand = u.callbackQuery.get().data.get()
          callbackRawSeqCommand = callbackRawCommand.split(".")
          command = callbackRawSeqCommand[0]
          val = callbackRawSeqCommand[1]
        if command == "selectgroup":
          let
            uID = u.callbackQuery.get().fromUser.id
            gID = val

          await redisClient.setGroup(uID, gID)
          await redisClient.setState(uID, usMainMenu)

          try:
            discard await b.deleteMessage($uID, message.messageId)
          except:
            echo "Failed to delete message (selectgroup)"

          discard await b.sendMessage(
            uID,
            "💀 Выбрана группа " & (site.groups.filter do (x: Group) -> bool: x.id == gID)[0].display,
            replyMarkup = keyboards[usMainMenu]
          )
          return true
        elif command == "selectweek":
          let
            uID = u.callbackQuery.get().fromUser.id
            weekID = val

            groupID = await redisClient.getGroup(uID)
            group = (site.groups.filter do (x: Group) -> bool: x.id == groupID)[0]
            weeks = await group.getWeeks()

            reqWeek = weeks.filter do (x: SelectOption) -> bool: x.id == weekID

          try:
            discard await b.deleteMessage($uID, message.messageId)
          except:
            echo "Failed to delete message (selectweek)"

          if reqWeek.len == 0:
            discard await b.sendMessage(uID, "Неделя не нашлась")
            return true

          let
            scheldue = await group.getScheldue(reqWeek[0])
            headerText = "Распиание для " & reqWeek[0].display & " группы " & group.display & "\n"
            daysContent = headerText & (scheldue.map do (d: ScheldueDay) -> string:
                          "🥀 " & d.displayDate & ", " & $d.day & "\n" & d.lessons
                            .mapIt("\t\t" & msgLesson(it)).join("\n")).join("\n\n")

          discard await b.sendMessage(uID, daysContent)
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
          let
            uGroup = await redisClient.getGroup(uID)
            group = site.groups.filter do (x: Group) -> bool: x.id == uGroup
          case content:
          of "Сегодня", "Завтра": 
            let
              weeks = await group[0].getWeeks()
              curWeek = weeks.filter do (x: SelectOption) -> bool: x.display == "Текущая неделя"
            if curWeek.len == 0:
              discard await b.sendMessage(uID, "🤩 На " & (if content == "Сегодня": "сегодня" else: "завтра") & " нету расписания")
              return true

            var lookDay = now()
            if content == "Завтра": lookDay += 1.days
            let
              scheldue = await group[0].getScheldue(curWeek[0])
              curDay = scheldue.filter do (x: ScheldueDay) -> bool:
                x.date.monthday() == lookDay.monthday()

            if curDay.len == 0:
              discard await b.sendMessage(uID, "🤩 На " & (if content == "Сегодня": "сегодня" else: "завтра") & " нету расписания")
              return true

            let headerText = "Распиание на " & (if content == "Сегодня": "сегодня" else: "завтра") & " для группы " & group[0].display & "\n"

            discard await b.sendMessage(uID,
              headerText & "🥀 " & curDay[0].displayDate & ", " & $curDay[0].day & "\n" & curDay[0].lessons
                .mapIt("\t\t" & msgLesson(it)).join("\n")
            )
          of "Неделя":
            let
              weeks = await group[0].getWeeks()
              buttons = newInlineKeyboardMarkup(weeks.map do (x: SelectOption) -> InlineKeyboardButton:
                result = initInlineKeyboardButton(x.display)
                result.callbackData = some("selectweek." & x.id)
              )
            discard await b.sendMessage(uID, "Выбери неделю", replyMarkup = buttons)
          of "Сменить группу":
            discard await b.sendMessage(uID, "не")

    bot.onCommand("start", startCommand)
    bot.onUpdate(updateHandler)
    bot.poll(timeout = 300)

  waitFor main()