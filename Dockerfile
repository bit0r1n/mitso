FROM nimlang/nim:latest-alpine

RUN apk update
RUN apk update
RUN apk add --no-cache pcre-dev

WORKDIR /mitso
COPY . .

RUN [ "nimble", "-y", "build" ]

ENTRYPOINT [ "./mitso" ]