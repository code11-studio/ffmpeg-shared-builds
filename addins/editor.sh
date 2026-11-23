#!/bin/bash
# BtbN FFmpeg-Builds add-in: the trimmed GPL build plus the filters Video Editor's export graph needs.
# Everything trimmed.sh sets (license, encoders, muxers, devices, protocols, GPU encoders, its filter list) is
# taken as is; only filters are added. Applied with: ./build.sh <target> gpl-shared 9.0 editor
# BtbN sources add-ins from the repository root (build.sh / generate.sh cd there first).
source addins/trimmed.sh

# Video Editor runs one -/filter_complex graph file per export: per-clip trim/scale/pad or crop, transpose/hflip,
# setpts/atempo speed, fade/afade, xfade/acrossfade transitions, concat, PNG title overlays timed with
# enable='between(t,a,b)', and music via adelay/volume/amix (apad/anullsrc/aevalsrc fill silent gaps).
FF_CONFIGURE+=" --enable-filter=setpts,asetpts,atempo,concat,xfade,acrossfade,fade,afade,pad,overlay"
FF_CONFIGURE+=",amix,adelay,volume,trim,atrim,crop,apad,anullsrc,aevalsrc"
# settb (common timebase before concat/xfade), tpad (hold the last frame when a source is shorter than its clip),
# loop (photo clips from one decoded image).
FF_CONFIGURE+=",settb,tpad,loop"
# drawtext: freetype, fontconfig and harfbuzz are already built for libass, so it adds no library.
FF_CONFIGURE+=",drawtext"
