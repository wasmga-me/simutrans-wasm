#!/bin/sh
# Builds Simutrans (https://www.simutrans.com/, Artistic License 1.0) for the
# site, from the 125.0.1 release with its SDL2 backend, with these changes
# (simutrans.diff beside this script):
# - the game runs on the page's main thread, sleeping with Asyncify, and
#   gives the browser a turn while it builds a map or catches up;
# - the page sizes the game to its game area (wg_resize), scaled down to keep
#   at least 720x480 on a small screen, and can stand it
#   still (wg_hold); the game's own full screen and borderless options are off;
# - the game in progress is written to /wg/snapshot.sve when the page asks,
#   and /wg/restore.sve is loaded when it asks (Resume), from a game or the
#   main menu; the page asks the game to write the settings it would write as
#   it quits;
# - Quit, Play Online, Install (the pakset downloader) and "Start this as a
#   server" are left out: the page is the game's window and it plays alone;
# - music: the songs play through FluidSynth (built here without its audio
#   drivers, threads or glib), mixed into the game's own sound output.
# Built without threads or network play. main() is run by the play page (INVOKE_RUN=0).
#
# The game's data zip holds the simutrans folder of the source (settings,
# fonts, themes, scripts, the AI, the songs) with the languages the page offers
# that the game's own fonts draw (English, German, French, Spanish, Portuguese
# and Russian). pak64 is served as released, and the sound font is the
# TimGM6mb.sf2 the OpenTTD build fetches.
#
# Needs git, make, zip, curl, cmake, ninja and emsdk 4.0.7 (source emsdk_env.sh first).
# Usage: sh build.sh [work dir]
# Writes simutrans.js and simutrans.wasm next to this script, and the files for R2
# to <work dir>/r2/simutrans/ (upload them to wasmgame-files under the same keys).
# For a newer Simutrans, copy this folder to simutrans-<new rev>-p1 and change the
# revision below; a change to the build here takes the next -p number.
set -eu

SIMUTRANS_REV=40bbb12894793cc7c6ae5c93f31a16e7e7707627 # 125.0.1
FLUIDSYNTH_REV=v2.5.7
PAK64=https://downloads.sourceforge.net/project/simutrans/pak64/125-0/simupak64-125-0.zip
EMSDK_VERSION=4.0.7
LANGS="en de fr es pt ru"

here=$(cd "$(dirname "$0")" && pwd)
work=${1:-${TMPDIR:-/tmp}/simutrans-build}
src=$work/simutrans

case "$(emcc --version | head -1)" in
  *" $EMSDK_VERSION "*) ;;
  *) echo "warning: built and tested with emsdk $EMSDK_VERSION" >&2 ;;
esac

# Emscripten fetches these ports as GitHub archives; clone them instead.
. "$here/ports.sh"
port zlib madler/zlib v1.3.1 zlib-1.3.1 https://github.com/madler/zlib/archive/refs/tags/v1.3.1.tar.gz
port bzip2 emscripten-ports/bzip2 1.0.6 bzip2-1.0.6 https://github.com/emscripten-ports/bzip2/archive/1.0.6.zip
port freetype freetype/freetype VER-2-13-3 freetype-VER-2-13-3 https://github.com/freetype/freetype/archive/VER-2-13-3.zip
port sdl2 libsdl-org/SDL release-2.32.0 SDL-release-2.32.0 https://github.com/libsdl-org/SDL/archive/release-2.32.0.zip

mkdir -p "$work"
# A checkout left by an earlier build is reset, so this folder's diff is the one applied.
if [ ! -d "$src" ]; then
  git init -q "$src"
  git -C "$src" remote add origin https://github.com/simutrans/simutrans.git
fi
git -C "$src" fetch -q --depth 1 origin "$SIMUTRANS_REV"
git -C "$src" -c advice.detachedHead=false checkout -q -f "$SIMUTRANS_REV"
git -C "$src" clean -q -fd src
git -C "$src" apply "$here/simutrans.diff"

# FluidSynth, a static library with nothing but the synth and MIDI player.
fs=$work/fluidsynth
[ -d "$fs" ] || git clone -q --depth 1 -b "$FLUIDSYNTH_REV" https://github.com/FluidSynth/fluidsynth.git "$fs"
git -C "$fs" submodule update -q --init --depth 1 gcem
off=""
for o in threads openmp libsndfile network ipv6 aufile alsa jack pulseaudio pipewire sdl3 oss dbus ladspa \
  libinstpatch midishare readline native-dls systemd; do off="$off -Denable-$o=OFF"; done
# shellcheck disable=SC2086
emcmake cmake -S "$fs" -B "$work/fluidsynth-build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
  -Dosal=embedded -Denable-floats=ON -DGCEM_INCLUDE_DIR="$fs/gcem/include" $off > /dev/null
ninja -C "$work/fluidsynth-build" libfluidsynth > /dev/null
inc=$work/fluidsynth-include
rm -rf "$inc"
mkdir -p "$inc/fluidsynth"
cp "$fs"/include/fluidsynth/*.h "$work/fluidsynth-build/include/fluidsynth/version.h" "$inc/fluidsynth/"
cp "$work/fluidsynth-build/include/fluidsynth.h" "$inc/"

# The game, with the Makefile: pkg-config's part is played by this script.
flags=$work/emflags
cat > "$flags" <<'EOF'
#!/bin/sh
case "$1" in sdl2) echo "-sUSE_SDL=2" ;; freetype2) echo "-sUSE_FREETYPE=1" ;; esac
EOF
chmod +x "$flags"
ports="-sUSE_SDL=2 -sUSE_FREETYPE=1 -sUSE_ZLIB=1 -sUSE_BZIP2=1 -sUSE_LIBPNG=1"
cat > "$src/config.web" <<EOF
BACKEND := sdl2
OSTYPE := linux
MULTI_THREAD := 0
USE_FREETYPE := 1
USE_FLUIDSYNTH_MIDI := 1
SDL2_CONFIG := $flags sdl2
FREETYPE_CONFIG := $flags freetype2
CC := emcc
CXX := em++
HOSTCC := emcc
HOSTCXX := em++
FLAGS := -Os $ports -I$inc
LDFLAGS := -Os $ports -L$work/fluidsynth-build/src -sASYNCIFY -sASYNCIFY_STACK_SIZE=262144 -sSTACK_SIZE=1MB \
  -sALLOW_MEMORY_GROWTH -sINITIAL_MEMORY=128MB -sINVOKE_RUN=0 -sEXIT_RUNTIME=0 -sFORCE_FILESYSTEM \
  -sEXPORTED_RUNTIME_METHODS=FS,callMain -sENVIRONMENT=web
PROG := simutrans.js
BUILDDIR := $work/build
EOF
make -C "$src" CFG=web -j"$(nproc)" > /dev/null
cp "$work/build/simutrans.js" "$work/build/simutrans.wasm" "$here/"

# The data zip.
stage=$work/data
rm -rf "$stage"
mkdir -p "$stage/text"
cd "$src/simutrans"
cp -r ai config font script themes "$stage/"
mkdir -p "$stage/music"
cp music/*.mid "$stage/music/"
cp copyright.txt license.txt license_squirrel.txt thanks.txt "$stage/"
cp text/translate_users.txt text/readme_citylist.txt "$stage/text/"
for l in $LANGS; do cp -r "text/$l.tab" "text/$l" "$stage/text/"; done
cd "$work"
find "$stage" -exec touch -d 2000-01-01T00:00:00Z {} +
mkdir -p "$work/r2/simutrans"
rm -f "$work/data.zip"
(cd "$stage" && find . -type f | LC_ALL=C sort | sed 's|^\./||' | TZ=UTC zip -q -X -9 -@ "$work/data.zip")
hash=$(sha256sum "$work/data.zip" | cut -c1-12)
mv "$work/data.zip" "$work/r2/simutrans/data-$hash.zip"
echo "data: $work/r2/simutrans/data-$hash.zip"

# pak64 as released.
curl -fsSL -o "$work/r2/simutrans/simupak64-125-0.zip" "$PAK64"
ls -l "$work/r2/simutrans"
