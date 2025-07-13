# ==============================================================================
# TASKY APPLICATION DOCKER IMAGE
# ==============================================================================
# Multi-stage build for optimized production image following security best practices
# Base image uses golang:1.19 for build and alpine:3.17.0 for runtime

# Stage 1: Build Dependencies
FROM golang:1.19-alpine AS deps
WORKDIR /go/src/tasky
# Copy dependency files first for better layer caching
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Stage 2: Build Application
FROM golang:1.19-alpine AS build
WORKDIR /go/src/tasky
# Copy dependency cache from deps stage
COPY --from=deps /go/pkg /go/pkg
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o tasky .

# Stage 3: Production Runtime
FROM alpine:3.17.0 AS production

# Install security updates and ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates tzdata && \
    apk upgrade --no-cache && \
    rm -rf /var/cache/apk/*

# Create non-root user with specific UID/GID for security
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy application binary and assets with proper ownership
COPY --from=build --chown=appuser:appgroup /go/src/tasky/tasky .
COPY --from=build --chown=appuser:appgroup /go/src/tasky/assets ./assets
COPY --from=build --chown=appuser:appgroup /go/src/tasky/exercise.txt .

# Set file permissions
RUN chmod +x /app/tasky

# Switch to non-root user for security
USER appuser

# Expose application port
EXPOSE 8080

# Health check for container orchestration
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Use ENTRYPOINT for better signal handling
ENTRYPOINT ["/app/tasky"]


