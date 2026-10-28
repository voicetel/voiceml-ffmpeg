# voiceml-ffmpeg

The ffmpeg program bundled with the VoiceML Phone desktop app, and the
complete source it is built from.

VoiceML Phone uses ffmpeg for one job: before a video clip is sent as an MMS,
the app runs ffmpeg to compress it to an MP4 of about 1 MB (H.264 video,
AAC audio). ffmpeg runs as a separate program, installed in the app's
`resources/ffmpeg` folder next to a copy of this README.

## License

The bundled ffmpeg is licensed under the **GNU General Public License,
version 2 or (at your option) any later version**.

- FFmpeg is mostly LGPL 2.1 or later. It becomes GPL here because it is built
  with `--enable-gpl` and linked with **x264** (GPL 2 or later), the H.264
  encoder. See `LICENSE.md`, `COPYING.GPLv2` and `COPYING.LGPLv2.1` in the
  ffmpeg source, and `COPYING` in the x264 source.
- No `--enable-nonfree` component is included, so the binaries may be
  redistributed under the GPL.
- The build scripts in this repository (`build.sh`, `Dockerfile`) are
  released under the same terms (GPL 2 or later); see `COPYING`.
- The VoiceML Phone app itself is a separate program under its own license;
  it only starts ffmpeg as a child process.

FFmpeg is a trademark of Fabrice Bellard, originator of the FFmpeg project.
x264 is developed by the VideoLAN project.

## Source

Every build is made only from the files listed in [`sources.txt`](sources.txt),
each checked against its SHA-256 by `build.sh` before use:

| Component | Version | Upstream |
|---|---|---|
| FFmpeg | 8.1.3 (release tarball, PGP-signed by the FFmpeg release key `FCF9 86EA 15E6 E293 A564 4F10 B432 2F04 D676 58D8`) | https://ffmpeg.org/releases/ffmpeg-8.1.3.tar.xz |
| x264 | stable branch, commit `b35605ace3ddf7c1a5d67a2eb553f034aef41d55` (2025-06-08) | https://code.videolan.org/videolan/x264 |

No patches are applied. The complete corresponding source for each release,
the two tarballs above plus the build scripts, is attached to the same
[GitHub release](../../releases) as the binaries it built. It stays there for
as long as those binaries are distributed.

## Builds

| Target | Built on |
|---|---|
| `linux-x64`, `linux-arm64` | Docker (`Dockerfile`, Debian bookworm, GCC cross compilers), statically linked |
| `win32-x64` | Docker (`Dockerfile`, MinGW-w64), statically linked |
| `darwin-x64`, `darwin-arm64` | macOS with Xcode, `nasm` and `pkg-config` (not yet released; until then the app sends macOS videos uncompressed) |

Each binary comes with a `BUILDINFO.txt` that gives its exact `configure`
line and SHA-256.

The configuration is deliberately small: every ffmpeg component is off except
what the app needs. That means the `file` protocol; the MP4/MOV/3GP,
Matroska/WebM, Ogg, MPEG-PS/TS and AVI demuxers; the decoders for common
phone and camera video and audio; scaling and rotation filters; the libx264
and native AAC encoders; and the MP4 muxer. There is no networking, no
`ffplay` and no `ffprobe`. AV1 input is not supported.

## Rebuilding

```sh
# Fetch the sources named in sources.txt into ./src (or take them from a
# release), then:
docker build -t voiceml-ffmpeg-builder .
docker run --rm -v "$PWD:/repo:ro" -v "$PWD/src:/src:ro" -v "$PWD/out:/out" \
	voiceml-ffmpeg-builder /repo/build.sh linux-x64 /src /out/linux-x64

# On a Mac:
./build.sh darwin-arm64 ./src ./out/darwin-arm64
```

## Written offer

If you cannot download the source from this repository's releases, VoiceTel
Communications will provide the complete corresponding source for any
distributed build on request, for at least three years after we last
distribute that build. Contact support@voicetel.com.
