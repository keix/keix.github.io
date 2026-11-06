## keix.github.io

眠れない夜にコードを書く。 — Kei Sawamura's blog.

The site is built by a small static site generator written in Lua (`build.lua`),
running on [moonquakes](https://github.com/keix/moonquakes), a Lua 5.4 implementation in Zig.
It also runs on the reference Lua 5.4, and both must produce the same output.

### Writing

Every post belongs to a series: one of my own projects, or one codebase I read.
A series is a directory under `posts/`, and its posts are numbered 1, 2, 3, ... with no gaps.

```
posts/
  moonquakes/
    index.md            series title, lead, repo and intro (optional)
    2026-11-05-1.md     → /posts/moonquakes/1/
    2026-12-01-2.md     → /posts/moonquakes/2/
```

The build stops on a file directly in `posts/`, a name that is not `YYYY-MM-DD-<n>.md`,
a duplicate number or a gap. Drafts count toward the numbering, so URLs never shift.

```markdown
<!-- posts/moonquakes/2026-11-05-1.md -->
---
title: moonquakes でこのサイトをビルドする
date: 2026-11-05          # optional, defaults to the file name
tags: [lua, zig]
lead: 一覧やカードに出る短い説明。
draft: true               # skipped unless built with --drafts
---
本文を Markdown で書く。
```

```markdown
<!-- posts/moonquakes/index.md -->
---
title: Moonquakes
lead: シリーズの一覧ページとカードに出る説明。
repo: https://github.com/keix/moonquakes
color: yellow             # one of the 30 names in build.lua (SERIES_COLORS) or #RRGGBB; unique per series
---
シリーズの紹介文。
```

Fenced code takes a language and an optional file name: ` ```lua lib/markdown.lua `.
Headings accept an explicit id: `## Why {#why}`.

`pages/about.md` and `pages/404.md` hold the About and 404 pages. Site-wide settings
(title, SNS links, tag colors) live in `site.lua`.

### Building

moonquakes, Zig and nixpkgs are pinned in `flake.lock`, so every machine and CI use the same toolchain.

```sh
nix build .#site            # compiles the pinned moonquakes, then builds the site into ./result
nix develop                 # shell with moonquakes, lua5.4, make and python3
make build                  # inside nix develop: writes _site/
make dev                    # rebuild + live reload on every save, served on http://localhost:4000
make watch                  # rebuild + live reload, without the server (bring your own)
make serve                  # one build with drafts, then serve
make check                  # output must match the reference Lua 5.4 byte for byte
nix flake update moonquakes # move to the latest moonquakes main
```

Without Nix, `make` falls back to `../moonquakes/zig-out/bin/moonquakes`, or pass `MQ=/path/to/moonquakes`.

Pushing to `main` runs `nix build .#site` on GitHub Actions and deploys the result (`.github/workflows/pages.yml`).

### Layout

```
build.lua        entry point
site.lua         settings
lib/             markdown, frontmatter, template, highlight, fs
templates/       base, home, post, list, series, tags, about, 404
static/          css, images, favicon (copied as is)
tools/watch.sh   rebuild + live-reload loop behind `make watch` / `make dev`
posts/           one directory per series
pages/           about.md, 404.md
```

### License
Under the terms of the [MIT License](https://opensource.org/license/mit/). Copyright (c) 2023 kei sawamura.
