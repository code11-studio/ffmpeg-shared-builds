#!/bin/bash
# BtbN FFmpeg-Builds add-in: trims the build to the outputs this repository ships.
# Decoders, demuxers, parsers and bitstream filters stay fully enabled (any input must open);
# only outputs are restricted. Applied with: ./build.sh <target> gpl-shared trimmed

# Stay GPL v2-or-later: none of the kept libraries needs version3. Ship the matching license text.
FF_CONFIGURE="$(echo "$FF_CONFIGURE" | sed 's/--enable-version3//g')"
LICENSE_FILE="COPYING.GPLv2"

# (--disable-doc would break BtbN's packaging, which copies share/doc; the docs are dropped at vendoring time.)
FF_CONFIGURE+=" --disable-ffplay --disable-debug --disable-network"
# lavfi stays so hardware encoders can be probed with `-f lavfi -i color=...` without an input file.
FF_CONFIGURE+=" --disable-indevs --disable-outdevs --disable-devices --enable-indev=lavfi"
FF_CONFIGURE+=" --disable-protocols --enable-protocol=file,pipe"

# Component names are configure names (movtext = the "mov_text" encoder), not runtime names.
FF_CONFIGURE+=" --disable-encoders --enable-encoder=libx264,libx265,libsvtav1,libvpx_vp9,prores_ks,gif,png"
FF_CONFIGURE+=",h264_mf,hevc_mf,aac,libopus,libmp3lame,movtext,webvtt,ass,subrip"
# ac3, srt, testsrc2 and sine: enough to synthesize test clips with the build itself.
FF_CONFIGURE+=",ac3,srt"
# wrapped_avframe: the encoder `-f null -` needs, for the interlace scan decoding frames without writing them.
FF_CONFIGURE+=",wrapped_avframe"

FF_CONFIGURE+=" --disable-muxers --enable-muxer=mp4,mov,ipod,matroska,webm,gif,mp3,image2,image2pipe,ass,webvtt,srt,null"

FF_CONFIGURE+=" --disable-filters --enable-filter=scale,format,setsar,fps,split,palettegen,paletteuse,bwdif,yadif"
FF_CONFIGURE+=",zscale,tonemap,subtitles,ass,transpose,hflip,vflip,rotate,aresample,aformat,anull,null"
FF_CONFIGURE+=",color,nullsrc,anullsrc,testsrc2,sine,hwupload,hwdownload"
# Interlace scan (idet) and inverse telecine (fieldmatch + decimate) for DVD-era sources.
FF_CONFIGURE+=",idet,fieldmatch,decimate"
# telecine, tinterlace and setfield: enough to synthesize interlaced and telecined test clips.
FF_CONFIGURE+=",telecine,tinterlace,setfield"

FF_CONFIGURE+=" --enable-mediafoundation --enable-d3d11va --enable-dxva2"

# BtbN builds nv-codec-headers for winarm64 only from FFmpeg 9.0 on; libvpl is win64-only.
FF_CONFIGURE+=" --enable-encoder=h264_nvenc,hevc_nvenc,av1_nvenc"
if [[ "$TARGET" == win64 ]]; then
    FF_CONFIGURE+=",h264_qsv,hevc_qsv,av1_qsv,h264_amf,hevc_amf,av1_amf"
fi
