# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod ./
RUN go mod download

# Copy source code
COPY main.go ./

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o extractor .

# Runtime stage
FROM gcr.io/distroless/base-debian11

WORKDIR /

# Copy binary from builder
COPY --from=builder /app/extractor /extractor

# Run as non-root user
USER nonroot:nonroot

ENTRYPOINT ["/extractor"]
