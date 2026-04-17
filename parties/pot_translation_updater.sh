#!/usr/bin/env bash

set -e

# ==================================================
# Luanti xgettext helper script
# - Extracts translations only from .lua files
# - Ignores the .git directory
# - Supported keywords:
#   S, PS, NS, FS, FPS, NFS
# ==================================================

LOCALE_DIR="locale"
POT_FILE="$LOCALE_DIR/template.pot"

echo "==> Extracting Lua strings (Luanti)"

# Find all .lua files, excluding .git
FILES=$(find . \
  -path "./.git/*" -prune -o \
  -type f -name "*.lua" -print)

# Exit early if no Lua files are found
if [ -z "$FILES" ]; then
  echo "No .lua files found"
  exit 0
fi

# Run xgettext with Luanti-specific keywords
xgettext \
  --language=Lua \
  --from-code=UTF-8 \
  --add-comments=Translators: \
  --keyword=S \
  --keyword=PS:1,2 \
  --keyword=NS \
  --keyword=FS \
  --keyword=FPS:1,2 \
  --keyword=NFS \
  --output="$POT_FILE" \
  $FILES

echo "==> POT file updated: $POT_FILE"

# --------------------------------------------------
# Update existing .po files using the new POT
# --------------------------------------------------

if [ -d "$LOCALE_DIR" ]; then
  for PO in "$LOCALE_DIR"/*.po; do
    [ -f "$PO" ] || continue
    echo "==> Updating $(basename "$PO")"
    msgmerge --update --backup=none "$PO" "$POT_FILE"
  done
fi

echo "==> Done"

