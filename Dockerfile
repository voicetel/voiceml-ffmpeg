# Build environment for the Linux x64, Linux arm64 and Windows x64 builds.
# The macOS builds are made on a Mac with build.sh directly.
FROM debian:bookworm-slim@sha256:99c0b25c46d0214d5a2091092e7908907dcaecd6a962cde0ac700acee222b6f3
RUN apt-get update && apt-get install -y --no-install-recommends \
	build-essential nasm pkg-config xz-utils bzip2 ca-certificates file \
	autoconf automake libtool \
	gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libc6-dev-arm64-cross \
	gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 binutils-mingw-w64-x86-64 \
	&& rm -rf /var/lib/apt/lists/*
WORKDIR /work
