<#
.SYNOPSIS
    Checks that an FFmpeg folder has every component this build promises and nothing it must not ship.
.EXAMPLE
    ./verify-ffmpeg.ps1 -Folder <folder with ffmpeg.exe, ffprobe.exe and the DLLs>
#>
param(
    [Parameter(Mandatory)] [string] $Folder,
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

# ac3, srt, testsrc2 and sine: kept so test clips can be synthesized with the build itself.
$requiredEncoders = 'libx264','libx265','libsvtav1','prores_ks','gif','png','h264_mf','hevc_mf','aac','ac3','libopus','libmp3lame','mov_text','webvtt','ass','subrip','srt'
if (-not $Arm64) {
    # BtbN does not build libvpx or libvpl for winarm64, and NVENC needs FFmpeg > 8.1 there.
    $requiredEncoders += 'libvpx-vp9','h264_nvenc','hevc_nvenc','av1_nvenc','h264_qsv','hevc_qsv','av1_qsv','h264_amf','hevc_amf','av1_amf'
}
$requiredMuxers = 'mp4','mov','matroska','webm','gif','mp3','image2pipe','ass','null'
$requiredFilters = 'scale','format','fps','split','palettegen','paletteuse','bwdif','zscale','tonemap','subtitles','transpose','aresample','color','testsrc2','sine'
$requiredDecoders = 'h264','hevc','vp9','libdav1d','mpeg2video','mpeg4','vc1','wmv3','prores','aac','ac3','eac3','dca','truehd','flac','opus','mp3','pgssub','dvdsub','subrip','ass'

$encoders = Get-CodecNames 'encoders'
$decoders = Get-CodecNames 'decoders'
$muxers = & $ffmpeg -hide_banner -muxers 2>$null | ForEach-Object { if ($_ -match '^\s*E\s+(\S+)') { $Matches[1] -split ',' } }
$filters = & $ffmpeg -hide_banner -filters 2>$null | ForEach-Object { if ($_ -match '^\s*\S{2,3}\s+(\S+)\s+\S+->\S+') { $Matches[1] } }
$indevs = & $ffmpeg -hide_banner -devices 2>$null | ForEach-Object { if ($_ -match '^\s*D\S?\s+(\S+)') { $Matches[1] } }

foreach ($name in $requiredEncoders) { if ($encoders -notcontains $name) { $problems.Add("missing encoder: $name") } }
foreach ($name in $requiredDecoders) { if ($decoders -notcontains $name) { $problems.Add("missing decoder: $name") } }
foreach ($name in $requiredMuxers) { if ($muxers -notcontains $name) { $problems.Add("missing muxer: $name") } }
foreach ($name in $requiredFilters) { if ($filters -notcontains $name) { $problems.Add("missing filter: $name") } }
if ($indevs -notcontains 'lavfi') { $problems.Add('missing input device: lavfi (the hardware encoder probe needs it)') }

$buildconf = (& $ffmpeg -hide_banner -buildconf 2>$null) -join "`n"
if ($buildconf -match 'enable-nonfree') { $problems.Add('build is --enable-nonfree: it cannot be redistributed') }
if ($buildconf -notmatch 'enable-gpl') { $problems.Add('expected a GPL build (--enable-gpl) with x264/x265') }
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
