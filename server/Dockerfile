# Build stage
FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git protobuf protobuf-dev

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -o /server ./cmd/server

# Run stage
FROM alpine:3.19

RUN apk add --no-cache ca-certificates

WORKDIR /app

COPY --from=builder /server .
COPY migrations/ ./migrations/

# Install migrate
RUN wget -q https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.linux-amd64.tar.gz -O migrate.tar.gz && \
    tar xzf migrate.tar.gz && \
    mv migrate /usr/local/bin/migrate && \
    rm migrate.tar.gz

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 50051 8080

ENTRYPOINT ["./entrypoint.sh"]
