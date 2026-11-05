-- A small Mustache-like template engine.
--
--   {{ name }}        HTML-escaped value (dotted lookup: post.title, "." = current item)
--   {{{ name }}}      raw value
--   {{# name }}..{{/ name }}   section: loops over lists, renders once for truthy values
--   {{^ name }}..{{/ name }}   inverted section: renders when falsy or empty
--   {{> name }}       partial

local template = {}

local ESC = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["'"] = "&#39;" }

function template.escape(s)
  return (tostring(s):gsub("[&<>\"']", ESC))
end

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Parses source into a tree of nodes.
local function parse(src, name)
  local root = { kind = "root", children = {} }
  local stack = { root }
  local pos = 1
  while true do
    local s, e = src:find("{{", pos, true)
    local node = stack[#stack]
    if not s then
      node.children[#node.children + 1] = src:sub(pos)
      break
    end
    if s > pos then node.children[#node.children + 1] = src:sub(pos, s - 1) end

    local raw = src:sub(s, s + 2) == "{{{"
    local close = raw and "}}}" or "}}"
    local cs, ce = src:find(close, e + 1, true)
    if not cs then error(("%s: unclosed tag at byte %d"):format(name, s)) end
    local tag = trim(src:sub(raw and s + 3 or s + 2, cs - 1))
    pos = ce + 1

    if raw then
      node.children[#node.children + 1] = { kind = "raw", key = tag }
    else
      local sigil, key = tag:sub(1, 1), trim(tag:sub(2))
      if sigil == "#" or sigil == "^" then
        local section = { kind = sigil == "#" and "section" or "inverted", key = key, children = {} }
        node.children[#node.children + 1] = section
        stack[#stack + 1] = section
      elseif sigil == "/" then
        if node.key ~= key then
          error(("%s: {{/%s}} closes {{#%s}}"):format(name, key, tostring(node.key)))
        end
        stack[#stack] = nil
      elseif sigil == ">" then
        node.children[#node.children + 1] = { kind = "partial", key = key }
      elseif sigil ~= "!" then
        node.children[#node.children + 1] = { kind = "var", key = tag }
      end
    end
  end
  if #stack > 1 then error(("%s: unclosed {{#%s}}"):format(name, stack[#stack].key)) end
  return root
end

local function lookup(ctx, key)
  if key == "." then return ctx[#ctx] end
  local first, rest = key:match("^([^%.]+)%.?(.*)$")
  for i = #ctx, 1, -1 do
    local frame = ctx[i]
    if type(frame) == "table" and frame[first] ~= nil then
      local v = frame[first]
      for part in rest:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
      end
      return v
    end
  end
  return nil
end

local function truthy(v)
  if v == nil or v == false or v == "" then return false end
  if type(v) == "table" and next(v) == nil then return false end
  return true
end

local function is_list(v)
  return type(v) == "table" and v[1] ~= nil
end

local render_nodes

local function render_node(node, ctx, out, engine)
  if type(node) == "string" then
    out[#out + 1] = node
  elseif node.kind == "var" then
    local v = lookup(ctx, node.key)
    if v ~= nil then out[#out + 1] = template.escape(v) end
  elseif node.kind == "raw" then
    local v = lookup(ctx, node.key)
    if v ~= nil then out[#out + 1] = tostring(v) end
  elseif node.kind == "section" then
    local v = lookup(ctx, node.key)
    if is_list(v) then
      for _, item in ipairs(v) do
        ctx[#ctx + 1] = item
        render_nodes(node.children, ctx, out, engine)
        ctx[#ctx] = nil
      end
    elseif truthy(v) then
      ctx[#ctx + 1] = v
      render_nodes(node.children, ctx, out, engine)
      ctx[#ctx] = nil
    end
  elseif node.kind == "inverted" then
    if not truthy(lookup(ctx, node.key)) then
      render_nodes(node.children, ctx, out, engine)
    end
  elseif node.kind == "partial" then
    render_nodes(engine:load(node.key).children, ctx, out, engine)
  end
end

function render_nodes(nodes, ctx, out, engine)
  for _, node in ipairs(nodes) do
    render_node(node, ctx, out, engine)
  end
end

-- Creates an engine that loads "<dir>/<name>.html" on demand.
function template.new(dir, read)
  local engine = { dir = dir, cache = {} }
  function engine:load(name)
    if not self.cache[name] then
      self.cache[name] = parse(read(self.dir .. "/" .. name .. ".html"), name)
    end
    return self.cache[name]
  end
  function engine:render(name, data)
    local out = {}
    render_nodes(self:load(name).children, { data }, out, self)
    return table.concat(out)
  end
  return engine
end

return template
