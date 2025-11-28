FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY migrator/go.mod .
COPY migrator/go.sum .

RUN go mod download

COPY migrator/ .

RUN go build -o migrator .

FROM alpine:latest

RUN apk --no-cache add postgresql-client

WORKDIR /root/

COPY --from=builder /app/migrator .

ENTRYPOINT ["./migrator"]
