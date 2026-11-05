#!/bin/sh
# Rebuild _site whenever a source file changes; with --serve, also serve it.
# Pages are built with --live, so open tabs reload after each successful build.
# Polls mtimes once a second, so it needs nothing beyond POSIX sh and find.
#
#   tools/watch.sh <moonquakes> [--serve <port>]

set -u
MQ=$1
shift

SOURCES="build.lua site.lua lib posts pages templates static"
STAMP=$(mktemp)
trap 'rm -f "$STAMP"; [ -n "${SERVER:-}" ] && kill "$SERVER" 2>/dev/null; exit 0' INT TERM EXIT

build() {
	touch "$STAMP"
	printf '[%s] ' "$(date +%H:%M:%S)"
	if "$MQ" build.lua --drafts --live _site; then
		date +%s%N >_site/__live # the page script polls this and reloads when it changes
	else
		echo "build failed; waiting for the next change"
	fi
}

build

if [ "${1:-}" = "--serve" ]; then
	python3 -m http.server "$2" --bind 127.0.0.1 -d _site >/dev/null 2>&1 &
	SERVER=$!
	echo "serving http://localhost:$2/"
fi
echo "watching $SOURCES (Ctrl-C to stop)"

while :; do
	sleep 1
	changed=$(find $SOURCES -type f -newer "$STAMP" 2>/dev/null | head -n 1)
	if [ -n "$changed" ]; then
		echo "changed: $changed"
		build
	fi
done
