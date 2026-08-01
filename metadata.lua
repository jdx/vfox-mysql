PLUGIN = {}

PLUGIN.name = "mysql"
PLUGIN.version = "0.1.0"
PLUGIN.homepage = "https://github.com/jdx/vfox-mysql"
PLUGIN.license = "MIT"
PLUGIN.description = "MySQL Database"
PLUGIN.minRuntimeVersion = "0.3.0"
PLUGIN.notes = {
  "Uses MySQL's official download page for current releases and dbdeployer's metadata for archives.",
}
PLUGIN.systemDependencies = {
  {
    sharedlib = "libncurses.so.6",
    packages = {
      apt = "libncurses6",
      dnf = "ncurses-libs",
      pacman = "ncurses",
      apk = "ncurses-libs",
    },
  },
  {
    command = "test \"$(uname -s)\" != Linux || ldconfig -p 2>/dev/null | grep -Eq 'libaio\\.so\\.1(t64)? '",
    packages = {
      apt = "libaio1t64",
      dnf = "libaio",
      pacman = "libaio",
      apk = "libaio",
    },
  },
  {
    sharedlib = "libnuma.so.1",
    packages = {
      apt = "libnuma1",
      dnf = "numactl-libs",
      pacman = "numactl",
      apk = "numactl",
    },
  },
}
