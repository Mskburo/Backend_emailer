FROM lukemathwalker/cargo-chef:latest-rust-1-alpine3.17 AS chef
WORKDIR /app

FROM nim65s/cargo-binstall as binstal
RUN cargo binstall -y --target x86_64-unknown-linux-musl cargo-cache


FROM chef AS planner
COPY Cargo.toml .
COPY Cargo.lock .
COPY src/main.rs src/main.rs
RUN cargo chef prepare --recipe-path recipe.json

RUN apk add musl-dev sccache protoc protobuf-dev openssl libressl-dev
COPY --from=binstal /usr/local/cargo/bin/cargo-cache /usr/local/bin/cargo-cache
RUN cargo cache

FROM chef AS cacher 
RUN apk add musl-dev sccache protoc protobuf-dev openssl libressl-dev
COPY --from=planner /app/recipe.json recipe.json
RUN cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json


FROM chef AS builder 
ENV CARGO_HOME=/usr/local/cargo
ENV SCCACHE_DIR=/usr/local/sccache
COPY Cargo.toml .
COPY Cargo.lock .
COPY build.rs .
COPY ./src ./src
COPY ./proto ./proto
RUN apk add musl-dev sccache protoc protobuf-dev openssl libressl-dev
# Copy over the cached dependencies
COPY --from=cacher /app/target/ /app/target/
ARG SQLX_OFFLINE=true
RUN cargo build --release --target x86_64-unknown-linux-musl --bin emailer


FROM alpine AS runtime
EXPOSE 50051
RUN apk add protoc openssl
COPY ./templates ./templates
COPY --from=builder /app/target/x86_64-unknown-linux-musl/release/emailer /usr/local/bin/emailer
CMD ["/usr/local/bin/emailer"]