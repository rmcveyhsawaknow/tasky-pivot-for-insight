# Building the binary of the App
FROM golang:1.19 AS build

WORKDIR /go/src/tasky
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /go/src/tasky/tasky

# Production image
FROM alpine:3.17.0 as release

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1001 -S appgroup && adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# Copy application binary and assets
COPY --from=build --chown=appuser:appgroup /go/src/tasky/tasky .
COPY --from=build --chown=appuser:appgroup /go/src/tasky/assets ./assets
COPY --from=build --chown=appuser:appgroup /go/src/tasky/exercise.txt .

# Switch to non-root user
USER appuser

EXPOSE 8080

ENTRYPOINT ["/app/tasky"]


