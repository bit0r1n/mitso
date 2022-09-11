FROM nimlang/nim:1.6.2-alpine

WORKDIR /mitso
COPY . .

RUN [ "nimble", "-y", "build" ]

ENTRYPOINT [ "./mitso" ]