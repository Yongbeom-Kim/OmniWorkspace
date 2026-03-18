# Build Apple's bash distribution (bash-142) for macOS compatibility testing
#
# Apple's patched bash 3.2 uses macOS-specific APIs and BSD libc features that
# don't exist on Linux/musl. The shims below bridge those gaps:
#   - EBADEXEC: macOS errno, mapped to ENOEXEC (nearest Linux equivalent)
#   - xlocale.h: BSD/macOS header, stubbed with standard locale.h
#   - fmtcheck(): BSD libc function, stubbed as identity (returns format as-is)
#
# GCC 15 also promotes several C warnings to errors by default. The -Wno-* flags
# suppress these for this legacy K&R-era codebase.
FROM alpine:latest AS bash-builder
RUN apk add --no-cache gcc make musl-dev patch ncurses-dev curl ca-certificates bison \
    && update-ca-certificates \
    && curl -fsSL https://github.com/apple-oss-distributions/bash/archive/refs/tags/bash-142.tar.gz | tar xz -C /tmp \
    && cd /tmp/bash-bash-142/bash-3.2 \
    # Update config.guess/config.sub to recognize aarch64 (originals are from 2002)
    && curl -fsSL -o support/config.guess 'https://raw.githubusercontent.com/gcc-mirror/gcc/master/config.guess' \
    && curl -fsSL -o support/config.sub 'https://raw.githubusercontent.com/gcc-mirror/gcc/master/config.sub' \
    # Apple's bash uses EBADEXEC (macOS-specific errno), map to nearest Linux equivalent
    && sed -i 's/EBADEXEC/ENOEXEC/g' execute_cmd.c \
    # musl doesn't have xlocale.h (BSD/macOS extension) - stub with standard locale.h
    && echo '#include <locale.h>' > /usr/include/xlocale.h \
    && ./configure --prefix=/usr --without-bash-malloc --disable-nls \
       CC="gcc -std=gnu99 -Wno-implicit-function-declaration -Wno-implicit-int -Wno-incompatible-pointer-types -Wno-int-conversion" \
    # fmtcheck() is BSD libc only, stub as identity function (format validation only)
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
