FROM golang:1.19.3@sha256:241ae1a3d3c67a7285010eae710adaf58b7f6c54864155a389ea4229ce67a9ee AS protoc-gen-go
RUN mkdir /app
WORKDIR /app
COPY go.mod .
COPY go.sum .
RUN go mod download
RUN go build -o /protoc-gen-go github.com/golang/protobuf/protoc-gen-go
RUN go build -o /protoc-gen-twirp github.com/twitchtv/twirp/protoc-gen-twirp


FROM alpine:3.16.3@sha256:b95359c2505145f16c6aa384f9cc74eeff78eb36d308ca4fd902eeeb0a0b161b AS buf

# renovate: datasource=github-releases depName=bufbuild/buf versioning=semver
ARG BUF_VERSION=v1.9.0
ARG BUF_CHECKSUM=77c9b27bacb037b6db8ec99e6b3933719161be31b42a2d4dbb7355909adefea7

ARG BUF_MINISIGN_KEY=RWQ/i9xseZwBVE7pEniCNjlNOeeyp4BQgdZDLQcAohxEAH5Uj5DEKjv6
ARG BUFF_URL=https://github.com/bufbuild/buf/releases/download/${BUF_VERSION}/buf-Linux-x86_64
ARG BUFF_DIGESTS_URL=https://github.com/bufbuild/buf/releases/download/${BUF_VERSION}/sha256.txt
RUN apk --no-cache add curl \
  && apk --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community add minisign \
  && mkdir -p /buf \
  && curl -Lo /buf/sha256.txt "$BUFF_DIGESTS_URL" \
  && curl -Lo /buf/sha256.txt.minisig "$BUFF_DIGESTS_URL.minisig" \
  && minisign -Vm /buf/sha256.txt -P "$BUF_MINISIGN_KEY" \
  && grep -q "$BUF_CHECKSUM" /buf/sha256.txt \
  && curl -o /usr/local/bin/buf -L "$BUFF_URL" \
  && echo "$BUF_CHECKSUM  /usr/local/bin/buf" | sha256sum -c \
  && chmod +x /usr/local/bin/buf \
  && apk del curl minisign

FROM gcr.io/distroless/static-debian11:latest@sha256:5759d194607e472ff80fff5833442d3991dd89b219c96552837a2c8f74058617
COPY --from=buf /usr/local/bin/buf /usr/local/bin/buf
COPY --from=protoc-gen-go /protoc-gen-go /usr/local/bin/protoc-gen-go
COPY --from=protoc-gen-go /protoc-gen-twirp /usr/local/bin/protoc-gen-twirp
