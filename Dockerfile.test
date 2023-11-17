FROM golang:1.21.3-bookworm as builder

ENV CGO_ENABLED=0
ENV GO111MODULE=on
ENV ROOT /app
ENV OUT_DIR ${ROOT}/out
ENV PACKAGES="ca-certificates git curl bash zsh wget"

RUN apt-get update && apt-get --no-install-recommends install -y ${PACKAGES} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR ${ROOT}

COPY ./ ./

RUN go mod download && go build -o ${OUT_DIR} ${ROOT}/main.go

# --------------------------------------------------
FROM debian:12.2-slim as prod

ENV ROOT /app
ENV OUT_DIR ${ROOT}/out

USER nobody

WORKDIR ${ROOT}
COPY --from=builder --chown=nobody:nogroup ${OUT_DIR} /usr/local/bin/server

CMD [ "server" ]
