# build the filestash binary from source; runs on the build platform and cross compiles for the target
FROM --platform=${BUILDPLATFORM} golang:1.27-alpine AS builder

# install git (needed to clone and by `go generate` to embed the build ref) and make
RUN apk add --no-cache git make

# git ref (branch or commit id) to build; pass the latest commit id on master to bust the cache when it changes
ARG FILESTASH_REF=master

WORKDIR /go/src/filestash

# clone only the requested ref (the .git dir is needed by `go generate` to embed the build ref)
RUN git init -q . &&\
  git remote add origin https://github.com/mickael-kerjean/filestash.git &&\
  git fetch -q --depth 1 origin "${FILESTASH_REF}" &&\
  git checkout -q FETCH_HEAD

# same steps upstream uses for its static release binaries: swap in the pure go image plugin, generate, and prune unneeded assets
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
  sed -i 's|plg_image_c|plg_image_golang|' server/plugin/index.go &&\
  make init &&\
  find ./public \( -name '*.map' -o -name pdf.sandbox.js -o -path '*/vendor/*.html' -o -path '*/codemirror/demo' -o -path '*/codemirror/doc' -o -path '*/codemirror/src' -o -path '*/codemirror/theme' -o -path '*/codemirror/bin' \) -prune -exec rm -rf {} +

# build a statically linked binary for the target platform
ARG TARGETOS
ARG TARGETARCH
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
  CGO_ENABLED=0 GOOS="${TARGETOS}" GOARCH="${TARGETARCH}" go build -trimpath -ldflags="-s -w" --tags fts5 -o /filestash cmd/main.go


# rebased/repackaged base image that only updates existing packages
FROM mbentley/alpine:latest
LABEL maintainer="Matt Bentley <mbentley@mbentley.net>"

# install gosu (to drop privileges)
RUN apk add --no-cache gosu

COPY --from=builder /filestash /opt/filestash/filestash.bin
COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/opt/filestash/filestash.bin"]
