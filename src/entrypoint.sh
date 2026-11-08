#!/bin/sh
# ===========================================================================
# LazyLibrarian entrypoint wrapper for the TerraMaster TOS 7 package.
#
# The upstream image boots with the s6-overlay v3 init, whose service manager
# needs root; with user "1000:1000" it cannot start the app and nothing listens
# on 5299. TOS forbids root containers, so this wrapper performs the same
# first-run setup as the image's init script and then runs the same command the
# s6 service runs, directly as the unprivileged container user.
# ===========================================================================
set -u

CONFIG_DIR=/config
DATADIR=$CONFIG_DIR
DOWNLOAD_DIR=/downloads
BOOK_DIR=/books

mkdir -p "$CONFIG_DIR/log" "$CONFIG_DIR/cache" "$DOWNLOAD_DIR" "$BOOK_DIR"

# First-run configuration, copied from the image defaults (never overwritten).
if [ ! -e "$CONFIG_DIR/config.ini" ]; then
  cp /defaults/config.ini "$CONFIG_DIR/config.ini" 2>/dev/null || true
fi
if [ -e /defaults/version.txt ]; then
  cp /defaults/version.txt "$CONFIG_DIR/cache/version.txt" 2>/dev/null || true
fi

export HOME=$CONFIG_DIR
export TZ="${TZ:-Asia/Shanghai}"
export PYTHONIOENCODING=UTF-8

exec python3 -u /app/lazylibrarian/LazyLibrarian.py --datadir "$DATADIR" --nolaunch
