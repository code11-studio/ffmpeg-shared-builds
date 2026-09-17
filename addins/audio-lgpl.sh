#!/bin/bash
# BtbN FFmpeg-Builds add-in: audio-only, LGPL v2.1 build for Audio Converter.
# Decoders, demuxers, parsers and bitstream filters stay fully enabled (any input must open, including video
# containers for video -> audio, Audible .aax via the mov demuxer with -activation_bytes, and Dialogic VOX via
# -f u8 -c adpcm_ima_oki); only outputs are restricted. Applied with: ./build.sh <target> lgpl-shared 9.0 audio-lgpl

# Stay LGPL v2.1-or-later: BtbN's lgpl variants add --enable-version3 (LGPLv3). None of the kept libraries
# (LAME LGPL2+, opus BSD, vorbis/ogg BSD, zlib, libiconv LGPL2.1+, libopenmpt BSD-3, codec2 LGPL2.1) needs it.
# libopenmpt and codec2 are input-only here: libopenmpt is a demuxer, and libcodec2's encoder is not in the list below.
FF_CONFIGURE="$(echo "$FF_CONFIGURE" | sed 's/--enable-version3//g')"
LICENSE_FILE="COPYING.LGPLv2.1"

# Fail loudly if anything upstream ever sneaks a GPL/nonfree flag into this flavour.
case " $FF_CONFIGURE " in
    *" --enable-gpl "*|*" --enable-nonfree "*)
        echo "audio-lgpl: --enable-gpl/--enable-nonfree present in FF_CONFIGURE; refusing to build" >&2
        exit 1 ;;
esac

# (--disable-doc would break BtbN's packaging, which copies share/doc; the docs are dropped at vendoring time.)
FF_CONFIGURE+=" --disable-ffplay --disable-debug --disable-network"
# No GPU/hwaccel paths: an audio converter never decodes video to pixels, except cover art.
FF_CONFIGURE+=" --disable-hwaccels --disable-d3d11va --disable-d3d12va --disable-dxva2 --disable-vulkan"
FF_CONFIGURE+=" --disable-mediafoundation --disable-amf --disable-ffnvcodec --disable-cuda-llvm"
# lavfi stays so test clips can be synthesized without an input file (-f lavfi -i sine=...).
FF_CONFIGURE+=" --disable-indevs --disable-outdevs --disable-devices --enable-indev=lavfi"
FF_CONFIGURE+=" --disable-protocols --enable-protocol=file,pipe"

# swscale (about 2 MB) is kept on purpose: re-encoding cover art (webp/bmp -> mjpeg/png, resizing) needs the
# auto-inserted scale filter for pixel-format conversion. Add --disable-swscale and drop scale,format,png,mjpeg
# below only if cover art is always stream-copied.

# Component names are configure names, not runtime names.
FF_CONFIGURE+=" --disable-encoders --enable-encoder=libmp3lame,aac,libopus,libvorbis,flac,alac,wmav2,ac3"
FF_CONFIGURE+=",pcm_u8,pcm_s8,pcm_s16le,pcm_s24le,pcm_s32le,pcm_f32le,pcm_s16be,pcm_s24be,pcm_s32be"
# png/mjpeg: re-embed cover art when the source picture is not already png/jpeg or must be resized.
# wrapped_avframe: what `-f null -` needs when an attached-picture stream is mapped (measurement passes).
FF_CONFIGURE+=",png,mjpeg,wrapped_avframe"

FF_CONFIGURE+=" --disable-muxers --enable-muxer=mp3,wav,aiff,ipod,mp4,mov,adts,flac,ogg,opus,asf,caf,ac3"
FF_CONFIGURE+=",matroska,image2,image2pipe,null"

# ffmpeg.c itself forces aformat,anull,atrim,crop,format,hflip,null,rotate,transpose,trim,vflip.
FF_CONFIGURE+=" --disable-filters --enable-filter=aresample,aformat,anull,null,atrim,asetpts"
FF_CONFIGURE+=",volume,volumedetect,loudnorm,ebur128,astats,silenceremove,afade,pan,channelmap,amix,concat"
FF_CONFIGURE+=",anullsrc,sine,aevalsrc"
# scale + format: pixel-format conversion for cover-art re-encoding.
FF_CONFIGURE+=",scale,format"
