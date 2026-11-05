-- Minimal file system helpers.
-- Standard Lua has no directory API, so listing and copying go through the shell.

local fs = {}

local function quote(path)
  return "'" .. path:gsub("'", "'\\''") .. "'"
end

function fs.read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("a")
  f:close()
  return s
end

function fs.write(path, data)
  fs.mkdir(path:match("^(.*)/[^/]*$") or ".")
  local f = assert(io.open(path, "wb"))
  f:write(data)
  f:close()
end

function fs.exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

function fs.mkdir(dir)
  assert(os.execute("mkdir -p " .. quote(dir)))
end

function fs.rmdir(dir)
  assert(os.execute("rm -rf " .. quote(dir)))
end

-- Copies the contents of src into dst.
function fs.copy_tree(src, dst)
  fs.mkdir(dst)
  assert(os.execute("cp -R " .. quote(src) .. "/. " .. quote(dst)))
end

-- Returns the sorted file names in dir that end with suffix.
function fs.list(dir, suffix)
  local names = {}
  local p = io.popen("ls -1 " .. quote(dir) .. " 2>/dev/null")
  if not p then return names end
  for name in p:lines() do
    if not suffix or name:sub(-#suffix) == suffix then
      names[#names + 1] = name
    end
  end
  p:close()
  table.sort(names)
  return names
end

-- Returns the sorted names of the subdirectories of dir.
function fs.dirs(dir)
  local names = {}
  local p = io.popen("ls -1 -p " .. quote(dir) .. " 2>/dev/null")
  if not p then return names end
  for name in p:lines() do
    if name:sub(-1) == "/" then names[#names + 1] = name:sub(1, -2) end
  end
  p:close()
  table.sort(names)
  return names
end

return fs
