#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p Fixtures
for extension in wav mp3 opus flac m4a aiff aac; do
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'sine=frequency=440:sample_rate=48000:duration=3' -ac 2 "Fixtures/tone.$extension"
done
ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'sine=frequency=440:sample_rate=48000:duration=3' -ac 2 -c:a vorbis -strict experimental Fixtures/tone.ogg
ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'sine=frequency=440:sample_rate=44100:duration=3' -ac 2 Fixtures/tone.mp3
ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'sine=frequency=440:sample_rate=96000:duration=3' -ac 1 Fixtures/tone.aiff
printf 'not audio' > Fixtures/corrupt.mp3
