---
title: moonquakes でこのサイトをビルドする
date: 2026-11-05
tags: [lua, zig]
lead: 自作の Lua 実装で静的サイトジェネレータを書いた。Markdown パーサーは純 Lua、依存ゼロ。眠れない夜の小さなプロジェクトの記録。
---
このサイトは Hugo で作っていましたが、ソースが手元になくビルド結果だけが残っていました。せっかく作り直すなら、自分で書いている Lua の実装 [moonquakes](https://github.com/keix/moonquakes) を実戦で動かしてみたい。そう思って、静的サイトジェネレータを一から書くことにしました。

## なぜ自作するのか

既製のジェネレータは便利ですが、記事を書くだけなら必要な機能は多くありません。Markdown を HTML にして、テンプレートに流し込み、一覧と RSS を作る。**それだけなら数百行で書ける**はずです。

- 依存はランタイム（moonquakes）だけ
- 処理を全部読める大きさに保つ
- ビルドそのものを処理系のテストにする

## Markdown を gsub で変換する

LPeg は C モジュールなので使いません。`string.gsub` とパターンだけでパーサーを書きます。たとえば見出しはこうなります。

```lua lib/markdown.lua
-- "## text" → <h2>text</h2>
local function heading(line)
  local marks, text = line:match("^(#+)%s+(.-)%s*$")
  if marks and #marks <= 6 then
    return #marks, text
  end
end
```

### インライン要素

強調やリンクは、順番に `gsub` をかけていくだけで変換できます。コードスパンを先に退避しておくのがコツです。

> Simple is better than complex.

## ファイル構成

| ファイル | 役割 |
|---|---|
| build.lua | エントリ。記事を集めて各ページを書き出す |
| lib/markdown.lua | Markdown → HTML |
| lib/template.lua | テンプレートの変数を置換する |
| lib/highlight.lua | コードの色付け |

## つぎにやること

ディレクトリの列挙は今のところ `ls` に頼っています。moonquakes 側に `os.listdir` を足すかどうか、次の夜に考えます。
