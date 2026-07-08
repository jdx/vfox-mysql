local http = require("http")
local json = require("json")

local util = {}

local metadata_url = "https://raw.githubusercontent.com/datacharmer/dbdeployer/master/downloads/tarball_list.json"

local function shell_quote(value)
  return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function run(cmd)
  local ok, reason, code = os.execute(cmd)
  if ok ~= true and ok ~= 0 then
    error("command failed (" .. tostring(code or reason) .. "): " .. cmd)
  end
end

local function exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

local function split_version(version)
  local parts = {}
  for n in version:gmatch("%d+") do
    table.insert(parts, tonumber(n))
  end
  return parts
end

local function version_gt(a, b)
  local av = split_version(type(a) == "table" and a.version or a)
  local bv = split_version(type(b) == "table" and b.version or b)
  for i = 1, math.max(#av, #bv) do
    local ai = av[i] or 0
    local bi = bv[i] or 0
    if ai ~= bi then
      return ai > bi
    end
  end
  return false
end

local function target_os()
  if OS_TYPE == "darwin" or OS_TYPE == "macos" then
    return "Darwin"
  end
  return "Linux"
end

local function target_arch()
  if ARCH_TYPE == "arm64" or ARCH_TYPE == "aarch64" then
    return "arm64"
  end
  return "amd64"
end

local function fetch_records()
  local resp, err = http.get({ url = metadata_url })
  if err ~= nil then
    error("failed to fetch MySQL tarball metadata: " .. err)
  end
  if resp.status_code ~= 200 then
    error("failed to fetch MySQL tarball metadata: status " .. resp.status_code)
  end
  return json.decode(resp.body).Tarballs
end

local function mysql_records()
  local records = {}
  local os_name = target_os()
  for _, record in ipairs(fetch_records()) do
    if record.flavor == "mysql" and record.minimal == false and record.OS == os_name then
      table.insert(records, record)
    end
  end
  return records
end

function util.get_versions()
  local seen = {}
  local versions = {}
  for _, record in ipairs(mysql_records()) do
    if not seen[record.version] then
      seen[record.version] = true
      table.insert(versions, { version = record.version })
    end
  end
  table.sort(versions, version_gt)
  return versions
end

function util.record_for_version(version)
  local records = {}
  for _, record in ipairs(mysql_records()) do
    if record.version == version then
      table.insert(records, record)
    end
  end
  if #records == 0 then
    error("No MySQL URL found for " .. version)
  end

  local arch = target_arch()
  for _, record in ipairs(records) do
    if record.arch == arch then
      return record
    end
  end
  return records[1]
end

function util.download_url(record)
  local url = record.url
  local series, filename = url:match("^https://dev%.mysql%.com/get/Downloads/MySQL%-([^/]+)/(.+)$")
  if series and filename then
    return "https://cdn.mysql.com/archives/mysql-" .. series .. "/" .. filename
  end
  return url
end

function util.sha512(record)
  if record.checksum then
    return record.checksum:match("^SHA512:(.+)$")
  end
  return nil
end

function util.post_install(root)
  if exists(root .. "/bin/mysql") then
    return
  end

  local handle = io.popen("find " .. shell_quote(root) .. " -mindepth 1 -maxdepth 1 -type d | head -1")
  local extracted = handle:read("*l")
  handle:close()
  if extracted == nil or extracted == "" or not exists(extracted .. "/bin/mysql") then
    error("Could not find extracted MySQL directory under " .. root)
  end

  run("cp -R " .. shell_quote(extracted .. "/.") .. " " .. shell_quote(root))
  run("rm -rf " .. shell_quote(extracted))
  run("test -x " .. shell_quote(root .. "/bin/mysql"))
end

return util
