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

import strutils, httpclient, asyncdispatch, uri

proc debug*(args: varargs[string, `$`]): void =
  if defined(debug):
    echo args.join(" ")

proc requestWithRetry*(client: HttpClient | AsyncHttpClient; url: Uri | string;
             httpMethod: HttpMethod | string = HttpGet; body = "";
             headers: HttpHeaders = nil; multipart: MultipartData = nil): Future[Response | AsyncResponse] {.multisync, gcsafe.} =
  try:
    result = await client.request(url, httpMethod, body, headers, multipart)
    debug url, " ", result.status, " ",
      if "html" notin result.headers["content-type"]: await result.body() else: ""
  except:
    result = await client.requestWithRetry(url, httpMethod, body, headers, multipart)

converter toFullString*(values: HttpHeaderValues): string =
  return seq[string](values).join("; ")