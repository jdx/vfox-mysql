local current_unavailable = false
local archive_unavailable = false

local linux_downloads = [[
<option value="26.7">26.7.0</option>
<option value="9.7">9.7.2 LTS</option>
(mysql-26.7.0-linux-glibc2.28-aarch64.tar.xz)
(mysql-26.7.0-linux-glibc2.28-x86_64-minimal.tar.xz)
(mysql-26.7.0-linux-glibc2.28-x86_64.tar.xz)
]]

local macos_downloads = [[
<option value="26.7">26.7.0</option>
(mysql-26.7.0-macos15-x86_64.tar.gz)
(mysql-26.7.0-macos15-arm64.tar.gz)
]]

local archive_records = {
  {
    flavor = "mysql",
    minimal = false,
    OS = "Linux",
    arch = "amd64",
    version = "8.0.33",
    url = "https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.33-linux.tar.gz",
    checksum = "SHA512:archive-checksum",
  },
}

package.preload.http = function()
  return {
    -- http.get yields on the network and cannot run under pcall in Lua 5.1.
    get = function()
      error("http.get must not be used; use http.try_get")
    end,
    try_get = function(request)
      if request.url:find("datacharmer", 1, true) then
        if archive_unavailable then
          return { status_code = 503, body = "unavailable" }
        end
        return { status_code = 200, body = "archive fixture" }
      end
      if current_unavailable then
        return { status_code = 503, body = "unavailable" }
      end
      if request.url:find("os=33", 1, true) then
        return { status_code = 200, body = macos_downloads }
      end
      return { status_code = 200, body = linux_downloads }
    end,
  }
end

package.preload.json = function()
  return {
    decode = function()
      return { Tarballs = archive_records }
    end,
  }
end

package.path = "./lib/?.lua;" .. package.path
OS_TYPE = "linux"
ARCH_TYPE = "amd64"

local util = require("util")
local versions = util.get_versions()
local found = {}
for _, version in ipairs(versions) do
  found[version.version] = true
end
assert(found["26.7.0"], "current release is missing")
assert(found["9.7.2"], "current LTS release is missing")
assert(found["8.0.33"], "archived release is missing")

local current = util.record_for_version("26.7.0")
assert(current.filename == "mysql-26.7.0-linux-glibc2.28-x86_64.tar.xz")
assert(
  util.download_url(current) == "https://cdn.mysql.com/Downloads/MySQL-26.7/mysql-26.7.0-linux-glibc2.28-x86_64.tar.xz"
)

local archived = util.record_for_version("8.0.33")
assert(util.sha512(archived) == "archive-checksum")
assert(util.download_url(archived) == "https://cdn.mysql.com/archives/mysql-8.0/mysql-8.0.33-linux.tar.gz")

current_unavailable = true
versions = util.get_versions()
assert(#versions == 1 and versions[1].version == "8.0.33", "archives should remain available")
current_unavailable = false

archive_unavailable = true
versions = util.get_versions()
found = {}
for _, version in ipairs(versions) do
  found[version.version] = true
end
assert(found["26.7.0"] and found["9.7.2"], "current releases should remain available")
assert(not found["8.0.33"], "unavailable archives should be omitted")
current = util.record_for_version("26.7.0")
assert(current.filename == "mysql-26.7.0-linux-glibc2.28-x86_64.tar.xz")
archive_unavailable = false

-- An amd64-only archive must not be selected on arm64.
ARCH_TYPE = "arm64"
package.loaded.util = nil
util = require("util")
local ok = pcall(util.record_for_version, "8.0.33")
assert(not ok, "amd64 archive must not be used on arm64")

-- Windows is unsupported and must fail before any download is chosen.
OS_TYPE = "windows"
ARCH_TYPE = "amd64"
package.loaded.util = nil
util = require("util")
ok = pcall(util.record_for_version, "26.7.0")
assert(not ok, "windows should be rejected")

OS_TYPE = "darwin"
ARCH_TYPE = "arm64"
package.loaded.util = nil
util = require("util")
current = util.record_for_version("26.7.0")
assert(current.filename == "mysql-26.7.0-macos15-arm64.tar.gz")

-- metadata.lua runs on every plugin metadata load, so it must stay pure data.
-- Anything that shells out or reads host state fails the suite here.
local real_execute, real_popen, real_open = os.execute, io.popen, io.open
os.execute = function(command)
  error("metadata.lua must not spawn processes: " .. tostring(command))
end
io.popen = function(command)
  error("metadata.lua must not spawn processes: " .. tostring(command))
end
io.open = function(path, ...)
  if path == "/etc/os-release" then
    error("metadata.lua must not read host state: " .. path)
  end
  return real_open(path, ...)
end
dofile("metadata.lua")
os.execute, io.popen, io.open = real_execute, real_popen, real_open

assert(#PLUGIN.systemDependencies == 3)
assert(PLUGIN.systemDependencies[1].sharedlib == "libncurses.so.6")
assert(PLUGIN.systemDependencies[1].packages.apt == "libncurses6")
assert(PLUGIN.systemDependencies[1].packages.apk == nil)
assert(PLUGIN.systemDependencies[3].sharedlib == "libnuma.so.1")
assert(PLUGIN.systemDependencies[3].packages.apt == "libnuma1")
assert(PLUGIN.systemDependencies[3].packages.apk == nil)

-- libaio is the one package the time_t transition renamed: mise asks apt which
-- candidate exists, newest name first. libncurses6/libnuma1 were not renamed,
-- so they stay single names.
local libaio_apt = PLUGIN.systemDependencies[2].packages.apt
assert(type(libaio_apt) == "table", "libaio apt hint should list candidates")
assert(libaio_apt[1] == "libaio1t64")
assert(libaio_apt[2] == "libaio1")
assert(#libaio_apt == 2)
assert(PLUGIN.systemDependencies[2].packages.apk == nil)

print("ok")
