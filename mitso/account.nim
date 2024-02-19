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

import std/[
  asyncdispatch, httpclient, net,
  strformat, options, htmlparser,
  xmltree, strutils
]

import private/constants, typedefs

proc isLoggedIn(content: XmlNode): bool =
  let inputs = content.findAll("input")
  if inputs.len != 0: return false

  let tds = content.findAll("td")
  if tds[1].innerText.strip.len == 0: return false # [ 0, 1 ] = [ "Баланс: ", float ]

  return true

proc login*(account: Account, login, password: string) {.async.} =
  ## Авторизация в аккаунт, при успешном входе данные будут сохранены в объект
  var client = newAsyncHttpClient(sslContext = newContext(verifyMode = CVerifyNone))

  let
    response = await client.request(
      ACCOUNT_LOGIN, HttpPost, &"login={login}&password={password}",
      newHttpHeaders({ "Content-Type": "application/x-www-form-urlencoded" }))
    accountBody = await response.body
    doc = parseHtml(accountBody)

  if not isLoggedIn(doc): raise newException(AccountFailedLoginError, "Invalid account credentials")

  for el in doc.findAll("div"):
    if el.attr("class") == "topmenu":
      account.fullName = some el.innerText.strip
      break

  for i, el in doc.findAll("td"):
    if i mod 2 != 1: continue

    let value = parseFloat(el.innerText)

    case i:
    of 1:
      account.balance = some value
    of 3:
      account.debt = some value
    of 5:
      account.penalty = some value
    else: discard

  account.fetched = true
