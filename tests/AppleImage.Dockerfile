# Build Apple's bash distribution (bash-142) for macOS compatibility testing
FROM alpine:latest AS bash-builder
RUN apk add --no-cache gcc make musl-dev patch ncurses-dev curl ca-certificates bison \
    && update-ca-certificates \
    && curl -fsSL https://github.com/apple-oss-distributions/bash/archive/refs/tags/bash-142.tar.gz | tar xz -C /tmp \
    && cd /tmp/bash-bash-142/bash-3.2 \
    && curl -fsSL -o support/config.guess 'https://raw.githubusercontent.com/gcc-mirror/gcc/master/config.guess' \
    && curl -fsSL -o support/config.sub 'https://raw.githubusercontent.com/gcc-mirror/gcc/master/config.sub' \
    && sed -i 's/EBADEXEC/ENOEXEC/g' execute_cmd.c \
    && echo '#include <locale.h>' > /usr/include/xlocale.h \
    && ./configure --prefix=/usr --without-bash-malloc --disable-nls \
       CC="gcc -std=gnu99 -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion" \
    && echo '#define fmtcheck(f, d) (f)' >> config.h \
    && make \
    && make install

# Runtime
FROM alpine:latest
RUN apk add --no-cache git openssh yq
COPY --from=bash-builder /usr/bin/bash /usr/bin/bash
COPY main.sh /usr/local/bin/ows
RUN chmod +x /usr/local/bin/ows
ENTRYPOINT ["tail", "-f", "/dev/null"]
