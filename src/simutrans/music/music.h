/*
 * This file is part of the Simutrans project under the Artistic License.
 * (see LICENSE.txt)
 *
 * Changed by wasmga.me in October 2026 for the web build: declares dr_render_midi().
 * See wasmgame/simutrans.diff and https://github.com/wasmga-me/simutrans-wasm/tree/wasmgame
 */

#ifndef MUSIC_MUSIC_H
#define MUSIC_MUSIC_H


#include "../simtypes.h"


#define MAX_MIDI (128)

/**
 * MIDI initialisation routine
 * false: leave midi alone
 */
bool dr_init_midi();


/**
 * sets midi playback volume
 * @param vol volume in range 0..255
 */
void dr_set_midi_volume(int vol);


/**
 * Loads a MIDI file
 */
int dr_load_midi(const char* filename);


/**
 * Plays a MIDI file
 */
void dr_play_midi(int key);


/**
 * Stops playing MIDI file
 */
void dr_stop_midi();


/**
 * @return -1 if current track has finished, 0 otherwise.
 */
sint32 dr_midi_pos();


/**
 * Stops playing and forgets all loaded MIDI files, so another list can be
 * loaded. The routine itself stays initialised.
 */
void dr_clear_midi();


/**
 * @return the file extensions this routine can play, each with its dot and
 * followed by a space, e.g. ".mid .midi "
 */
const char *dr_get_midi_extensions();


/**
 * Midi shutdown/cleanup
 */
void dr_destroy_midi();


/**
 * Load a soundfont. Only available if we are using FluidSynth.
 */
#ifdef USE_FLUIDSYNTH_MIDI
bool dr_load_sf(const char * filename);
#endif

#if defined(USE_FLUIDSYNTH_MIDI) && defined(__EMSCRIPTEN__)
/**
 * The web build has no audio driver for FluidSynth: the sound routine asks
 * for the music, as interleaved stereo at its own sample rate.
 * @return false if there is none to mix in
 */
bool dr_render_midi(sint16 *stereo, int frames);
#endif

#endif
