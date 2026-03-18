FROM alpine:latest
RUN apk add --no-cache bash git openssh yq
COPY main.sh /usr/local/bin/ows
RUN chmod +x /usr/local/bin/ows
ENTRYPOINT ["tail", "-f", "/dev/null"]
