FROM lukemathwalker/cargo-chef:0.1.62-rust-slim-bookworm AS chef
WORKDIR /app
FROM nim65s/cargo-binstall as binstal
RUN cargo binstall -y --target x86_64-unknown-linux-gnu cargo-cache


FROM chef AS planner
COPY Cargo.toml .
COPY Cargo.lock .
COPY src/main.rs src/main.rs
RUN cargo chef prepare --recipe-path recipe.json


FROM chef AS cacher 

RUN apt update && apt upgrade -y
RUN apt-get install -y sccache protobuf-compiler libssl-dev pkg-config
COPY --from=binstal /usr/local/cargo/bin/cargo-cache /usr/local/bin/cargo-cache
RUN cargo cache
COPY --from=planner /app/recipe.json recipe.json
# ENV OPENSSL_INCLUDE_DIR = /usr/local/opt/openssl@3/include
# ENV OPENSSL_DIR = /usr/local/openss/linclude/
RUN cargo chef cook --release --target x86_64-unknown-linux-gnu --recipe-path recipe.json


FROM chef AS builder 
RUN apt update && apt upgrade -y
RUN apt-get install -y sccache protobuf-compiler libssl-dev pkg-config
ENV CARGO_HOME=/usr/local/cargo
ENV SCCACHE_DIR=/usr/local/sccache
# ENV OPENSSL_INCLUDE_DIR = /usr/local/opt/openssl@3/include
# ENV OPENSSL_DIR = /usr/local/openssl/linclude/
COPY Cargo.toml .
COPY Cargo.lock .
COPY build.rs .
COPY ./src ./src
COPY ./proto ./proto
COPY ./templates ./templates
# Copy over the cached dependencies
COPY --from=cacher /app/target/x86_64-unknown-linux-gnu/release /app/target/x86_64-unknown-linux-gnu/release
RUN cargo build --release --target x86_64-unknown-linux-gnu --bin emailer

FROM  busybox:1.35.0-glibc AS runtime
EXPOSE 50051
COPY --from=builder /app/target/x86_64-unknown-linux-gnu/release/emailer /usr/local/bin/emailer
CMD ["/usr/local/bin/emailer"]