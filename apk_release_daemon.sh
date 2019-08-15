#!/bin/bash
set -e
set -u

LAST_FILE="/app/data/last_url.txt"
UPLOAD_DIR="/app/data/uploads"

mkdir -p "$UPLOAD_DIR"

while true; do
  source "$(dirname "$0")/config.sh"
  echo "Cek update..."

  # Ambil redirectUrl dari HTML
  REDIRECT=$(curl -s "$URL" | grep -oP 'var redirectUrl = "\K[^"]+')

  if [ -z "$REDIRECT" ]; then
    echo "Gagal ambil redirectUrl"
    sleep 21600
    continue
  fi

  # Cek apakah berubah
  if [ -f "$LAST_FILE" ] && grep -q "$REDIRECT" "$LAST_FILE"; then
    echo "Tidak ada perubahan."
  else
    echo "Versi baru ditemukan!"

    # Simpan URL terbaru
    echo "$REDIRECT" > "$LAST_FILE"

    # Ambil nama file dari URL
    FILENAME=$(basename "$REDIRECT")        # contoh: app25301.apk
    NUM=${FILENAME#app}
    NUM=${NUM%.apk}

    major=${NUM:0:1}
    minor=${NUM:1:1}
    patch=${NUM:2:1}
    build=${NUM:3:2}

    NEWNAME="com.kcstream.cing_${major}.${minor}.${patch}-build${build}.apk"

    set -x
    curl -L "$REDIRECT" -o "$UPLOAD_DIR/$NEWNAME"
    set +x

    echo "Downloaded sebagai $NEWNAME"
  fi

  echo "Tunggu 6 jam..."
  sleep 21600
done
