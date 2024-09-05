FROM golang:1.23.0@sha256:1a6db32ea47a4910759d5bcbabeb8a8b42658e311bd8348ea4763735447c636c AS protoc-gen-go
RUN mkdir /app
WORKDIR /app
COPY go.mod .
COPY go.sum .
RUN go mod download
RUN go build -o /protoc-gen-go github.com/golang/protobuf/protoc-gen-go
RUN go build -o /protoc-gen-twirp github.com/twitchtv/twirp/protoc-gen-twirp


FROM alpine:3.20.2@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5 AS buf

# renovate: datasource=github-release-attachments depName=bufbuild/buf versioning=semver
ARG BUF_VERSION=v1.39.0
ARG BUF_CHECKSUM=657eaafbe1cbeafecfda15386004bd3253fc91162e68cd52185937e3ff4d7afe

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
