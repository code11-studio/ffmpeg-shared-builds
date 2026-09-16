<#
.SYNOPSIS
    Checks that an FFmpeg folder has every component this build promises and nothing it must not ship.
    -Profile video: the trimmed GPL build (Video Converter). -Profile audio: the LGPL v2.1 audio-only build.
.EXAMPLE
    ./verify-ffmpeg.ps1 -Folder <folder with ffmpeg.exe, ffprobe.exe and the DLLs>
    ./verify-ffmpeg.ps1 -Folder <folder> -Profile audio
#>
param(
    [Parameter(Mandatory)] [string] $Folder,
    [ValidateSet('video', 'audio')] [string] $Profile = 'video',
    [switch] $Arm64
)

$ErrorActionPreference = 'Stop'
$ffmpeg = Join-Path $Folder 'ffmpeg.exe'
$ffprobe = Join-Path $Folder 'ffprobe.exe'
$problems = [System.Collections.Generic.List[string]]::new()

foreach ($exe in $ffmpeg, $ffprobe) {
    if (-not (Test-Path $exe)) { throw "Missing $exe" }
}

# Names from `ffmpeg -encoders` / `-decoders`: rows after the "------" legend separator, name in column 2.
function Get-CodecNames([string] $kind) {
    $past = $false
    foreach ($line in (& $ffmpeg -hide_banner "-$kind" 2>$null)) {
        $trimmed = $line.Trim()
        if (-not $past) { $past = $trimmed.StartsWith('---'); continue }
        $parts = $trimmed -split '\s+'
        if ($parts.Count -ge 2) { $parts[1] }
    }
}

$forbiddenEncoders = @()
$requiredDemuxers = @()
if ($Profile -eq 'audio') {
    # pcm_s16le is also what `-f null -` picks for audio analysis passes (loudness measurement).
    $requiredEncoders = 'libmp3lame','aac','libopus','libvorbis','flac','alac','wmav2','ac3',
        'pcm_u8','pcm_s8','pcm_s16le','pcm_s24le','pcm_s32le','pcm_f32le','pcm_s16be','pcm_s24be','pcm_s32be',
        'png','mjpeg','wrapped_avframe'
    $forbiddenEncoders = 'libx264','libx265','libsvtav1','libvpx-vp9','h264_nvenc','h264_mf','h264_amf','h264_qsv'
    $requiredMuxers = 'mp3','wav','aiff','ipod','mp4','mov','adts','flac','ogg','opus','asf','caf','ac3','matroska','image2','image2pipe','null'
    $requiredFilters = 'aresample','aformat','anull','atrim','asetpts','volume','volumedetect','loudnorm','ebur128','astats',
        'silenceremove','afade','pan','channelmap','amix','concat','anullsrc','sine','aevalsrc','scale','format'
    $requiredDecoders = 'aac','ac3','eac3','dca','truehd','mp3','flac','alac','opus','vorbis','wmav2','wmapro','wmalossless',
        'ape','tta','wavpack','mpc7','mpc8','tak','amrnb','amrwb','gsm','gsm_ms','adpcm_ima_oki','pcm_s16le',
        'h264','hevc','vp9','mjpeg','png','webp','bmp'
    # Names are the first alias ffmpeg prints ("mov,mp4,m4a,3gp,3g2,mj2" -> mov). `u8` is the raw demuxer VOX files use.
    $requiredDemuxers = 'mov','mp3','wav','aiff','flac','ogg','asf','caf','ape','tta','wv','mpc','mpc8','tak','amr','gsm',
        'dts','ac3','eac3','aac','au','w64','voc','u8','s16le','matroska','avi','mpegts','flv','aa','concat'
} else {
    # ac3, srt, testsrc2 and sine: kept so test clips can be synthesized with the build itself.
    $requiredEncoders = 'libx264','libx265','libsvtav1','prores_ks','gif','png','h264_mf','hevc_mf','aac','ac3','libopus','libmp3lame','mov_text','webvtt','ass','subrip','srt','wrapped_avframe','h264_nvenc','hevc_nvenc','av1_nvenc'
    if (-not $Arm64) {
        # BtbN does not build libvpx or libvpl for winarm64.
        $requiredEncoders += 'libvpx-vp9','h264_qsv','hevc_qsv','av1_qsv','h264_amf','hevc_amf','av1_amf'
    }
    $requiredMuxers = 'mp4','mov','matroska','webm','gif','mp3','image2pipe','ass','null'
    $requiredFilters = 'scale','format','fps','split','palettegen','paletteuse','bwdif','idet','fieldmatch','decimate','telecine','tinterlace','setfield','zscale','tonemap','subtitles','transpose','aresample','color','testsrc2','sine'
    $requiredDecoders = 'h264','hevc','vp9','libdav1d','mpeg2video','mpeg4','vc1','wmv3','prores','aac','ac3','eac3','dca','truehd','flac','opus','mp3','pgssub','dvdsub','subrip','ass'
}

$encoders = Get-CodecNames 'encoders'
$decoders = Get-CodecNames 'decoders'
$muxers = & $ffmpeg -hide_banner -muxers 2>$null | ForEach-Object { if ($_ -match '^\s*E\s+(\S+)') { $Matches[1] -split ',' } }
$demuxers = & $ffmpeg -hide_banner -demuxers 2>$null | ForEach-Object { if ($_ -match '^\s*D\s+(\S+)') { $Matches[1] -split ',' } }
$filters = & $ffmpeg -hide_banner -filters 2>$null | ForEach-Object { if ($_ -match '^\s*\S{2,3}\s+(\S+)\s+\S+->\S+') { $Matches[1] } }
$indevs = & $ffmpeg -hide_banner -devices 2>$null | ForEach-Object { if ($_ -match '^\s*D\S?\s+(\S+)') { $Matches[1] } }

foreach ($name in $requiredEncoders) { if ($encoders -notcontains $name) { $problems.Add("missing encoder: $name") } }
foreach ($name in $forbiddenEncoders) { if ($encoders -contains $name) { $problems.Add("GPL/video encoder present: $name (wrong flavour?)") } }
foreach ($name in $requiredDemuxers) { if ($demuxers -notcontains $name) { $problems.Add("missing demuxer: $name") } }
foreach ($name in $requiredDecoders) { if ($decoders -notcontains $name) { $problems.Add("missing decoder: $name") } }
foreach ($name in $requiredMuxers) { if ($muxers -notcontains $name) { $problems.Add("missing muxer: $name") } }
foreach ($name in $requiredFilters) { if ($filters -notcontains $name) { $problems.Add("missing filter: $name") } }
if ($indevs -notcontains 'lavfi') { $problems.Add('missing input device: lavfi (the hardware encoder probe needs it)') }

$buildconf = (& $ffmpeg -hide_banner -buildconf 2>$null) -join "`n"
if ($buildconf -match 'enable-nonfree') { $problems.Add('build is --enable-nonfree: it cannot be redistributed') }
if ($Profile -eq 'audio') {
    if ($buildconf -match 'enable-gpl') { $problems.Add('audio build must not be --enable-gpl (LGPL flavour expected)') }
    if ($buildconf -match 'enable-version3') { $problems.Add('audio build must not be --enable-version3 (LGPL v2.1 only)') }
    $licenseText = (& $ffmpeg -hide_banner -L 2>$null) -join "`n"   # the license text itself, not its short name
    if ($licenseText -notmatch 'Lesser General Public' -or $licenseText -notmatch 'version 2\.1') { $problems.Add('ffmpeg -L does not report the GNU Lesser General Public License version 2.1') }
    # The trap the GPL flavour falls into: `-f null -` on audio needs the pcm_s16le encoder, and loudnorm must exist.
    & $ffmpeg -hide_banner -loglevel error -f lavfi -i 'sine=f=440:d=0.2' -af 'loudnorm=print_format=summary' -f null - 2>$null
    if ($LASTEXITCODE -ne 0) { $problems.Add('loudness measurement smoke test failed (sine -> loudnorm -> null)') }
} else {
    if ($buildconf -notmatch 'enable-gpl') { $problems.Add('expected a GPL build (--enable-gpl) with x264/x265') }
}
if ($buildconf -notmatch 'enable-shared') { $problems.Add('expected a shared build (--enable-shared): ffmpeg and ffprobe should share av*.dll') }

$version = (& $ffmpeg -hide_banner -version 2>$null | Select-Object -First 1)
Write-Host "ffmpeg: $version"
Write-Host ("size:   {0:N1} MB" -f ((Get-ChildItem $Folder -File | Measure-Object Length -Sum).Sum / 1MB))

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "  x $_" -ForegroundColor Red }
    Write-Error "$($problems.Count) problem(s) in $Folder"
    exit 1
}
Write-Host 'OK' -ForegroundColor Green
