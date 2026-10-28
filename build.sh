#!/usr/bin/env bash
# Build the ffmpeg that VoiceML Phone (desktop) bundles, from the sources
# pinned in sources.txt, for one target:
#
#   ./build.sh <target> <sources dir> <out dir>
#
#   target: linux-x64 | linux-arm64 | win32-x64   (in the Docker image)
#           darwin-x64 | darwin-arm64             (on a Mac with Xcode,
#                                                  nasm and pkg-config)
#
# The sources dir holds the files sources.txt names; each is checked against
# its sha256 before use. The out dir gets ffmpeg (ffmpeg.exe on Windows) and
# BUILDINFO.txt.
#
# The build is a small one: ffmpeg's components are all off, then only what
# VoiceML's video compression needs is turned on (read the clip types the
# platform takes, decode what phones and cameras record, scale, tone-map
# HDR to SDR with zimg, encode H.264 with libx264 and AAC with ffmpeg's own
# encoder, write MP4). libx264 makes the binary GPL (version 2 or later).
set -euo pipefail

TARGET=${1:?target}
SRC=$(cd "${2:?sources dir}" && pwd)
OUT=$(mkdir -p "${3:?out dir}" && cd "$3" && pwd)
HERE=$(cd "$(dirname "$0")" && pwd)
JOBS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)

FFMPEG_TAR=ffmpeg-8.1.3.tar.xz
X264_TAR=x264-b35605ace3ddf7c1a5d67a2eb553f034aef41d55.tar.bz2
ZIMG_TAR=zimg-3.0.6.tar.gz

sha256() {
	if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
	else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# Check every pinned source.
grep -v '^#' "$HERE/sources.txt" | while read -r name digest _url; do
	[ -n "$name" ] || continue
	got=$(sha256 "$SRC/$name")
	if [ "$got" != "$digest" ]; then
		echo "build.sh: $name sha256 $got, expected $digest" >&2
		exit 1
	fi
done

X264_HOST=""
X264_FLAGS=()
ZIMG_FLAGS=()
FF_FLAGS=()
EXE=ffmpeg
case "$TARGET" in
linux-x64)
	FF_FLAGS=(--extra-ldflags=-static)
	X264_FLAGS=(--extra-ldflags=-static)
	# A static glibc link needs libm after libstdc++.
	ZIMG_FLAGS=("STL_LIBS=-lstdc++ -lm")
	;;
linux-arm64)
	X264_HOST=aarch64-linux-gnu
	X264_FLAGS=(--cross-prefix=aarch64-linux-gnu- --extra-ldflags=-static)
	FF_FLAGS=(--enable-cross-compile --cross-prefix=aarch64-linux-gnu-
		--arch=aarch64 --target-os=linux --extra-ldflags=-static)
	ZIMG_FLAGS=("STL_LIBS=-lstdc++ -lm")
	;;
win32-x64)
	EXE=ffmpeg.exe
	X264_HOST=x86_64-w64-mingw32
	X264_FLAGS=(--cross-prefix=x86_64-w64-mingw32-)
	FF_FLAGS=(--enable-cross-compile --cross-prefix=x86_64-w64-mingw32-
		--arch=x86_64 --target-os=mingw32 --extra-ldflags=-static)
	;;
darwin-x64 | darwin-arm64)
	ARCH=$([ "$TARGET" = darwin-x64 ] && echo x86_64 || echo arm64)
	MIN=-mmacosx-version-min=11.0
	X264_HOST=$ARCH-apple-darwin
	X264_FLAGS=("--extra-cflags=-arch $ARCH $MIN" "--extra-ldflags=-arch $ARCH $MIN")
	FF_FLAGS=(--enable-cross-compile --arch="$ARCH" --target-os=darwin
		--cc=clang "--extra-cflags=-arch $ARCH $MIN"
		"--extra-ldflags=-arch $ARCH $MIN")
	ZIMG_FLAGS=("CC=clang -arch $ARCH $MIN" "CXX=clang++ -arch $ARCH $MIN"
		STL_LIBS=-lc++)
	;;
*)
	echo "build.sh: unknown target $TARGET" >&2
	exit 1
	;;
esac

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
PREFIX=$WORK/prefix

tar -xjf "$SRC/$X264_TAR" -C "$WORK"
(
	cd "$WORK"/x264-*
	./configure --prefix="$PREFIX" ${X264_HOST:+--host=$X264_HOST} \
		--enable-static --enable-pic --disable-cli --disable-opencl \
		--disable-lavf --disable-swscale --disable-ffms --disable-gpac \
		--disable-lsmash "${X264_FLAGS[@]}"
	make -j"$JOBS"
	make install-lib-static
)

tar -xzf "$SRC/$ZIMG_TAR" -C "$WORK"
(
	cd "$WORK"/zimg-*
	./autogen.sh
	./configure --prefix="$PREFIX" ${X264_HOST:+--host=$X264_HOST} \
		--enable-static --disable-shared "${ZIMG_FLAGS[@]}"
	make -j"$JOBS"
	make install
)

tar -xJf "$SRC/$FFMPEG_TAR" -C "$WORK"
(
	cd "$WORK"/ffmpeg-*
	PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" ./configure \
		--prefix="$PREFIX" --pkg-config=pkg-config --pkg-config-flags=--static \
		--extra-cflags="-I$PREFIX/include" --extra-ldflags="-L$PREFIX/lib" \
		"${FF_FLAGS[@]}" \
		--enable-gpl --enable-libx264 --enable-libzimg \
		--enable-static --disable-shared \
		--disable-everything --disable-autodetect --disable-network \
		--disable-doc --disable-debug --disable-ffplay --disable-ffprobe \
		--disable-avdevice --enable-swscale --enable-swresample \
		--enable-protocol=file \
		--enable-demuxer=mov,matroska,ogg,mpegps,mpegts,mpegvideo,h264,hevc,m4v,avi \
		--enable-decoder=h264,hevc,vp8,vp9,mpeg4,h263,h263p,mpeg1video,mpeg2video,mjpeg,theora,aac,aac_latm,mp3,mp3float,mp2,opus,vorbis,flac,alac,ac3,eac3,amrnb,amrwb,pcm_s16le,pcm_s16be,pcm_s24le,pcm_s32le,pcm_f32le,pcm_u8,pcm_alaw,pcm_mulaw,adpcm_ima_qt \
		--enable-parser=h264,hevc,vp8,vp9,mpeg4video,mpegvideo,h263,mjpeg,aac,aac_latm,mpegaudio,opus,vorbis,flac,ac3 \
		--enable-encoder=libx264,aac \
		--enable-muxer=mp4 \
		--enable-filter=scale,zscale,tonemap,format,null,aformat,aresample,anull,transpose,hflip,vflip,rotate,fps,setpts,asetpts,trim,atrim,copy,acopy,pad,crop,setsar,setdar,pan,amix,channelmap,channelsplit \
		--enable-bsf=h264_mp4toannexb,hevc_mp4toannexb,aac_adtstoasc,extract_extradata,vp9_superframe_split
	make -j"$JOBS"
	cp "$EXE" "$OUT/$EXE"
	CONFIGURATION=$(sed -n 's/^#define FFMPEG_CONFIGURATION "\(.*\)"$/\1/p' config.h)
	{
		echo "voiceml-ffmpeg build for $TARGET"
		echo "ffmpeg: $FFMPEG_TAR"
		echo "x264: $X264_TAR"
		echo "zimg: $ZIMG_TAR"
		echo "license: GPL version 2 or later (libx264)"
		echo "configuration: $CONFIGURATION"
		echo "sha256 $EXE: $(sha256 "$OUT/$EXE")"
	} >"$OUT/BUILDINFO.txt"
)
cat "$OUT/BUILDINFO.txt"
