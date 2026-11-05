-- Site settings. Edit freely; build.lua reads this table.

return {
  title = "眠れない夜に、コードを書く",
  url = "https://keix.github.io",
  host = "keix.github.io",
  author = "Kei Sawamura",
  description = "Kei Sawamura のブログ。Gentoo と Vim と Lua と、眠れない夜に書いたコードのこと。",

  home = {
    title_html = '眠れない夜に<br><span class="accent-pink">コード</span>を書く<span class="accent-yellow">。</span>',
    subtitle = "Code for sleepless nights.",
    lead_html = 'Gentoo と Vim と Lua が好きなプログラマ。このサイトは Lua でビルドされています。ソースコードは<a href="https://github.com/keix/keix.github.io">こちら</a>にあります。',
    badges = {
      { text = "by Kei Sawamura", color = "pink" },
      { text = "AM 3:12", color = "cyan" },
      { text = "Kobe, Japan", color = "lime" },
    },
    recent = 3, -- cards after the featured post
  },

  -- Tag colors. Tags not listed here get a color from the palette in turn.
  tags = {
    lua = "yellow",
    zig = "pink",
    os = "cyan",
    gentoo = "lavender",
    vim = "lime",
    essay = "orange",
  },

  sns = {
    { name = "GitHub", url = "https://github.com/keix", color = "ink" },
    { name = "Bluesky", url = "https://bsky.app/profile/keix.bsky.social", color = "cyan" },
    { name = "Threads", url = "https://www.threads.net/@keix.py", color = "lavender", badge = "ときどき" },
    { name = "Instagram", url = "https://www.instagram.com/keix.py/", color = "pink" },
    { name = "Medium", url = "https://medium.com/@keix.py", color = "lime" },
    { name = "Zenn", url = "https://zenn.dev/exelion", color = "yellow" },
    { name = "note", url = "https://note.com/hofchan", color = "orange" },
    { name = "X", url = "https://x.com/hofchan", color = "ink", badge = "いつも" },
  },

  author_card = {
    name = "Kei Sawamura",
    bio = "神戸のプログラマ。Vim と Gentoo と Lua。",
    url = "https://github.com/keix",
    label = "github.com/keix",
  },
}
