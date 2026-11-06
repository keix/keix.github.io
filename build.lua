-- build.lua — static site generator for keix.github.io
--
--   moonquakes build.lua [--drafts] [--live] [outdir]
--
-- --live adds a script that reloads the page when /__live changes (tools/watch.sh).
--
-- Reads posts/<series>/*.md and pages/*.md, renders templates/*.html and writes the site to
-- outdir (default: _site). Runs on moonquakes and on the reference Lua 5.4.

package.path = "./?.lua;" .. package.path

local fs = require("lib.fs")
local frontmatter = require("lib.frontmatter")
local markdown = require("lib.markdown")
local highlight = require("lib.highlight")
local template = require("lib.template")
local site = require("site")

local OUT, DRAFTS, LIVE = "_site", false, false
for _, a in ipairs(arg or {}) do
  if a == "--drafts" then DRAFTS = true
  elseif a == "--live" then LIVE = true
  else OUT = a end
end

local HEX = {
  yellow = "#FFD84D", pink = "#FF6FB5", cyan = "#4FD8F0", lavender = "#B79CFF",
  lime = "#B6F36B", orange = "#FF8A3D", ink = "#F4F2FF", muted = "#B9B5DE",
  -- 24 more for series, picked to stay apart from the six above and from each other
  grass = "#62AE45", azure = "#00A2F0", blush = "#FFB6C7", mustard = "#C3B438",
  teal = "#00B5B2", periwinkle = "#BFCCFF", orchid = "#C772CF", mint = "#9AE5B6",
  coral = "#EA6A66", amber = "#C68D00", jade = "#59CB8B", iris = "#7F8CF9",
  peach = "#FFC28E", cornflower = "#77B2FF", salmon = "#FD8A8F", mauve = "#E38FDB",
  straw = "#D7D688", tangerine = "#E2781F", lilac = "#EDBDFC", olive = "#A39E00",
  aqua = "#00CDBE", emerald = "#00B685", rose = "#E46894", violet = "#A87EEB",
}
local PALETTE = { "yellow", "pink", "cyan", "lavender", "lime", "orange" }
-- series and tags each draw from these 30, so no two series and no two tags share one
local UNIQUE_COLORS = {
  "yellow", "pink", "cyan", "lavender", "lime", "orange",
  "grass", "azure", "blush", "mustard", "teal", "periwinkle", "orchid", "mint",
  "coral", "amber", "jade", "iris", "peach", "cornflower", "salmon", "mauve",
  "straw", "tangerine", "lilac", "olive", "aqua", "emerald", "rose", "violet",
}
local TILTS = { "tilt-l", "tilt-r", "tilt-s" }

local escape = template.escape
local T = template.new("templates", fs.read)

local build = {
  stamp = tostring(os.time()),
  year = os.date("%Y"),
  runtime = os.getenv("MOONQUAKES_VERSION") or "",
  live = LIVE,
}

local started = os.clock()
local written = 0

---------------------------------------------------------------------------
-- helpers

local function hex(name)
  return HEX[name] or name
end

local function cycle(list, i)
  return list[(i - 1) % #list + 1]
end

local function chips(items)
  local out = {}
  for i, item in ipairs(items or {}) do
    out[#out + 1] = { text = item.text, color = hex(item.color), tilt = cycle(TILTS, i) }
  end
  return out
end

-- Truncates s to at most n characters, on a UTF-8 boundary.
local function truncate(s, n)
  if utf8.len(s) and utf8.len(s) > n then
    return s:sub(1, utf8.offset(s, n + 1) - 1) .. "…"
  end
  return s
end

-- Percent-encodes s byte by byte (UTF-8 stays valid), for query strings.
local function urlencode(s)
  return (s:gsub("[^%w%-%._~]", function(c) return ("%%%02X"):format(c:byte()) end))
end

local function entries(n)
  return n .. (n == 1 and " entry" or " entries")
end

local function plain_text(html)
  return (markdown.strip_tags(html):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function output_path(url)
  if url:sub(-1) == "/" then return OUT .. url .. "index.html" end
  return OUT .. url
end

local function write(url, data)
  fs.write(output_path(url), data)
  written = written + 1
end

-- Fenced code blocks become the bar + highlighted <pre> from the design.
local function code_renderer(flags)
  return function(code, lang, file)
    flags.has_code = true
    local label = file ~= "" and file or (lang ~= "" and lang or "text")
    local class = lang ~= "" and (' class="language-' .. escape(lang) .. '"') or ""
    return '<div class="code"><div class="code-bar"><span>' .. escape(label)
      .. '</span><button class="code-copy" type="button">コピー</button></div>'
      .. "<pre><code" .. class .. ">" .. highlight.render(code, lang) .. "</code></pre></div>"
  end
end

local function render_markdown(body)
  local flags = {}
  local html, toc = markdown.render(body, { code = code_renderer(flags) })
  for _, item in ipairs(toc) do item.sub = item.level == 3 end
  return html, toc, flags.has_code or false
end

-- Wraps rendered content in the base layout and writes it.
local function page(url, tpl, data, opts)
  opts = opts or {}
  data.site, data.build = site, build
  local title = opts.title and (opts.title .. " | " .. site.title) or site.title
  write(url, T:render("base", {
    site = site,
    build = build,
    content = T:render(tpl, data),
    page_title = title,
    description = opts.description or site.description,
    canonical = site.url .. url,
    og_type = opts.og_type or "website",
    nav = { posts = opts.nav == "posts", about = opts.nav == "about" },
    has_code = opts.has_code or false,
    has_toc = opts.has_toc or false,
  }))
end

---------------------------------------------------------------------------
-- site data: colors resolved once

for _, s in ipairs(site.sns) do s.color = hex(s.color) end
site.home.badges = chips(site.home.badges)

-- Gives each item its own color. A pinned color (a palette name or #RRGGBB) is kept and
-- may not repeat; the rest start at a slot picked from the name, so adding an item rarely
-- moves anyone else, and step to the next free color in UNIQUE_COLORS.
local function unique_colors(items, where)
  local taken = {}
  for _, item in ipairs(items) do
    if item.pin then
      local c = hex(item.pin)
      assert(c:match("^#%x%x%x%x%x%x$"), where(item) .. ": color is a palette name or #RRGGBB, not " .. item.pin)
      assert(not taken[c:upper()], where(item) .. ": color " .. item.pin .. " is already used by " .. tostring(taken[c:upper()]))
      taken[c:upper()] = item.name
      item.color = c
    end
  end
  for _, item in ipairs(items) do
    if not item.color then
      local start = 0
      for k = 1, #item.name do start = (start * 31 + item.name:byte(k)) % #UNIQUE_COLORS end
      for k = 0, #UNIQUE_COLORS - 1 do
        local c = HEX[UNIQUE_COLORS[(start + k) % #UNIQUE_COLORS + 1]]
        if not taken[c:upper()] then
          taken[c:upper()] = item.name
          item.color = c
          break
        end
      end
      assert(item.color, where(item) .. ": all " .. #UNIQUE_COLORS .. " colors are taken; pin one as #RRGGBB")
    end
  end
end

-- tag colors are resolved once every tag is known (see the tag index below)
local tag_colors, tag_items, tag_names = {}, {}, {}
local function tag_color(name)
  return tag_colors[name]
end

local function tag_list(names)
  local out = {}
  for i, name in ipairs(names) do
    out[#out + 1] = { name = name, url = "/tags/" .. name .. "/", tilt = cycle(TILTS, i) }
    tag_items[#tag_items + 1] = out[#out]
  end
  return out
end

---------------------------------------------------------------------------
-- posts: every post belongs to a series, posts/<series>/YYYY-MM-DD-<n>.md
--
-- A series is one of my own projects (or one codebase I read). Its posts are
-- numbered 1, 2, 3, ... with no gaps, and live at /posts/<series>/<n>/.
-- posts/<series>/index.md optionally holds the series title, lead, repo and intro.

local posts, series_list, all_series = {}, {}, {}

for _, file in ipairs(fs.list("posts", ".md")) do
  error("posts/" .. file .. ": posts go in a series, as posts/<series>/YYYY-MM-DD-<n>.md")
end

for i, name in ipairs(fs.dirs("posts")) do
  local dir = "posts/" .. name .. "/"
  assert(name:match("^[a-z0-9][a-z0-9%-]*$"), dir .. ": series names are lowercase letters, digits and hyphens")

  local smeta, intro = {}, ""
  if fs.exists(dir .. "index.md") then smeta, intro = frontmatter.parse(fs.read(dir .. "index.md")) end
  local series = {
    name = name,
    title = smeta.title or name,
    lead = smeta.lead,
    repo = smeta.repo,
    repo_label = smeta.repo and (smeta.repo:gsub("^https?://", ""):gsub("/$", "")),
    color = smeta.color, -- resolved below, once every series is known
    url = "/posts/" .. name .. "/",
    intro = (render_markdown(intro)),
    posts = {},
  }

  local numbers, count = {}, 0
  for _, file in ipairs(fs.list(dir, ".md")) do
    if file ~= "index.md" then
      local where = dir .. file
      local fdate, n = file:match("^(%d%d%d%d%-%d%d%-%d%d)%-(%d+)%.md$")
      assert(fdate, where .. ": name it YYYY-MM-DD-<n>.md, e.g. 2026-11-05-1.md")
      n = tonumber(n)
      assert(not numbers[n], where .. ": #" .. n .. " is already " .. tostring(numbers[n]))
      numbers[n], count = where, count + 1

      local meta, body = frontmatter.parse(fs.read(where))
      local date = meta.date or fdate
      assert(date:match("^%d%d%d%d%-%d%d%-%d%d$"), where .. ": date must be YYYY-MM-DD")
      assert(meta.title, where .. ": title is required")

      local tags = type(meta.tags) == "table" and meta.tags or (meta.tags and { meta.tags }) or {}
      for _, t in ipairs(tags) do tag_names[t] = true end -- drafts count, so colors match with --drafts

      if DRAFTS or meta.draft ~= true then
        local html, toc, has_code = render_markdown(body)
        local text = plain_text(html)
        local p = {
          file = where,
          series = series,
          number = n,
          label = name .. " #" .. n,
          slug = name .. "/" .. n,
          url = series.url .. n .. "/",
          -- Web Intents: plain links to each compose screen, no API or script
          share_x = "https://x.com/intent/post?text=" .. urlencode(site.title .. " - " .. meta.title)
            .. "&url=" .. urlencode(site.url .. series.url .. n .. "/"),
          share_threads = "https://www.threads.net/intent/post?text="
            .. urlencode(site.title .. " - " .. meta.title .. " " .. site.url .. series.url .. n .. "/"),
          title = meta.title,
          lead = meta.lead or false, -- false, not nil: keeps {{# lead }} from falling back to the series lead
          description = meta.lead or truncate(text, 120),
          date = date,
          year = date:sub(1, 4),
          month_day = date:sub(6),
          tags = tags,
          tag_list = tag_list(tags),
          html = html,
          toc = toc,
          has_toc = #toc > 1,
          has_code = has_code,
          minutes = math.max(1, math.floor((utf8.len(text) or #text) / 500 + 0.5)),
        }
        posts[#posts + 1] = p
        series.posts[#series.posts + 1] = p
      end
    end
  end
  -- numbers run 1..count with no gaps, drafts included, so URLs never shift
  for n = 1, count do
    assert(numbers[n], dir .. ": #" .. n .. " is missing; numbers run 1, 2, 3, ... with no gaps")
  end

  all_series[#all_series + 1] = series
  if #series.posts > 0 then
    table.sort(series.posts, function(a, b) return a.number < b.number end)
    series.count = entries(#series.posts)
    series.latest = series.posts[#series.posts]
    series_list[#series_list + 1] = series
  end
end

-- series colors never repeat; drafts count, so --drafts does not recolor anything
for _, series in ipairs(all_series) do series.pin, series.color = series.color, nil end
unique_colors(all_series, function(series) return "posts/" .. series.name .. "/index.md" end)

table.sort(posts, function(a, b)
  if a.date ~= b.date then return a.date > b.date end
  return a.slug < b.slug
end)

-- prev / next walk the series, and each post carries the series table of contents
for _, series in ipairs(series_list) do
  local list = series.posts
  for i, p in ipairs(list) do
    p.prev, p.next = list[i - 1], list[i + 1]
    p.episodes = {}
    for j, q in ipairs(list) do
      p.episodes[j] = { number = q.number, title = q.title, url = q.url, current = q == p }
    end
  end
end

-- related posts: most shared tags first, then newest
for _, p in ipairs(posts) do
  local mine = {}
  for _, t in ipairs(p.tags) do mine[t] = true end
  local scored = {}
  for _, q in ipairs(posts) do
    local shared = 0
    for _, t in ipairs(q.tags) do if mine[t] then shared = shared + 1 end end
    if q ~= p and q ~= p.prev and q ~= p.next and shared > 0 then scored[#scored + 1] = { post = q, shared = shared } end
  end
  table.sort(scored, function(a, b)
    if a.shared ~= b.shared then return a.shared > b.shared end
    return a.post.date > b.post.date
  end)
  p.related = {}
  for i = 1, math.min(3, #scored) do p.related[i] = scored[i].post end
end

-- tag index, ordered by count then name
local tags, by_tag = {}, {}
for _, p in ipairs(posts) do
  for _, name in ipairs(p.tags) do
    if not by_tag[name] then
      by_tag[name] = {}
      tags[#tags + 1] = name
    end
    local list = by_tag[name]
    list[#list + 1] = p
  end
end
table.sort(tags, function(a, b)
  if #by_tag[a] ~= #by_tag[b] then return #by_tag[a] > #by_tag[b] end
  return a < b
end)

do
  local items = {}
  for name in pairs(tag_names) do items[#items + 1] = { name = name, pin = site.tags[name] } end
  table.sort(items, function(a, b) return a.name < b.name end)
  unique_colors(items, function(item) return "site.lua tags." .. item.name end)
  for _, item in ipairs(items) do tag_colors[item.name] = item.color end
  for _, item in ipairs(tag_items) do item.color = tag_colors[item.name] end
end

local function all_tags(current)
  local out = {}
  for _, name in ipairs(tags) do
    local n = #by_tag[name]
    out[#out + 1] = {
      name = name,
      url = "/tags/" .. name .. "/",
      color = tag_color(name),
      count = n,
      current = name == current,
      latest = by_tag[name][1].title,
      size = (56 + math.min(n, 8) * 16) .. "px",
    }
  end
  return out
end

local function by_year(list)
  local years, index = {}, {}
  for _, p in ipairs(list) do
    if not index[p.year] then
      index[p.year] = { year = p.year, color = hex(cycle(PALETTE, #years + 1)), posts = {} }
      years[#years + 1] = index[p.year]
    end
    local group = index[p.year].posts
    group[#group + 1] = p
  end
  return years
end

---------------------------------------------------------------------------
-- the seismograph on the home page: one line per series, amplitude = posts per month.
-- Only series with posts in the window are drawn; the busiest (site.home.wave_series,
-- default 5) get their own line, ties going to the most recent, and the rest share one.

local function wave()
  if #posts == 0 or #series_list == 0 then return nil end
  local function month_index(date)
    return tonumber(date:sub(1, 4)) * 12 + tonumber(date:sub(6, 7)) - 1
  end
  local last = month_index(os.date("%Y-%m-%d"))
  local first = math.max(math.min(month_index(posts[#posts].date), last - 11), last - 35)
  local span = last - first + 1

  local active = {}
  for _, series in ipairs(series_list) do
    local recent, newest = {}, ""
    for _, p in ipairs(series.posts) do
      if month_index(p.date) >= first then
        recent[#recent + 1] = p
        if p.date > newest then newest = p.date end
      end
    end
    if #recent > 0 then
      active[#active + 1] = { name = series.name, color = series.color, posts = recent, newest = newest }
    end
  end
  if #active == 0 then return nil end
  table.sort(active, function(a, b)
    if #a.posts ~= #b.posts then return #a.posts > #b.posts end
    if a.newest ~= b.newest then return a.newest > b.newest end
    return a.name < b.name
  end)

  local max = site.home.wave_series or 5
  local shown = {}
  for i = 1, math.min(max, #active) do shown[i] = active[i] end
  if #active > max then
    local rest = {}
    for i = max + 1, #active do
      for _, p in ipairs(active[i].posts) do rest[#rest + 1] = p end
    end
    shown[#shown + 1] = { name = "other", color = HEX.muted, posts = rest }
  end

  local seed = 7
  local function rand()
    seed = (seed * 1103515245 + 12345) % 2147483648
    return seed / 2147483648
  end

  local lines = {}
  for t, entry in ipairs(shown) do
    local counts = {}
    for _, p in ipairs(entry.posts) do
      local m = month_index(p.date) - first
      counts[m] = (counts[m] or 0) + 1
    end
    local pts = {}
    for x = 0, 1200, 8 do
      local pos = x / 1200 * span
      local amp = 0.6
      for m, c in pairs(counts) do
        local d = (pos - (m + 0.5)) / 0.9
        amp = amp + c * 26 * math.exp(-d * d)
      end
      amp = math.min(amp, 46)
      local sign = (x // 8) % 2 == 0 and -1 or 1
      local y = 50 + sign * math.abs(math.sin(x * 0.23 + t)) * amp * (0.5 + rand() * 0.5)
      pts[#pts + 1] = ("%d,%.1f"):format(x, y)
    end
    table.insert(lines, 1, {
      tag = entry.name,
      color = entry.color,
      width = t == 1 and "2.8" or "2.4",
      points = table.concat(pts, " "),
    })
  end
  local function label(m) return ("%04d.%02d"):format(m // 12, m % 12 + 1) end
  -- legend in rank order, drawing order reversed so the top series is on top
  local legend = {}
  for i = #lines, 1, -1 do legend[#legend + 1] = lines[i] end
  return { lines = lines, legend = legend, from = label(first), to = label(last) }
end

---------------------------------------------------------------------------
-- pages/*.md

local function read_page(name)
  local path = "pages/" .. name .. ".md"
  if not fs.exists(path) then return nil end
  local meta, body = frontmatter.parse(fs.read(path))
  local html, _, has_code = render_markdown(body)
  meta.html, meta.has_code = html, has_code
  return meta
end

-- Age on the build date in Japan time, from "YYYY-MM-DD".
local function age(birthday)
  local by, bm, bd = tostring(birthday):match("^(%d+)-(%d+)-(%d+)$")
  if not by then error("birthday must be YYYY-MM-DD: " .. tostring(birthday)) end
  local now = os.date("!*t", os.time() + 9 * 3600)
  local years = now.year - tonumber(by)
  if now.month * 100 + now.day < tonumber(bm) * 100 + tonumber(bd) then years = years - 1 end
  return tostring(years)
end

local about = read_page("about")
if about then
  local profile = {}
  for i, item in ipairs(type(about.profile) == "table" and about.profile or {}) do
    if type(item) == "table" then
      local value = item.value
      -- AGE follows the birthday field, so it never goes stale between rebuilds
      if item.key == "AGE" and about.birthday then value = age(about.birthday) end
      profile[#profile + 1] = { key = item.key, value = value, color = hex(cycle({ "ink", "orange", "cyan", "lavender", "pink", "lime" }, i)) }
    end
  end
  local roles = {}
  for i, r in ipairs(type(about.roles) == "table" and about.roles or {}) do
    roles[i] = { text = r, color = cycle({ "cyan", "lavender", "lime" }, i) }
  end
  about.role_list = chips(roles)
  about.profile_list = profile
  about.has_profile = #profile > 0
  -- the home page shows the tiles after NAME and AGE
  about.home_profile = {}
  for i = 3, math.min(6, #profile) do about.home_profile[#about.home_profile + 1] = profile[i] end
  local work = {}
  for i, w in ipairs(type(about.work_tags) == "table" and about.work_tags or {}) do
    work[i] = { text = w, color = cycle({ "pink", "yellow", "cyan" }, i) }
  end
  about.work_chips = chips(work)
  about.heading_html = about.heading_html or escape(about.title or "About")
end

---------------------------------------------------------------------------
-- write everything

fs.rmdir(OUT)
fs.copy_tree("static", OUT)

-- home
local recent = {}
for i = 2, math.min(#posts, 1 + (site.home.recent or 3)) do recent[#recent + 1] = posts[i] end
page("/", "home", {
  home = site.home,
  featured = posts[1],
  recent = recent,
  post_count = entries(#posts),
  wave = wave(),
  about = about,
})

-- posts
for _, p in ipairs(posts) do
  page(p.url, "post", { post = p, prev = p.prev, next = p.next, series = p.series, related = p.related, has_related = #p.related > 0 }, {
    title = p.title,
    description = p.description,
    og_type = "article",
    nav = "posts",
    has_code = p.has_code,
    has_toc = p.has_toc,
  })
end

-- lists
page("/posts/", "list", {
  heading = "Posts",
  heading_dot = HEX.cyan,
  count = entries(#posts),
  total = #posts,
  all_tags = all_tags(nil),
  series_list = series_list,
  has_series = #series_list > 0,
  years = by_year(posts),
}, { title = "Posts", nav = "posts" })

for _, series in ipairs(series_list) do
  page(series.url, "series", { series = series }, {
    title = series.title,
    description = series.lead,
    nav = "posts",
  })
end

for _, name in ipairs(tags) do
  page("/tags/" .. name .. "/", "list", {
    heading = name,
    heading_dot = tag_color(name),
    current_tag = { name = name },
    count = entries(#by_tag[name]),
    total = #posts,
    all_tags = all_tags(name),
    years = by_year(by_tag[name]),
  }, { title = "#" .. name, nav = "posts" })
end

page("/tags/", "tags", { all_tags = all_tags(nil), tag_count = #tags .. (#tags == 1 and " tag" or " tags"), total = entries(#posts) }, { title = "Tags", nav = "posts" })

-- about, 404
if about then
  page("/about/", "about", { page = about }, {
    title = "About",
    description = about.lead,
    nav = "about",
    has_code = about.has_code,
  })
end
local notfound = read_page("404")
if notfound then
  page("/404.html", "404", { page = notfound }, { title = notfound.title or "404" })
end

-- old Hugo URLs
local function redirect(from, to)
  write(from, ('<!DOCTYPE html><meta charset="utf-8"><title>Moved</title>'
    .. '<meta http-equiv="refresh" content="0; url=%s"><link rel="canonical" href="%s%s">'
    .. '<p><a href="%s">%s</a></p>\n'):format(to, site.url, to, to, to))
end
redirect("/categories/", "/tags/")

---------------------------------------------------------------------------
-- feeds

-- Posts are dated in JST. Computed by hand so the output does not depend on
-- the build machine's time zone (os.time treats its table as local time).
local function rfc822(date)
  local y, m, d = date:match("^(%d+)%-(%d+)%-(%d+)$")
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  local offsets = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
  local yy = m < 3 and y - 1 or y
  local wday = (yy + yy // 4 - yy // 100 + yy // 400 + offsets[m] + d) % 7
  local days = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }
  local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
  return ("%s, %02d %s %04d 00:00:00 +0900"):format(days[wday + 1], d, months[m], y)
end

local rss = {
  '<?xml version="1.0" encoding="utf-8"?>',
  '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">',
  "<channel>",
  "<title>" .. escape(site.title) .. "</title>",
  "<link>" .. site.url .. "/</link>",
  "<description>" .. escape(site.description) .. "</description>",
  "<language>ja</language>",
  '<atom:link href="' .. site.url .. '/index.xml" rel="self" type="application/rss+xml"/>',
}
if posts[1] then rss[#rss + 1] = "<lastBuildDate>" .. rfc822(posts[1].date) .. "</lastBuildDate>" end
for i = 1, math.min(#posts, 20) do
  local p = posts[i]
  local link = site.url .. p.url
  rss[#rss + 1] = table.concat({
    "<item>",
    "<title>" .. escape(p.title) .. "</title>",
    "<link>" .. link .. "</link>",
    '<guid isPermaLink="true">' .. link .. "</guid>",
    "<pubDate>" .. rfc822(p.date) .. "</pubDate>",
    "<description>" .. escape(p.html) .. "</description>",
    "</item>",
  }, "\n")
end
rss[#rss + 1] = "</channel>\n</rss>\n"
write("/index.xml", table.concat(rss, "\n"))

local urls = { "/", "/posts/", "/tags/" }
if about then urls[#urls + 1] = "/about/" end
for _, series in ipairs(series_list) do urls[#urls + 1] = series.url end
for _, p in ipairs(posts) do urls[#urls + 1] = p.url end
for _, name in ipairs(tags) do urls[#urls + 1] = "/tags/" .. name .. "/" end
local sitemap = { '<?xml version="1.0" encoding="utf-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' }
for _, u in ipairs(urls) do sitemap[#sitemap + 1] = "<url><loc>" .. site.url .. u .. "</loc></url>" end
sitemap[#sitemap + 1] = "</urlset>\n"
write("/sitemap.xml", table.concat(sitemap, "\n"))
write("/robots.txt", "User-agent: *\nAllow: /\nSitemap: " .. site.url .. "/sitemap.xml\n")

io.write(("built %d posts in %d series, %d tags, %d files into %s/ in %.0f ms (%s)\n"):format(
  #posts, #series_list, #tags, written, OUT, (os.clock() - started) * 1000, _VERSION))
