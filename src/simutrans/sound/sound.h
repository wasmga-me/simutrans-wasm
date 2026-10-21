/*
 * This file is part of the Simutrans project under the Artistic License.
 * (see LICENSE.txt)
 *
 * Changed by wasmga.me in October 2026 for the web build: declares dr_get_sample_rate().
 * See wasmgame/simutrans.diff and https://github.com/wasmga-me/simutrans-wasm/tree/wasmgame
 */

#ifndef SOUND_SOUND_H
#define SOUND_SOUND_H


/**
 * Sound initialisation routine
 */
bool dr_init_sound();

/**
 * loads a sample
 *
 * @param filename
 * @return a handle for that sample or -1 on failure
 */
int dr_load_sample(const char* filename);

/**
 * plays a sample
 * 
 * @param key the handle for the sample to be played
 * @param volume
 */
void dr_play_sample(int key, int volume);

#ifdef __EMSCRIPTEN__
/// the sample rate the sound routine plays at, for the music it mixes in
int dr_get_sample_rate();
#endif

#endif
