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
  strformat, xmltree,
  strutils
]
import private/constants, typedefs
import pkg/htmlparser

proc isLoggedIn(content: var XmlNode): bool =
  let inputs = content.findAll("input")
  if inputs.len != 0: return false

  let tds = content.findAll("td")
  if tds[1].innerText.strip.len == 0: return false # [ 0, 1 ] = [ "Баланс: ", float ]

  return true

proc fetchAccount*(login, password: string): Future[Account] {.async.} =
  ## Авторизация в аккаунт, при успешном входе данные будут сохранены в объект
  var
    ctx = newContext(verifyMode = CVerifyNone)
    client = newAsyncHttpClient(
      sslContext = ctx,
      userAgent = USER_AGENT
    )
    headers = newHttpHeaders({ "Content-Type": "application/x-www-form-urlencoded" })
    response = await client.request(
      ACCOUNT_LOGIN, HttpPost, &"login={login}&password={password}",
      headers = headers)
    accountBody = await response.body
    doc = parseHtml(accountBody)

  ctx.destroyContext()
  headers.clear()

  if not isLoggedIn(doc): raise newException(AccountFailedLoginError, "Invalid account credentials")

  new(result)

  for el in doc.findAll("div"):
    if el.attr("class") == "topmenu":
      result.fullName = el.innerText.strip
      break

  for i, el in doc.findAll("td"):
    if i mod 2 != 1: continue

    case i:
    of 1:
      result.balance = parseFloat(el.innerText)
    of 3:
      result.debt = parseFloat(el.innerText)
    of 5:
      result.penalty = parseFloat(el.innerText)
    else: discard

  doc.clear()
