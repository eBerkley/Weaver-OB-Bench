FROM golang:1.24-bookworm AS builder


WORKDIR /build

COPY telemetry/. .

RUN go mod download

RUN go build -o collector

# ALSO ADD ABBR FILE!
COPY abbr.cfg abbrfile.txt
# FROM ubuntu:latest

RUN apt-get update -y && apt-get install -y bash curl jq vim && rm -rf /var/lib/apt/lists/*
# WORKDIR /app

# COPY --from=builder /build/collector /app/collector

ENTRYPOINT [ "bash" ]