# Multi-stage Dockerfile for Go application with security best practices
# Builds minimal, secure container image for apqx-platform sample app

# Build stage
FROM golang:1.21-alpine@sha256:96634e55b363cb93d39f78fb18aa64da5a281e9f85560c6d68330c46aaa1b2e4 AS builder

# Install dependencies and create non-root user in single layer
WORKDIR /build
RUN apk --no-cache add ca-certificates git && \
    adduser -D -s /bin/sh -u 1001 appuser

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download && go mod verify

# Copy source code
COPY . .

# Build the application with security flags
RUN CGO_ENABLED=0 GOOS=linux go build \
    -a -installsuffix cgo \
    -ldflags '-extldflags "-static" -s -w' \
    -o main .

# Production stage - minimal distroless image
FROM gcr.io/distroless/static-debian11@sha256:ce46866b3a5170db3e11853eee6a96b8b2e934b0b4c23076e70b3d35e8efcf0b

# Security: Use non-root user
USER 1001:1001

# Copy the binary from builder stage
COPY --from=builder /build/main /

# Copy CA certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["/main"]

# Run the application
ENTRYPOINT ["/main"]