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

import strutils, httpclient, asyncdispatch, uri, strformat
from ../typedefs import ScheduleServiceError

proc debug*(args: varargs[string, `$`]): void =
  if defined(debug):
    echo args.join(" ")

proc requestWithRetry*(client: HttpClient | AsyncHttpClient; url: Uri | string;
             httpMethod: HttpMethod | string = HttpGet; body = "";
             headers: HttpHeaders = nil; multipart: MultipartData = nil): Future[Response | AsyncResponse] {.multisync, gcsafe.} =
  try:
    result = await client.request(url, httpMethod, body, headers, multipart)
    debug url, " ", result.status
  except:
    result = await client.requestWithRetry(url, httpMethod, body, headers, multipart)

converter toFullString*(values: HttpHeaderValues): string =
  return seq[string](values).join("; ")

proc newScheduleServiceError(endpoint: string): ScheduleServiceError =
  new(result)
  result.endpoint = endpoint
  result.msg = &"Schedule service ({endpoint}) response contains invalid Content-Type"

proc handleNonJsonResponse*(response: AsyncResponse | Response, endpoint: string) {.multisync.} =
  if "application/json" notin response.headers["content-type", 0]:
    debug &"[{endpoint}]", "Сервер отправил контент не с ожидаемым типом контента",
      " ", response.status

    raise newScheduleServiceError(endpoint)