#!/bin/bash
# macOS check of TExternalProcess roWinJobCloseChildren, with the fpc found in
# the PATH (FPC fixes_3_2 as built by build_fpc.sh in the workflow):
# - show the waitid() constants of this system;
# - build the TTestCoreBase runner for this branch, and for a mutant of this
#   branch in which the ended process is not kept: the new tests must reject it;
# - run the TExternalProcess tests five times with the branch, once with the mutant.
# A failing step does not stop the next ones: every result is in the log and in out/.
set -u
cd "$(dirname "$0")" || exit 2
HERE=$PWD
ROOT=$(cd ../.. && pwd)
OUT=$HERE/out
TESTS="-t TTestCoreBase._TExternalProcess"
mkdir -p "$OUT"
CPU=$(fpc -iTP)
W=$(mktemp -d /tmp/tcc.XXXXXX)

echo "===== system"
sw_vers
uname -a
echo "FPC $(fpc -iW) for $CPU-$(fpc -iTO) from $(command -v fpc)"
git -C "$ROOT" log --oneline -3 | cut -c1-100
SDK=$(xcrun --show-sdk-path)
echo "===== waitid constants of $SDK"
grep -n -E "define[[:space:]]+(WNOHANG|WEXITED|WNOWAIT|WSTOPPED)[[:space:]]" "$SDK/usr/include/sys/wait.h"
grep -n -E "P_ALL|P_PID|P_PGID" "$SDK/usr/include/sys/wait.h" | head -5
grep -n -E "CLD_EXITED|CLD_KILLED|CLD_DUMPED|CLD_STOPPED" "$SDK/usr/include/sys/signal.h" | head -6

echo "===== static files"
mkdir -p "$W/st"
curl -sS -L --retry 3 --max-time 300 -o "$W/static.tgz" https://synopse.info/files/mormot2static.tgz ||
  curl -sS -L --retry 3 --max-time 300 -o "$W/static.tgz" \
    https://github.com/synopse/mORMot2/releases/download/2.4-stable/mormot2static.tgz
tar xzf "$W/static.tgz" -C "$W/st"
SDIR=$(find "$W/st" -type d -name "$CPU-darwin" | head -1)
echo "static folder: $SDIR"

echo "===== mutant"
git -C "$ROOT" worktree add -q --detach "$W/t_mut" HEAD
python3 - "$W/t_mut/src/core/mormot.core.os.posix.inc" <<'EOF'
import sys
f = sys.argv[1]
a = "fZombie := r > 0;"
b = "fZombie := false; // mutation"
s = open(f, encoding="latin-1", newline="").read()
n = s.count(a)
print("mutation: %d occurrence(s) replaced" % n)
if n == 1:
    open(f, "w", encoding="latin-1", newline="").write(s.replace(a, b))
EOF

build() { # <build name> <source tree>
  local src=$2/src d u=""
  for d in core lib crypt net db orm rest soa app script ui misc ddd; do
    u="$u -Fu$src/$d"
  done
  mkdir -p "$HERE/b_$1/units"
  ( cd "$src/core" &&
    fpc -B -MDelphi -Sci -Ci -O2 -g -gl -dNO_UI -veiw \
      -vm5024,5023,3175,5026,5028,5057,5058,5059,6058,5092,5093,4055,4056,4079,4080,4081,4082,5089,5090,5091,3123,3124,3018 \
      $u "-Fu$2/test" "-Fi$src" "-Fi$src/core" "-Fl$SDIR" \
      "-FU$HERE/b_$1/units" "-FE$HERE/b_$1" "$HERE/test648.dpr" ) > "$OUT/build_$1.log" 2>&1
  echo "===== build $1: exit=$? $(ls -l "$HERE/b_$1/test648" 2>/dev/null | awk '{print $5, "bytes"}')"
  grep -E 'Fatal:|Error:|lines compiled|Undefined symbols' "$OUT/build_$1.log" | head -20
  grep -E '(mormot\.core\.os\.(pas|posix\.inc)|test\.core\.base\.pas)\([0-9]+' "$OUT/build_$1.log" | head -20
}
build new "$ROOT"
build mut "$W/t_mut"

run() { # <label> <build name>
  local dir=$HERE/b_$2 rc
  if [ ! -x "$dir/test648" ]; then
    echo "===== run $1: no executable"
    return
  fi
  ( cd "$dir" && ( sleep 30 ) | ./test648 $TESTS > "$OUT/run_$1.txt" 2>&1 )
  rc=$?
  echo "===== run $1: exit=$rc $(grep -E 'TExternalProcess:|Total failed' "$OUT/run_$1.txt" | tr -s ' ' | tr '\n' ' ')"
  grep -E '#[0-9]+ ' "$OUT/run_$1.txt" | head -10
  echo "leftover: $(pgrep -x sleep | wc -l | tr -d ' ') sleep"
}
for i in 1 2 3 4 5; do
  run "new$i" new
done
run mut mut
echo "===== expected: the five runs of new pass, the run of mut fails on closechildren"
