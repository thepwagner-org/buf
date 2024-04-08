FROM golang:1.22.1@sha256:0b55ab82ac2a54a6f8f85ec8b943b9e470c39e32c109b766bbc1b801f3fa8d3b AS protoc-gen-go
RUN mkdir /app
WORKDIR /app
COPY go.mod .
COPY go.sum .
RUN go mod download
RUN go build -o /protoc-gen-go github.com/golang/protobuf/protoc-gen-go
RUN go build -o /protoc-gen-twirp github.com/twitchtv/twirp/protoc-gen-twirp


FROM alpine:3.19.1@sha256:c5b1261d6d3e43071626931fc004f70149baeba2c8ec672bd4f27761f8e1ad6b AS buf

# renovate: datasource=github-release-attachments depName=bufbuild/buf versioning=semver
ARG BUF_VERSION=v1.30.1
ARG BUF_CHECKSUM=06a41f5ada6c4d3b7a72ce6bb5daef9b8ec93c756232f4cbdfd054e77a7e50d7

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

FROM gcr.io/distroless/static-debian11:latest@sha256:046b92c933032a8ca99a66f4c79a68ac029d9a4ababd1a806a82140b3b899fd3
COPY --from=buf /usr/local/bin/buf /usr/local/bin/buf
COPY --from=protoc-gen-go /protoc-gen-go /usr/local/bin/protoc-gen-go
COPY --from=protoc-gen-go /protoc-gen-twirp /usr/local/bin/protoc-gen-twirp
