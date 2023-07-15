ROOT=$(pwd)
CPUS=`grep processor /proc/cpuinfo | wc -l`
grep -q "release 10" /etc/os-release && VERS=10 || VERS=0
grep -q "release 11" /etc/os-release && VERS=11
echo "ROOT:$ROOT"
echo "CPUS:$CPUS"
echo "VERS:$VERS"

# V1 > V2
function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }
# V1 >= V2
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }
# V1 <= V2
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" == "$1"; }
# V1 < V2
function version_lt() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; }
