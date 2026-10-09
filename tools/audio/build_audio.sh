#!/usr/bin/env bash
# Regenerates all game audio from source (original synthesis + composed MIDI).
# Requires: node, ffmpeg, fluidsynth and the GeneralUser GS soundfont.
#   FLUIDSYNTH=/path/to/fluidsynth SOUNDFONT=/path/to/GeneralUser-GS.sf2 tools/audio/build_audio.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WAV="$ROOT/build/audio_wav"
A="$ROOT/game/assets/audio"
mkdir -p "$WAV" "$A/sfx" "$A/ambience" "$A/music"
node "$ROOT/tools/audio/synth_sfx.js" "$WAV"
for f in "$WAV"/*.wav; do
  b="$(basename "$f" .wav)"
  case "$b" in
    amb_*) dst="$A/ambience/${b#amb_}.ogg" ;;
    sfx_*) dst="$A/sfx/${b#sfx_}.ogg" ;;
    *) continue ;;
  esac
  ffmpeg -loglevel error -y -i "$f" -c:a libvorbis -q:a 5 "$dst"
done
node "$ROOT/tools/audio/compose_theme.js" "$WAV/meadow_theme.mid"
"${FLUIDSYNTH:-fluidsynth}" -ni -g 0.7 -r 44100 -F "$WAV/meadow_theme_raw.wav" "${SOUNDFONT:?set SOUNDFONT}" "$WAV/meadow_theme.mid"
# Trim to exactly 32 bars (2 x 16) so the loop point lands on the downbeat.
LOOP_SECONDS=$(node -e "console.log((32*3*60/78).toFixed(4))")
ffmpeg -loglevel error -y -i "$WAV/meadow_theme_raw.wav" -t "$LOOP_SECONDS" -af "afade=t=in:d=0.05" -c:a libvorbis -q:a 6 "$A/music/meadow_theme.ogg"
echo "audio built"
