# Build stage
FROM golang:1.23-alpine AS builder

WORKDIR /app

COPY server/go.mod server/go.sum ./
RUN go mod download

COPY server/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /familyledger ./cmd/server

# Runtime stage
FROM alpine:3.20

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app
COPY --from=builder /familyledger .
COPY server/migrations/ ./migrations/

ENV APP_ENV=production
ENV GRPC_PORT=50051
ENV WS_PORT=8080

EXPOSE 50051 8080

ENTRYPOINT ["./familyledger"]
