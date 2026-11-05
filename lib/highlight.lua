-- A tiny line-based syntax highlighter.
-- Emits <span class="k|s|n|c|f"> for keywords, strings, numbers, comments and calls.

local highlight = {}

local function set(words)
  local t = {}
  for w in words:gmatch("%S+") do t[w] = true end
  return t
end

local C_LIKE = "if else for while do return break continue switch case default struct enum union const static void"
local LANGS = {
  lua = {
    keywords = set("and break do else elseif end false for function goto if in local nil not or repeat return then true until while"),
    comment = "--",
  },
  zig = {
    keywords = set(C_LIKE .. " fn pub var try catch defer errdefer comptime orelse and or null undefined true false test usingnamespace inline export extern"),
    comment = "//",
  },
  c = {
    keywords = set(C_LIKE .. " int char long short unsigned signed float double sizeof typedef extern goto NULL include define"),
    comment = "//",
  },
  sh = {
    keywords = set("if then else elif fi for in do done while until case esac function return export local"),
    comment = "#",
  },
  python = {
    keywords = set("and as assert break class continue def del elif else except False finally for from global if import in is lambda None nonlocal not or pass raise return True try while with yield"),
    comment = "#",
  },
}
LANGS.bash, LANGS.shell, LANGS.zsh, LANGS.h, LANGS.py = LANGS.sh, LANGS.sh, LANGS.sh, LANGS.c, LANGS.python
LANGS.js = { keywords = set("const let var function return if else for while do break continue new class extends import export from await async true false null undefined this typeof"), comment = "//" }
LANGS.javascript, LANGS.ts, LANGS.typescript = LANGS.js, LANGS.js, LANGS.js

local ESC = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }
local function esc(s) return (s:gsub("[&<>]", ESC)) end
local function span(class, text) return '<span class="' .. class .. '">' .. esc(text) .. "</span>" end

local function line_html(line, lang)
  local out, i, n = {}, 1, #line
  while i <= n do
    local rest = line:sub(i)
    local c = rest:sub(1, 1)
    if rest:sub(1, #lang.comment) == lang.comment then
      out[#out + 1] = span("c", rest)
      break
    elseif c == '"' or c == "'" or c == "`" then
      local j = i + 1
      while j <= n do
        local d = line:sub(j, j)
        if d == "\\" then j = j + 1 elseif d == c then break end
        j = j + 1
      end
      out[#out + 1] = span("s", line:sub(i, j))
      i = j + 1
    elseif c:match("%d") then
      local num = rest:match("^0[xX]%x+") or rest:match("^%d+%.?%d*[eE][%+%-]?%d+") or rest:match("^%d+%.?%d*")
      out[#out + 1] = span("n", num)
      i = i + #num
    elseif c:match("[%a_]") then
      local word = rest:match("^[%w_]+")
      local after = line:sub(i + #word):match("^%s*(.)")
      if lang.keywords[word] then
        out[#out + 1] = span("k", word)
      elseif after == "(" then
        out[#out + 1] = span("f", word)
      else
        out[#out + 1] = esc(word)
      end
      i = i + #word
    else
      out[#out + 1] = esc(c)
      i = i + 1
    end
  end
  return table.concat(out)
end

-- Returns highlighted HTML for code, one <span class="ln"> per line.
function highlight.render(code, name)
  local lang = LANGS[(name or ""):lower()]
  local lines = {}
  local n = 0
  for line in (code .. "\n"):gmatch("(.-)\n") do
    n = n + 1
    local html = lang and line_html(line, lang) or esc(line)
    lines[#lines + 1] = '<span class="ln">' .. n .. "</span>" .. html
  end
  return table.concat(lines, "\n")
end

return highlight
