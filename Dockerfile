FROM golang:1.23.1@sha256:4a3c2bcd243d3dbb7b15237eecb0792db3614900037998c2cd6a579c46888c1e AS protoc-gen-go
RUN mkdir /app
WORKDIR /app
COPY go.mod .
COPY go.sum .
RUN go mod download
RUN go build -o /protoc-gen-go github.com/golang/protobuf/protoc-gen-go
RUN go build -o /protoc-gen-twirp github.com/twitchtv/twirp/protoc-gen-twirp


FROM alpine:3.20.3@sha256:beefdbd8a1da6d2915566fde36db9db0b524eb737fc57cd1367effd16dc0d06d AS buf

# renovate: datasource=github-release-attachments depName=bufbuild/buf versioning=semver
ARG BUF_VERSION=v1.40.0
ARG BUF_CHECKSUM=0ee4e9eab4fceb970f66d88b7d2aa7b0b236a97b0c35c573c6babb750b0eff8b

ARG BUF_MINISIGN_KEY=RWQ/i9xseZwBVE7pEniCNjlNOeeyp4BQgdZDLQcAohxEAH5Uj5DEKjv6
ARG BUFF_URL=https://github.com/bufbuild/buf/releases/download/${BUF_VERSION}/buf-Linux-x86_64
ARG BUFF_DIGESTS_URL=https://github.com/bufbuild/buf/releases/download/${BUF_VERSION}/sha256.txt
RUN apk --no-cache add curl minisign \
  && mkdir -p /buf \
  && curl -Lo /buf/sha256.txt "$BUFF_DIGESTS_URL" \
  && curl -Lo /buf/sha256.txt.minisig "$BUFF_DIGESTS_URL.minisig" \
  && minisign -Vm /buf/sha256.txt -P "$BUF_MINISIGN_KEY" \
  && grep -q "$BUF_CHECKSUM" /buf/sha256.txt \
  && curl -o /usr/local/bin/buf -L "$BUFF_URL" \
  && echo "$BUF_CHECKSUM  /usr/local/bin/buf" | sha256sum -c \
  && chmod +x /usr/local/bin/buf \
  && apk del curl minisign

FROM gcr.io/distroless/static-debian11:latest@sha256:1dbe426d60caed5d19597532a2d74c8056cd7b1674042b88f7328690b5ead8ed
COPY --from=buf /usr/local/bin/buf /usr/local/bin/buf
COPY --from=protoc-gen-go /protoc-gen-go /usr/local/bin/protoc-gen-go
COPY --from=protoc-gen-go /protoc-gen-twirp /usr/local/bin/protoc-gen-twirp
