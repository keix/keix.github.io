-- Markdown to HTML, written with Lua patterns only.
--
-- Blocks:  ATX headings (## text {#id}), paragraphs, fenced code (```lang file),
--          blockquotes, nested lists, GFM tables, horizontal rules, raw HTML blocks.
-- Inline:  `code`, **strong**, *em*, ~~del~~, [link](url), ![image](src "title"),
--          <https://autolink>, inline HTML, backslash escapes, hard breaks.

local markdown = {}

local ESC = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;" }

local function escape(s)
  return (s:gsub('[&<>"]', ESC))
end
markdown.escape = escape

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Removes tags, leaving plain text.
function markdown.strip_tags(html)
  return (html:gsub("<[^>]*>", ""):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&amp;", "&"))
end

---------------------------------------------------------------------------
-- Inline

local function inline(s)
  local stash = {}
  local function keep(html)
    stash[#stash + 1] = html
    return "\1" .. #stash .. "\2"
  end

  -- Code spans first: nothing inside them is markup.
  s = s:gsub("(`+)(.-)%1", function(_, code)
    code = code:gsub("^ (.*) $", "%1")
    return keep("<code>" .. escape(code) .. "</code>")
  end)
  s = s:gsub("\\([%p])", function(c) return keep(escape(c)) end)
  s = s:gsub("<(https?://[^%s>]+)>", function(url)
    return keep('<a href="' .. escape(url) .. '">' .. escape(url) .. "</a>")
  end)
  s = s:gsub("<(/?%a[%w%-]*[^<>]*)>", function(tag) return keep("<" .. tag .. ">") end)
  s = escape(s)

  s = s:gsub("!%[(.-)%]%((.-)%)", function(alt, target)
    local src, title = target:match('^(%S+)%s+&quot;(.*)&quot;$')
    src = src or trim(target)
    local t = title and (' title="' .. title .. '"') or ""
    return keep('<img src="' .. src .. '" alt="' .. alt .. '"' .. t .. ' loading="lazy">')
  end)
  s = s:gsub("%[(.-)%]%((.-)%)", function(text, target)
    local href = target:match("^(%S+)") or ""
    return keep('<a href="' .. href .. '">') .. text .. keep("</a>")
  end)

  s = s:gsub("%*%*(.-)%*%*", "<strong>%1</strong>")
  s = s:gsub("%*([^%*%s][^%*]-)%*", "<em>%1</em>")
  s = s:gsub("~~(.-)~~", "<del>%1</del>")
  s = s:gsub("  +\n", "<br>\n")

  -- Restore stashed pieces; a stash may itself contain markers.
  local n
  repeat
    s, n = s:gsub("\1(%d+)\2", function(i) return stash[tonumber(i)] end)
  until n == 0
  return s
end
markdown.inline = inline

---------------------------------------------------------------------------
-- Blocks

local BLOCK_TAGS = {
  address = true, article = true, aside = true, details = true, div = true, dl = true,
  figure = true, footer = true, form = true, header = true, hr = true, iframe = true,
  nav = true, ol = true, p = true, pre = true, section = true, table = true, ul = true,
  video = true, audio = true, picture = true, ["!--"] = true,
}

local function is_blank(line) return line:match("^%s*$") ~= nil end

local function fence_open(line)
  local indent, fence, info = line:match("^(%s*)(```+)%s*(.-)%s*$")
  if not fence then indent, fence, info = line:match("^(%s*)(~~~+)%s*(.-)%s*$") end
  if fence and #indent < 4 then return fence, info end
end

local function heading(line)
  local marks, text = line:match("^(#+)%s+(.-)%s*$")
  if marks and #marks <= 6 then
    text = text:gsub("%s+#+$", "")
    return #marks, text
  end
end

local function is_hr(line)
  local t = line:gsub("%s", "")
  return #t >= 3 and (t:match("^%-+$") or t:match("^%*+$") or t:match("^_+$")) ~= nil
end

local function list_marker(line)
  local indent, marker, rest = line:match("^(%s*)([%-%*%+])%s+(.*)$")
  if marker then return #indent, "ul", #indent + #marker + 1, rest end
  local num, delim
  indent, num, delim, rest = line:match("^(%s*)(%d+)([%.%)])%s+(.*)$")
  if num then return #indent, "ol", #indent + #num + 2, rest, tonumber(num) end
end

local function html_block(line)
  local tag = line:match("^%s*<(!%-%-)") or line:match("^%s*</?([%a][%w]*)")
  return tag and BLOCK_TAGS[tag:lower()]
end

local function table_delim(line)
  if not line or not line:find("-", 1, true) then return nil end
  local t = trim(line):gsub("^|", ""):gsub("|$", "")
  local aligns = {}
  for cell in (t .. "|"):gmatch("(.-)|") do
    cell = trim(cell)
    if not cell:match("^:?%-+:?$") then return nil end
    local l, r = cell:sub(1, 1) == ":", cell:sub(-1) == ":"
    aligns[#aligns + 1] = (l and r) and "center" or r and "right" or l and "left" or false
  end
  return aligns
end

local function split_row(line)
  local t = trim(line):gsub("^|", ""):gsub("|$", "")
  local cells = {}
  for cell in (t .. "|"):gmatch("(.-)|") do cells[#cells + 1] = trim(cell) end
  return cells
end

local function starts_block(line)
  return fence_open(line) or heading(line) or is_hr(line) or line:match("^%s*>")
      or list_marker(line) or html_block(line)
end

local function slugify(text, used)
  -- Drops ASCII punctuation only, so Japanese headings keep their text as the id.
  local slug = markdown.strip_tags(text):lower():gsub("[%p]", function(c)
    return (c == "-" or c == "_") and c or ""
  end):gsub("%s+", "-"):gsub("%-+", "-")
  slug = slug:gsub("^%-", ""):gsub("%-$", "")
  if slug == "" then slug = "section" end
  local base, n = slug, 1
  while used[slug] do
    n = n + 1
    slug = base .. "-" .. n
  end
  used[slug] = true
  return slug
end

local parse_blocks

local function parse_list(lines, i, ctx)
  local base, kind, _, _, start = list_marker(lines[i])
  local items, loose = {}, false

  while i <= #lines do
    local indent, k, content_col, rest = list_marker(lines[i])
    if not indent or indent ~= base or k ~= kind then break end
    local body = { rest }
    i = i + 1
    local blank_seen = false
    while i <= #lines do
      local line = lines[i]
      if is_blank(line) then
        blank_seen = true
        body[#body + 1] = ""
        i = i + 1
      else
        local lead = #line:match("^(%s*)")
        local mi, mk = list_marker(line)
        if lead >= content_col then
          if blank_seen then loose = true end
          body[#body + 1] = line:sub(content_col + 1)
          blank_seen = false
          i = i + 1
        elseif mi and mi == base and mk == kind then
          if blank_seen then loose = true end
          break
        elseif not blank_seen and not starts_block(line) then
          body[#body + 1] = trim(line) -- lazy continuation
          i = i + 1
        else
          break
        end
      end
    end
    while body[#body] == "" do body[#body] = nil end
    items[#items + 1] = body
  end

  local out = {}
  local open = kind == "ol" and start and start ~= 1 and ('<ol start="' .. start .. '">') or ("<" .. kind .. ">")
  out[#out + 1] = open
  for _, body in ipairs(items) do
    local html = parse_blocks(body, ctx)
    if not loose then
      html = html:gsub("^<p>(.-)</p>", "%1", 1)
    end
    out[#out + 1] = "<li>" .. html .. "</li>"
  end
  out[#out + 1] = "</" .. kind .. ">"
  return table.concat(out, "\n"), i
end

function parse_blocks(lines, ctx)
  local out = {}
  local i = 1
  while i <= #lines do
    local line = lines[i]
    local fence, info = fence_open(line)
    local level, htext = heading(line)

    if is_blank(line) then
      i = i + 1

    elseif fence then
      local code = {}
      i = i + 1
      while i <= #lines and not lines[i]:match("^%s*" .. fence:sub(1, 1):rep(#fence)) do
        code[#code + 1] = lines[i]
        i = i + 1
      end
      i = i + 1
      local lang, file = info:match("^(%S*)%s*(.-)$")
      out[#out + 1] = ctx.code(table.concat(code, "\n"), lang or "", file or "")

    elseif level then
      local id = htext:match("%s*{#([%w_%-]+)}$")
      htext = htext:gsub("%s*{#[%w_%-]+}$", "")
      local html = inline(htext)
      id = id or slugify(html, ctx.ids)
      if level == 2 or level == 3 then
        ctx.toc[#ctx.toc + 1] = { level = level, id = id, text = markdown.strip_tags(html) }
      end
      out[#out + 1] = ("<h%d id=\"%s\">%s</h%d>"):format(level, id, html, level)
      i = i + 1

    elseif is_hr(line) then
      out[#out + 1] = "<hr>"
      i = i + 1

    elseif line:match("^%s*>") then
      local quote = {}
      while i <= #lines and lines[i]:match("^%s*>") do
        quote[#quote + 1] = lines[i]:gsub("^%s*> ?", "")
        i = i + 1
      end
      out[#out + 1] = "<blockquote>\n" .. parse_blocks(quote, ctx) .. "\n</blockquote>"

    elseif list_marker(line) then
      local html
      html, i = parse_list(lines, i, ctx)
      out[#out + 1] = html

    elseif line:find("|", 1, true) and table_delim(lines[i + 1]) then
      local aligns = table_delim(lines[i + 1])
      local function row(cells, tag)
        local r = {}
        for c = 1, #aligns do
          local style = aligns[c] and (' style="text-align:' .. aligns[c] .. '"') or ""
          r[#r + 1] = "<" .. tag .. style .. ">" .. inline(cells[c] or "") .. "</" .. tag .. ">"
        end
        return "<tr>" .. table.concat(r) .. "</tr>"
      end
      local t = { "<table>", "<thead>" .. row(split_row(line), "th") .. "</thead>", "<tbody>" }
      i = i + 2
      while i <= #lines and lines[i]:find("|", 1, true) and not is_blank(lines[i]) do
        t[#t + 1] = row(split_row(lines[i]), "td")
        i = i + 1
      end
      t[#t + 1] = "</tbody>"
      t[#t + 1] = "</table>"
      out[#out + 1] = table.concat(t, "\n")

    elseif html_block(line) then
      local block = {}
      while i <= #lines and not is_blank(lines[i]) do
        block[#block + 1] = lines[i]
        i = i + 1
      end
      out[#out + 1] = table.concat(block, "\n")

    else
      local para = { line }
      i = i + 1
      while i <= #lines and not is_blank(lines[i]) and not starts_block(lines[i]) do
        para[#para + 1] = lines[i]
        i = i + 1
      end
      out[#out + 1] = "<p>" .. inline(trim(table.concat(para, "\n"))) .. "</p>"
    end
  end
  return table.concat(out, "\n")
end

local function default_code(code, lang)
  local class = lang ~= "" and (' class="language-' .. escape(lang) .. '"') or ""
  return "<pre><code" .. class .. ">" .. escape(code) .. "</code></pre>"
end

-- Returns html, toc. opts.code(code, lang, file) renders fenced code blocks.
function markdown.render(text, opts)
  opts = opts or {}
  local lines = {}
  text = text:gsub("\r\n", "\n"):gsub("\t", "    ")
  for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
  local ctx = { toc = {}, ids = {}, code = opts.code or default_code }
  return parse_blocks(lines, ctx), ctx.toc
end

return markdown
