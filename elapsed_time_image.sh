#!/bin/bash
set -e
set -u

UPLOAD_DIR="/app/data/uploads"
mkdir -p "$UPLOAD_DIR"

total=0

while true; do
    minutes=$(( total % 1440 ))
    days=$(( total / 1440 ))
    seconds=$(( total * 60 ))

    # hapus file lama
    rm -f "$UPLOAD_DIR"/*.minutes*.png

    if [ "$days" -eq 0 ]; then
        filename="${minutes}.minutes"
    else
        filename="${minutes}.minutes_${days}.day"
    fi

    set -x
    # buat gambar berisi angka total detik
    convert -size 500x250 xc:white \
    -gravity center \
    -font DejaVu-Sans-Mono \
    -pointsize 100 \
    -fill black \
    -annotate 0 "$seconds" \
    "$UPLOAD_DIR/${filename}.png"
    set +x

    sleep 60
    total=$(( total + 1 ))
done
