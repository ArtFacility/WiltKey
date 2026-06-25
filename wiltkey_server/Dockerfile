# Build Stage
FROM golang:1.26-alpine AS builder

WORKDIR /app

# Copy dependency files and download
COPY go.mod go.sum ./
RUN go mod download

# Copy source code and build
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -o wiltkey-relay .

# Run Stage
FROM alpine:latest

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/wiltkey-relay .

# Expose server port
EXPOSE 8000

# Set default envs (can be overridden by docker-compose)
ENV PORT=8000
ENV REDIS_ADDR=localhost:6379

CMD ["./wiltkey-relay"]
