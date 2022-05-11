FROM lukemathwalker/cargo-chef:latest-rust-1.59.0 as chef 
WORKDIR /app
RUN apt update && apt install lld clang -y

FROM chef as planner
COPY . .
# Compute a lock-like file for our project
RUN cargo chef prepare --recipe-path recipe.json

FROM chef as builder
COPY --from=planner /app/recipe.json recipe.json
# Build our project dependencies, not our application!
RUN cargo chef cook --release --recipe-path recipe.json
# Up to this point, if our dependency tree stays the same
# all layers should be cached.
# Copy files from working environment to docker image
COPY . .
# Read cached metadata for query validation at compile time
ENV SQLX_OFFLINE true
# Build the binary
RUN cargo build --release --bin zero2prod


# Runtime stage
FROM debian:bullseye-slim AS runtime
WORKDIR /app
# Install OpenSSL - it is dynamically linked by some of our dependencies # Install ca-certificates - it is needed to verify TLS certificates
# when establishing HTTPS connections
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
# Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/zero2prod zero2prod
COPY configuration configuration
# Pull correct configuration
ENV APP_ENVIRONMENT production

# Run this binary when `docker run` is executed
ENTRYPOINT ["./zero2prod"]