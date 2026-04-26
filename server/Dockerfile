# Build stage
FROM golang:1.25-alpine AS builder

RUN apk add --no-cache git protobuf protobuf-dev

ENV GOPROXY=https://goproxy.cn,direct

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build
RUN CGO_ENABLED=0 go build -o /server ./cmd/server

# Run stage
FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /server .
COPY migrations/ ./migrations/

# Install migrate (auto-detect architecture)
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
      aarch64|arm64) MIGRATE_ARCH="arm64" ;; \
      x86_64|amd64) MIGRATE_ARCH="amd64" ;; \
      *) echo "Unsupported arch: $ARCH" && exit 1 ;; \
    esac && \
    wget -q "https://ghfast.top/https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.linux-${MIGRATE_ARCH}.tar.gz" -O migrate.tar.gz && \
    tar xzf migrate.tar.gz && \
    mv migrate /usr/local/bin/migrate && \
    rm migrate.tar.gz

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 50051 8080

ENTRYPOINT ["./entrypoint.sh"]
