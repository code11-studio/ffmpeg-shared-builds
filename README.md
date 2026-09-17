# ffmpeg-builds

Trimmed **shared** FFmpeg builds for Windows (x64 and ARM64): `ffmpeg.exe` + `ffprobe.exe` + `av*.dll`, meant
to be started as separate processes by a host application. Each release carries the binaries, `SHA256SUMS`, and
`ffmpeg-source.tar.xz`: the complete corresponding source (GPL v2 §3 / LGPL v2.1 §4).

Two flavours, one release each (`FLAVOR` in `prepare.sh`, `flavor` input in the workflow):

| Flavour | Add-in | BtbN variant | Zip | License | For |
|---|---|---|---|---|---|
| `trimmed` (default) | `addins/trimmed.sh` | `gpl-shared` | `ffmpeg-<target>-gpl-shared.zip` | GPL v2+ | Video Converter (x264/x265/SVT-AV1/libvpx, GPU encoders, subtitle burn-in) |
| `audio-lgpl` | `addins/audio-lgpl.sh` | `lgpl-shared` | `ffmpeg-<target>-lgpl-shared.zip` | LGPL v2.1+ | Audio Converter (all decoders, plus libopenmpt for tracker modules (x64 only) and libcodec2 for `.c2` speech; LAME, AAC, Opus, Vorbis, FLAC, ALAC, PCM, WMA, AC-3 encoders; loudnorm) |

The audio flavour is built without `--enable-gpl`, `--enable-nonfree` and `--enable-version3`, and its
`verify-ffmpeg.ps1 -Profile audio` run refuses any GPL component. The rest of this file describes the video flavour;
the audio one only swaps the add-in and the dependency roots.

## What is in it

All FFmpeg **decoders, demuxers, parsers and bitstream filters** stay enabled, so any input opens. Only the
encoders, muxers and filters listed in the add-in are enabled, and only these external libraries are built:

| Library | Why |
|---|---|
| x264, x265 | Software H.264 / HEVC encoding |
| SVT-AV1 | AV1 encoding |
| dav1d | AV1 decoding |
| libvpx | VP9 encoding (WebM) |
| opus | Opus audio (WebM) |
| LAME | MP3 output |
| libass + freetype + harfbuzz + fribidi | Subtitle burn-in |
| zimg | `zscale` for HDR → SDR tone-mapping |
| zlib, libiconv | Compressed MKV tracks, PNG, non-UTF-8 subtitles |
| nv-codec-headers, AMF, libvpl (x64 only), Media Foundation | GPU encoders |

The exact configure switches live in [`addins/trimmed.sh`](addins/trimmed.sh); the kept dependency
scripts are listed in [`prepare.sh`](prepare.sh).

## How it is built

The build is a thin layer over [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds) (Docker + mingw-w64 /
llvm-mingw), pinned to one commit in `prepare.sh`. CI runs
[`.github/workflows/ffmpeg.yml`](.github/workflows/ffmpeg.yml):

1. `prepare.sh` clones BtbN at `BTBN_COMMIT`, computes the transitive dependency closure of the root libraries
   listed in its `ROOTS` array (from each stage's `ffbuild_depends`), deletes every other stage, and rewrites
   `scripts.d/zz-final.sh` — the entry point BtbN's `generate.sh` walks from — to depend on exactly those roots.
   Stages BtbN does not have live in `stages/` (`50-codec2.sh`) and are copied into `scripts.d` first, so a
   flavour reaches them through `ROOTS` like any other.
   It also installs the `trimmed` add-in and patches `util/vars.sh` so `BTBN_IMAGE_REPO` can select whose
   base images to use.
2. `makeimage.sh` + `build.sh` with add-ins `9.0 trimmed` produce `win64` and `winarm64` `gpl-shared` zips
   from FFmpeg's `release/9.0` branch (`FFMPEG_VERSION` in the workflow and `build-local.sh`). With `BTBN_IMAGE_REPO=btbn/ffmpeg-builds QUICKBUILD=1` the public
   `ghcr.io/btbn/ffmpeg-builds/base-<target>` cross-toolchain images are pulled instead of rebuilt.
3. `collect-sources.sh` archives the exact source of FFmpeg and every kept dependency (GPL corresponding source).
4. Binaries, `SHA256SUMS` and the source archive are attached to one GitHub release of this repository.

Target differences: BtbN does not build libvpx or libvpl for `winarm64`, so that build has no VP9 encoder and no
QSV (NVENC is there on both). `verify-ffmpeg.ps1 -Arm64` knows this.

### Building locally (Windows)

Install WSL 2 with Ubuntu and Docker Desktop with WSL integration enabled for that distro, then from a WSL shell
(work on the Linux filesystem, not `/mnt/e`):

```bash
cp -r /mnt/e/Github/Codeleven/ffmpeg-shared-builds ~/ffmpeg-builds && sed -i 's/\r$//' ~/ffmpeg-builds/*.sh ~/ffmpeg-builds/addins/*.sh
bash ~/ffmpeg-builds/build-local.sh ~/btbn win64 winarm64
FLAVOR=audio-lgpl bash ~/ffmpeg-builds/build-local.sh ~/btbn-audio win64 winarm64   # the LGPL audio flavour
```

`build-local.sh` runs the same steps as the workflow and leaves the zips, source archive and `SHA256SUMS` in
`~/btbn/out`. Copy a zip's `bin` folder somewhere and run
`verify-ffmpeg.ps1` on it.

## Using a release

Unzip `ffmpeg-<target>-gpl-shared.zip`, keep `bin\ffmpeg.exe`, `bin\ffprobe.exe`, the `bin\*.dll` beside them and
`LICENSE.txt`; verify a download against `SHA256SUMS`. `verify-ffmpeg.ps1` checks that a folder has every
promised encoder, muxer, filter and device and the expected license flags:

```powershell
./verify-ffmpeg.ps1 -Folder <folder with ffmpeg.exe, ffprobe.exe and the DLLs>
```

## License

The scripts here are glue over [BtbN/FFmpeg-Builds](https://github.com/BtbN/FFmpeg-Builds). The produced
binaries are GPL v2 (`LICENSE.txt` inside each zip) and their complete corresponding source is
`ffmpeg-source.tar.xz` on the same release.
