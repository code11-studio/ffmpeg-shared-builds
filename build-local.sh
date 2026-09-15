#!/bin/bash
# Builds the trimmed FFmpeg locally, mirroring .github/workflows/ffmpeg.yml. Needs Linux with Docker
# (on Windows: WSL 2 + Docker Desktop with WSL integration). Keep WORK on the Linux filesystem, not /mnt/*.
#   ./build-local.sh [workdir] [targets...]      e.g. ./build-local.sh ~/btbn win64 winarm64
# Output: <workdir>/out/ffmpeg-<target>-gpl-shared.zip, ffmpeg-source.tar.xz, SHA256SUMS
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${1:-$HOME/btbn}"; shift || true
TARGETS=("${@:-win64 winarm64}")
[[ ${#TARGETS[@]} -eq 1 && "${TARGETS[0]}" == *" "* ]] && read -ra TARGETS <<< "${TARGETS[0]}"
# BtbN version add-in: builds FFmpeg's release/<version> branch. Keep in step with the workflow's FFMPEG_VERSION.
FFMPEG_VERSION="${FFMPEG_VERSION:-9.0}"

# Pull BtbN's public cross-toolchain images instead of rebuilding them (about an hour saved per target).
export BTBN_IMAGE_REPO=btbn/ffmpeg-builds QUICKBUILD=1

bash "$HERE/prepare.sh" "$WORK"
cd "$WORK"
mkdir -p out

for target in "${TARGETS[@]}"; do
    echo "==== $target: image"
    ./makeimage.sh "$target" gpl-shared "$FFMPEG_VERSION" trimmed
    echo "==== $target: ffmpeg"
    ./build.sh "$target" gpl-shared "$FFMPEG_VERSION" trimmed
    zip="$(ls -t artifacts/*.zip | head -n1)"
    cp "$zip" "out/ffmpeg-$target-gpl-shared.zip"
    # BtbN's zip name carries the FFmpeg commit (…-g<hash>-<target>-…); keep it for the source archive.
    basename "$zip" .zip > "out/ffmpeg-$target-build-name.txt"
done

# Corresponding source (GPL) for the exact FFmpeg commit the binaries were built from.
# Build names look like ffmpeg-N-123-g<hash>-… (master) or ffmpeg-n9.0.1-12-g<hash>-… (release branches).
hash="$(grep -ohE -- '-g[0-9a-f]{7,}' out/*-build-name.txt | head -n1 | sed 's/^-g//')"
FFMPEG_COMMIT="$hash" bash "$HERE/collect-sources.sh" "$WORK" "$WORK/out/ffmpeg-source.tar.xz"

(cd out && sha256sum * > SHA256SUMS && cat SHA256SUMS)
echo "==== done: $WORK/out"
