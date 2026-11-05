# `nix develop` puts the pinned moonquakes on PATH; otherwise use a sibling checkout.
MQ ?= $(shell command -v moonquakes 2>/dev/null || echo ../moonquakes/zig-out/bin/moonquakes)
PORT ?= 4000

.PHONY: build drafts serve watch dev check clean

build:
	$(MQ) build.lua _site

# include posts marked draft: true
drafts:
	$(MQ) build.lua --drafts _site

serve: drafts
	python3 -m http.server $(PORT) --bind 127.0.0.1 -d _site

# rebuild (with drafts and live reload) whenever posts, pages, templates, static or the SSG change
watch:
	tools/watch.sh $(MQ)

# watch + serve on http://localhost:$(PORT)/
dev:
	tools/watch.sh $(MQ) --serve $(PORT)

# the output must match the reference Lua 5.4 byte for byte
check:
	lua5.4 build.lua /tmp/keix-site-lua54 >/dev/null
	$(MQ) build.lua /tmp/keix-site-mq >/dev/null
	diff -r -I 'style.css?v=' /tmp/keix-site-lua54 /tmp/keix-site-mq && echo "same output on Lua 5.4 and moonquakes"

clean:
	rm -rf _site
