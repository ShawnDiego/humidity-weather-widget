# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM swift:6.0-noble AS builder

WORKDIR /build

# Copy the Swift Package first so dependency resolution is cached separately
COPY WeatherCore/Package.swift WeatherCore/Package.resolved* ./
RUN swift package resolve 2>/dev/null || true

# Copy sources and build the release binary
COPY WeatherCore/Sources Sources/
RUN swift build -c release --product WeatherMonitor

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM ubuntu:24.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libcurl4 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/.build/release/WeatherMonitor /usr/local/bin/weather-monitor

ENTRYPOINT ["weather-monitor"]
# Default: fetch once and exit. Override with: docker run … --watch 1800
