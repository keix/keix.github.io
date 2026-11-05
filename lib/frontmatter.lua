-- Front matter: a small subset of YAML between two "---" lines.
--
--   title: Hello
--   tags: [lua, zig]
--   draft: true
--   profile:
--     - EDITOR: Vim        -> { key = "EDITOR", value = "Vim" }
--     - plain item         -> "plain item"

local frontmatter = {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function scalar(s)
  s = trim(s)
  if s == "true" then return true end
  if s == "false" then return false end
  local q = s:match('^"(.*)"$') or s:match("^'(.*)'$")
  return q or s
end

local function inline_list(s)
  local list = {}
  for item in s:gmatch("[^,]+") do
    item = scalar(item)
    if item ~= "" then list[#list + 1] = item end
  end
  return list
end

-- Returns meta, body. A document without front matter yields an empty meta.
function frontmatter.parse(text)
  text = text:gsub("\r\n", "\n")
  local head, body = text:match("^%-%-%-\n(.-)\n%-%-%-\n?(.*)$")
  if not head then return {}, text end

  local meta, list_key = {}, nil
  for line in (head .. "\n"):gmatch("(.-)\n") do
    local item = line:match("^%s+%-%s+(.*)$")
    if item and list_key then
      local k, v = item:match("^([%w_%-]+):%s+(.*)$")
      local list = meta[list_key]
      list[#list + 1] = k and { key = k, value = scalar(v) } or scalar(item)
    elseif not line:match("^%s*$") and not line:match("^%s*#") then
      local key, value = line:match("^([%w_%-]+):%s*(.*)$")
      if key then
        value = trim(value)
        list_key = nil
        if value == "" then
          meta[key] = {}
          list_key = key
        elseif value:match("^%[.*%]$") then
          meta[key] = inline_list(value:sub(2, -2))
        else
          meta[key] = scalar(value)
        end
      end
    end
  end
  return meta, body
end

return frontmatter
