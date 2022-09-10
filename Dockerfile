FROM nimlang/nim:latest-alpine

WORKDIR /mitso
COPY . .

RUN [ "nimble", "-y", "build" ]

ENTRYPOINT [ "./mitso" ]