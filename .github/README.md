# Simutrans in the browser

This fork is the web build of [Simutrans](https://github.com/simutrans/simutrans) that runs on wasmga.me. Play it at **https://wasmga.me/games/simutrans**.

It is Simutrans 125.0.1 with its SDL2 backend, built with Emscripten for single player with pak64: Quit, Play Online, Install (the pakset downloader) and "Start this as a server" are left out, and the page owns full screen. The songs play through FluidSynth with the TimGM6mb sound font. The game can also save and load the game in progress on request (`wg_request_snapshot()` and `wg_restore()`), which the page uses to resume a game.

## What's here

- Branch `wasmgame` (this one) is upstream commit [`40bbb12`](https://github.com/simutrans/simutrans/commit/40bbb12894793cc7c6ae5c93f31a16e7e7707627) (125.0.1) with our changes on top as commits, so `git log` and the diff against `40bbb12` show everything we changed.
- [`wasmgame/`](../wasmgame) holds the build script and the same changes as `simutrans.diff` against that commit. `build.sh` starts from a fresh upstream checkout, applies it and builds, and its header comment lists each change.

## Building

Needs git, make, cmake, ninja, zip, curl and emsdk 4.0.7 (source `emsdk_env.sh` first).

```sh
sh wasmgame/build.sh /tmp/simutrans-build
```

It builds FluidSynth 2.5.7 as a static library, then the game with the Makefile, and writes `simutrans.js` and `simutrans.wasm` next to the script. Under `<work dir>/r2/simutrans/` go the game's data zip (settings, fonts, themes, scripts, the AI, the songs and six languages) and pak64 as released.

## Running it

The page runs `main()` itself (`INVOKE_RUN=0`) with `-set_basedir /simutrans -objects pak -screensize <width>x<height>`, plus `-lang <code>` on a first visit, after writing the data zip and pak64 to `/simutrans`, the sound font to `/simutrans/music/TimGM6mb.sf2` and the player's files to `/home/web_user/simutrans`. `wg_resize(w, h)` follows the page's size, `wg_hold(on)` stands the game still, `wg_save_files()` writes the settings, and for a snapshot `wg_request_snapshot()` writes `/wg/snapshot.sve` between two steps (`wg_snapshot_count()` goes up when it's done); `wg_restore()` loads `/wg/restore.sve`.

## Licence

Same as upstream: Artistic License 1.0 (see `simutrans/license.txt`). FluidSynth is LGPL-2.1-or-later, pak64 is under the Artistic License 1.0 too, TimGM6mb GPL-2.0. Our changes are under the same licence as the files they change.
