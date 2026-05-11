FROM alpine:3.20 AS build

ARG ZIG_VERSION=0.15.2
ARG DUCKDB_VERSION=v1.2.2
ARG TARGETARCH

RUN apk add --no-cache build-base curl tar xz sqlite-dev ca-certificates unzip

WORKDIR /tmp
RUN case "${TARGETARCH}" in \
        amd64) ZIG_ARCH="x86_64" ;; \
        arm64) ZIG_ARCH="aarch64" ;; \
        *) echo "Unsupported Docker target architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSLO "https://ziglang.org/download/${ZIG_VERSION}/zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz" \
    && tar -xf "zig-${ZIG_ARCH}-linux-${ZIG_VERSION}.tar.xz" \
    && mv "zig-${ZIG_ARCH}-linux-${ZIG_VERSION}" /opt/zig

RUN case "${TARGETARCH}" in \
        amd64) DUCKDB_ARCH="amd64" ;; \
        arm64) DUCKDB_ARCH="aarch64" ;; \
        *) echo "Unsupported Docker target architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && curl -fsSLO "https://github.com/duckdb/duckdb/releases/download/${DUCKDB_VERSION}/libduckdb-linux-${DUCKDB_ARCH}.zip" \
    && unzip "libduckdb-linux-${DUCKDB_ARCH}.zip" -d /tmp/duckdb \
    && cp /tmp/duckdb/libduckdb.so /usr/local/lib/ \
    && cp /tmp/duckdb/duckdb.h /usr/local/include/ \
    && cp /tmp/duckdb/duckdb.hpp /usr/local/include/ \
    && ldconfig /usr/local/lib

ENV PATH="/opt/zig:${PATH}"

WORKDIR /app
COPY build.zig build.zig.zon ./
COPY src ./src
COPY cmd ./cmd
COPY db ./db

RUN zig version && zig build -Doptimize=ReleaseFast -Dduckdb-prefix=/usr/local
RUN mkdir -p /app/zig-out/lib \
    && find /app/.zig-cache -name 'libfacil.io.so' -exec cp '{}' /app/zig-out/lib/ \; \
    && test -f /app/zig-out/lib/libfacil.io.so

FROM alpine:3.20 AS runtime

RUN apk add --no-cache sqlite-libs ca-certificates

WORKDIR /app

COPY --from=build /app/zig-out/bin/umboard /usr/local/bin/umboard
COPY --from=build /app/zig-out/bin/umboard-cmd_create-user /usr/local/bin/umboard-cmd_create-user
COPY --from=build /app/zig-out/lib/libfacil.io.so /usr/local/lib/libfacil.io.so
COPY --from=build /usr/local/lib/libduckdb.so /usr/local/lib/libduckdb.so

RUN mkdir -p /app/db

ENV DATABASE_URL=sqlite:db/umboard.db

EXPOSE 5561

CMD ["/usr/local/bin/umboard"]
