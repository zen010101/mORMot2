#!/bin/bash
# build and install FPC from the fixes_3_2 branch into $1, with the FPC of Homebrew as starting compiler
# usage: build_fpc.sh <install folder> <fixes_3_2 commit>
set -u
P=$1
SDK=$(xcrun --show-sdk-path)
CPU=$(fpc -iTP)
case "$CPU" in
  x86_64) PPC=ppcx64;;
  aarch64) PPC=ppca64;;
  *) echo "unexpected CPU $CPU"; exit 2;;
esac
echo "starting compiler: $(command -v fpc) $(fpc -iW), SDK $SDK"
echo "Homebrew fpc.cfg options for the SDK:"
find "$(brew --prefix fpc)/" -name fpc.cfg -exec grep -h -E '^-XR|^-Fl|^-k' {} + 2>/dev/null | head
git clone -q --depth 1 --branch fixes_3_2 https://gitlab.com/freepascal.org/fpc/source.git /tmp/fpcsrc || exit 2
git -C /tmp/fpcsrc log --oneline -1 | cut -c1-100
[ "$(git -C /tmp/fpcsrc rev-parse HEAD)" = "$2" ] || echo "warning: the branch moved since the cache key was computed"
cd /tmp/fpcsrc || exit 2
start=$(date +%s)
if ! make all OPT="-XR$SDK" FPMAKEOPT="-T 4" > /tmp/fpc_make.log 2>&1; then
  echo "make all failed after $(( $(date +%s) - start )) s"
  grep -E 'Error|Fatal|error:' /tmp/fpc_make.log | head -20
  tail -40 /tmp/fpc_make.log
  exit 1
fi
echo "make all: $(( $(date +%s) - start )) s"
if ! make install INSTALL_PREFIX="$P" OPT="-XR$SDK" FPMAKEOPT="-T 4" > /tmp/fpc_install.log 2>&1; then
  echo "make install failed"
  tail -40 /tmp/fpc_install.log
  exit 1
fi
V=$(ls "$P/lib/fpc" | grep -E '^[0-9]' | head -1)
ln -sf "$P/lib/fpc/$V/$PPC" "$P/bin/$PPC"
mkdir -p "$P/etc"
"$P/bin/fpcmkcfg" -d "basepath=$P/lib/fpc/$V" -o "$P/etc/fpc.cfg" || exit 1
echo "-XR$SDK" >> "$P/etc/fpc.cfg"
echo "installed FPC $V into $P: $(PPC_CONFIG_PATH=$P/etc "$P/bin/fpc" -iW)"
