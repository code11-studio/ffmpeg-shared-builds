#!/bin/bash
# Archives the corresponding source of the FFmpeg build (GPL §3):
#   sources/<stage>.tar.xz  the exact source tarball BtbN's download.sh fetched for every kept stage (this is what
#                           the build compiled — git checkouts, the lame SVN checkout, …), taken from .cache/downloads
#   sources/ffmpeg/         FFmpeg at the commit the binaries report (FFMPEG_COMMIT)
#   FFmpeg-Builds/          the pruned BtbN tree with our add-in (no caches, no build output)
#   ./collect-sources.sh <btbn-workdir> <output.tar.xz>     (run after makeimage.sh + build.sh)
set -euo pipefail

WORK="$(cd "$1" && pwd)"
OUT="$2"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/sources" "$STAGE/FFmpeg-Builds"
tar -C "$WORK" --exclude=.git --exclude=.cache --exclude=ffbuild --exclude=artifacts --exclude=out -cf - . \
    | tar -C "$STAGE/FFmpeg-Builds" -xf -

missing=()
for script in "$WORK"/scripts.d/*.sh "$WORK"/scripts.d/*/*.sh; do
    [[ -f "$script" ]] || continue
    name="$(basename "$script" .sh)"
    grep -q '^SCRIPT_SKIP="1"' "$script" && continue      # pseudo stages (base, zz-final) have no source
    link="$WORK/.cache/downloads/$name.tar.xz"
    if [[ -e "$link" ]]; then
        cp -L "$link" "$STAGE/sources/$name.tar.xz"
        echo "== $name: $(readlink "$link")"
    else
        missing+=("$name")
    fi
done
if ((${#missing[@]})); then
    echo "!! no downloaded source for: ${missing[*]} (run makeimage.sh first; every enabled stage must be here)" >&2
    exit 1
fi

FFMPEG_REPO="${FFMPEG_REPO:-https://github.com/FFmpeg/FFmpeg.git}"
FFMPEG_COMMIT="${FFMPEG_COMMIT:?set FFMPEG_COMMIT to the commit the build used}"
# gc.autoDetach=false: git otherwise leaves a background gc touching the tree while tar reads it.
git -c gc.autoDetach=false clone --filter=blob:none --no-checkout "$FFMPEG_REPO" "$STAGE/sources/ffmpeg"
git -C "$STAGE/sources/ffmpeg" -c gc.autoDetach=false checkout --quiet "$FFMPEG_COMMIT"
rm -rf "$STAGE/sources/ffmpeg/.git"
echo "== ffmpeg: $FFMPEG_REPO @ $FFMPEG_COMMIT"

# GNU tar exits 1 for "file changed as we read it" (a warning); anything worse is a real error.
set +e
tar -C "$STAGE" -I 'xz -T0' -cf "$OUT" .
rc=$?
set -e
(( rc == 0 || rc == 1 )) || exit "$rc"
echo "== wrote $OUT ($(du -h "$OUT" | cut -f1))"
