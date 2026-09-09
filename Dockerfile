FROM --platform=$BUILDPLATFORM golang:1.26.3-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

RUN apk update && apk add --no-cache make

WORKDIR /src

COPY go* .
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} make NAME=main build
RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} make install_xray

FROM alpine:latest

LABEL org.opencontainers.image.source="https://github.com/PasarGuard/node"

RUN apk update && apk add --no-cache wireguard-tools nftables iproute2 procps openssl

WORKDIR /app
COPY --from=builder /src/main /app/main
COPY --from=builder /usr/local/bin/xray /usr/local/bin/xray
COPY --from=builder /usr/local/share/xray /usr/local/share/xray

RUN mkdir -p /var/lib/pg-node/certs

ENTRYPOINT ["sh", "-c", "openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -keyout /var/lib/pg-node/certs/ssl_key.pem -out /var/lib/pg-node/certs/ssl_cert.pem -days 3650 -nodes -subj '/CN=thomas.proxy.rlwy.net' -addext 'subjectAltName=DNS:thomas.proxy.rlwy.net' && echo '===CERTIFICATE START===' && cat /var/lib/pg-node/certs/ssl_cert.pem && echo '===CERTIFICATE END===' && exec ./main"]