FROM alpine:latest AS bash-builder
RUN apk add --no-cache gcc make musl-dev patch ncurses-dev curl ca-certificates \
    && update-ca-certificates \
    && curl -fsSL https://ftp.gnu.org/gnu/bash/bash-3.2.tar.gz | tar xz -C /tmp \
    && cd /tmp/bash-3.2 \
    && curl -fsSL -o support/config.guess 'https://raw.githubusercontent.com/gcc-mirror/gcc/master/config.guess' \
    && curl -fsSL -o support/config.sub 'https://raw.githubusercontent.com/gcc-mirror/gcc/master/config.sub' \
    && ./configure --prefix=/usr --without-bash-malloc --disable-nls \
       CC="gcc -std=gnu89" \
    && make \
    && make install

FROM alpine:latest
RUN apk add --no-cache git openssh yq
COPY --from=bash-builder /usr/bin/bash /usr/bin/bash
COPY main.sh /usr/local/bin/ows
RUN chmod +x /usr/local/bin/ows
ENTRYPOINT ["tail", "-f", "/dev/null"]
