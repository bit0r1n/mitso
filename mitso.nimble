# Package

version       = "0.1.1"
author        = "bit0r1n"
description   = "крутой бот митсо расписание арбуз парсинг"
license       = "GPL-3.0-or-later"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["mitso"]


# Dependencies

requires "nim >= 1.6.2"
requires "telebot"