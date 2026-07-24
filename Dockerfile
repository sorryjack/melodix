# ---- Stage 1: Builder ----
FROM golang:1.26-alpine AS builder

ENV GOPROXY=https://proxy.golang.org,direct

RUN apk add --no-cache git build-base alsa-lib-dev

WORKDIR /usr/project

COPY go.mod go.sum ./
COPY pkg ./pkg
RUN go mod download

COPY . .

RUN BUILD_DATE=$(date -u +"%Y-%m-%dT%H-%M-%SZ") && \
    GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "none") && \
    CGO_ENABLED=1 GOOS=linux GOARCH=amd64 go build \
        -o app \
        -ldflags="-s -w \
            -X github.com/keshon/buildinfo.Version=dev \
            -X github.com/keshon/buildinfo.Commit=${GIT_COMMIT} \
            -X github.com/keshon/buildinfo.BuildTime=${BUILD_DATE} \
            -X github.com/keshon/buildinfo.Project=Melodix \
            -X 'github.com/keshon/buildinfo.Description=Discord music bot that allows you to play music from YouTube, SoundCloud and internet radio streams.'" \
        ./cmd/discord/

# ---- Stage 2: Runtime ----
FROM alpine:latest

RUN apk add --no-cache \
        ffmpeg \
        python3 \
        py3-pip \
        libstdc++ \
        alsa-lib \
    && pip3 install --no-cache-dir --break-system-packages yt-dlp \
    && rm -rf /var/cache/apk/*

WORKDIR /usr/project
COPY --from=builder /usr/project/app ./app

RUN mkdir -p data && echo '{}' > data/datastore.json

EXPOSE 8080

ENTRYPOINT ["/usr/project/app"]
