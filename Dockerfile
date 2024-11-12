# Stage 1: Build
FROM nimlang/nim:ubuntu AS builder
WORKDIR /app
COPY . .
RUN nim c -d:release main.nim

# Stage 2: Run
FROM ubuntu:latest
WORKDIR /app
COPY --from=builder /app/main .
CMD ["./main"]
