/*
    Sabre Fighter Plane Simulator
    Copyright (C) 1997	Dan Hammer

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 1, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/
/*************************************************
 * Sabre Fighter Plane Simulator                 *
 * File   : simsnd.C                             *
 * Date   : December, 1998                       *
 * Author : Dan Hammer                           *
 * SDL_mixer backend added 2026                  *
 *************************************************/
#include <stdio.h>
#include <string.h>
#include "sim.h"
#include "simerr.h"
#include "simfile.h"
#include "simsnd.h"

#ifdef HAVE_LIBSDL
#ifdef HAVE_SDL2
#include <SDL2/SDL.h>
#include <SDL2/SDL_mixer.h>
#else
#include "SDL.h"
#include "SDL_mixer.h"
#endif

#define MAX_SOUND_IDS 256
#define MAX_SOUND_ID_LEN 32
#define MIX_CHANNELS 32

typedef struct {
  char id[MAX_SOUND_ID_LEN + 1];
  Mix_Chunk *chunk;
  int channel;
  int playing;
  int looping;
} sdl_sound;

static sdl_sound sounds[MAX_SOUND_IDS];
static int sound_count = 0;

static sdl_sound *find_sound(const char *id)
{
  for (int i = 0; i < sound_count; i++)
    if (!strcmp(sounds[i].id, id))
      return &sounds[i];
  return NULL;
}

static void channel_finished(int ch)
{
  for (int i = 0; i < sound_count; i++)
    if (sounds[i].channel == ch) {
      sounds[i].playing = 0;
      sounds[i].channel = -1;
      break;
    }
}
#endif

static const char *enumSounds[4] = {
  "JET_ENGINE",
  "GUN",
  "CRASH",
  "CANNON"
};

static const char *soundErr2String(int err);

static R_3DPoint soundViewPoint;
static int soundLock = 0;
static int soundActive = 1;
static int soundAffiliation = 0;
static int masterVolume = 50;

int sound_avail = 0;

int sound_init(__attribute__((unused)) long param)
{
#ifdef HAVE_LIBSDL
  if (SDL_InitSubSystem(SDL_INIT_AUDIO) < 0) {
    fprintf(stderr, "SDL audio init failed: %s\n", SDL_GetError());
    sound_avail = 0;
    return SOUND_ERROR_INIT;
  }
  if (Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 2048) < 0) {
    fprintf(stderr, "Mix_OpenAudio failed: %s\n", Mix_GetError());
    sound_avail = 0;
    return SOUND_ERROR_INIT;
  }
  Mix_AllocateChannels(MIX_CHANNELS);
  Mix_ChannelFinished(channel_finished);
  Mix_Volume(-1, (masterVolume * MIX_MAX_VOLUME) / 100);
  sound_count = 0;
  for (int i = 0; i < MAX_SOUND_IDS; i++) {
    sounds[i].id[0] = 0;
    sounds[i].chunk = NULL;
    sounds[i].channel = -1;
    sounds[i].playing = 0;
    sounds[i].looping = 0;
  }
  sound_avail = 1;
  printf("Sound initialized (SDL_mixer)\n");
  return SOUND_OK;
#else
  sound_avail = 0;
  return SOUND_NOT_LOADED;
#endif
}

void sound_destroy(void)
{
#ifdef HAVE_LIBSDL
  if (!sound_avail) return;
  Mix_HaltChannel(-1);
  for (int i = 0; i < sound_count; i++)
    if (sounds[i].chunk)
      Mix_FreeChunk(sounds[i].chunk);
  sound_count = 0;
  Mix_CloseAudio();
  printf("Sound destroyed\n");
#endif
}

int sound_load_wav(__attribute__((unused)) const char *path,
                   __attribute__((unused)) const char *id)
{
#ifdef HAVE_LIBSDL
  if (!sound_avail) return SOUND_NOT_LOADED;
  if (sound_count >= MAX_SOUND_IDS) return SOUND_FULL;

  Mix_Chunk *chunk = Mix_LoadWAV(path);
  if (!chunk) {
    fprintf(stderr, "Could not load %s: %s\n", path, Mix_GetError());
    return WAV_PATH_NOT_FOUND;
  }

  sdl_sound *s = &sounds[sound_count];
  strncpy(s->id, id, MAX_SOUND_ID_LEN);
  s->id[MAX_SOUND_ID_LEN] = 0;
  s->chunk = chunk;
  s->channel = -1;
  s->playing = 0;
  s->looping = 0;
  sound_count++;
  sim_printf("Loaded sound id \"%s\" from %s\n", id, path);
  return SOUND_OK;
#else
  return SOUND_NOT_LOADED;
#endif
}

int sound_on(__attribute__((unused)) const char *id,
             __attribute__((unused)) int mode,
             __attribute__((unused)) int vol)
{
  if (soundLock || !soundActive) return SOUND_OK;
#ifdef HAVE_LIBSDL
  if (!sound_avail) return SOUND_NOT_LOADED;
  sdl_sound *s = find_sound(id);
  if (!s) return SOUND_NOT_FOUND;

  if (mode == LOOP && s->looping) return SOUND_OK;

  int loops = (mode == LOOP) ? -1 : 0;
  int ch = Mix_PlayChannel(-1, s->chunk, loops);
  if (ch < 0) return SOUND_ERROR_PLAY;

  if (vol >= 0) {
    int mixvol = (vol * MIX_MAX_VOLUME) / 100;
    Mix_Volume(ch, mixvol);
  }

  s->channel = ch;
  s->playing = 1;
  s->looping = (mode == LOOP) ? 1 : 0;
  return SOUND_OK;
#else
  return SOUND_NOT_LOADED;
#endif
}

int sound_on(int idx, int mode, int vol)
{
  if (soundLock) return SOUND_OK;
  if (idx >= 0 && idx <= 3)
    return sound_on(enumSounds[idx], mode, vol);
  return SOUND_NOT_FOUND;
}

int sound_off(__attribute__((unused)) const char *id)
{
#ifdef HAVE_LIBSDL
  if (!sound_avail) return SOUND_NOT_LOADED;
  sdl_sound *s = find_sound(id);
  if (!s) return SOUND_NOT_FOUND;
  if (s->channel >= 0) {
    Mix_HaltChannel(s->channel);
    s->playing = 0;
    s->looping = 0;
    s->channel = -1;
  }
  return SOUND_OK;
#else
  return SOUND_NOT_LOADED;
#endif
}

int sound_off(int idx)
{
  if (idx >= 0 && idx <= 3)
    return sound_off(enumSounds[idx]);
  return SOUND_NOT_FOUND;
}

int sound_off_all(void)
{
#ifdef HAVE_LIBSDL
  if (!sound_avail) return SOUND_NOT_LOADED;
  Mix_HaltChannel(-1);
  for (int i = 0; i < sound_count; i++) {
    sounds[i].playing = 0;
    sounds[i].looping = 0;
    sounds[i].channel = -1;
  }
  return SOUND_OK;
#else
  return SOUND_NOT_LOADED;
#endif
}

int sound_vol(__attribute__((unused)) const char *id,
              __attribute__((unused)) int vol)
{
#ifdef HAVE_LIBSDL
  if (!sound_avail) return SOUND_NOT_LOADED;
  sdl_sound *s = find_sound(id);
  if (!s) return SOUND_NOT_FOUND;
  if (s->channel >= 0) {
    int mixvol = (vol * MIX_MAX_VOLUME) / 100;
    Mix_Volume(s->channel, mixvol);
  }
  return SOUND_OK;
#else
  return SOUND_NOT_LOADED;
#endif
}

int sound_freq(__attribute__((unused)) const char *id,
               __attribute__((unused)) int freq)
{
#ifdef HAVE_LIBSDL
  return SOUND_OK;
#else
  return SOUND_NOT_LOADED;
#endif
}

int sound_pan(__attribute__((unused)) const char *id,
              __attribute__((unused)) int pan)
{
#ifdef HAVE_LIBSDL
  if (!sound_avail) return SOUND_NOT_LOADED;
  sdl_sound *s = find_sound(id);
  if (!s) return SOUND_NOT_FOUND;
  if (s->channel >= 0) {
    Uint8 left, right;
    if (pan < 0) { left = 255; right = static_cast<Uint8>(255 + pan * 255 / 100); }
    else if (pan > 0) { right = 255; left = static_cast<Uint8>(255 - pan * 255 / 100); }
    else { left = 255; right = 255; }
    Mix_SetPanning(s->channel, left, right);
  }
  return SOUND_OK;
#else
  return SOUND_NOT_LOADED;
#endif
}

int sound_free(__attribute__((unused)) const char *id)
{
#ifdef HAVE_LIBSDL
  if (!sound_avail) return SOUND_NOT_LOADED;
  sdl_sound *s = find_sound(id);
  if (!s) return SOUND_NOT_FOUND;
  if (s->channel >= 0) Mix_HaltChannel(s->channel);
  if (s->chunk) Mix_FreeChunk(s->chunk);
  s->chunk = NULL;
  s->channel = -1;
  s->playing = 0;
  s->looping = 0;
  return SOUND_OK;
#else
  return SOUND_NOT_LOADED;
#endif
}

int sound_free_all(void)
{
#ifdef HAVE_LIBSDL
  Mix_HaltChannel(-1);
  for (int i = 0; i < sound_count; i++) {
    if (sounds[i].chunk) Mix_FreeChunk(sounds[i].chunk);
    sounds[i].chunk = NULL;
    sounds[i].channel = -1;
    sounds[i].playing = 0;
  }
  return SOUND_OK;
#else
  return SOUND_NOT_LOADED;
#endif
}

unsigned int sound_status(__attribute__((unused)) const char *id)
{
#ifdef HAVE_LIBSDL
  if (!sound_avail) return SOUND_NOT_LOADED;
  sdl_sound *s = find_sound(id);
  if (!s) return SOUND_NOT_FOUND;
  unsigned int flags = 0;
  if (s->playing) flags |= SND_STATUS_PLAYING;
  if (s->looping) flags |= SND_STATUS_LOOPING;
  return flags;
#else
  return 0;
#endif
}

void sound_set_viewpoint(const R_3DPoint &p)
{
  soundViewPoint = p;
}

int sound_calc_distant_vol(const R_3DPoint &origin, REAL_TYPE maxDistSq)
{
  int result = 0;
  REAL_TYPE distSq = distance_squared(origin, soundViewPoint);
  distSq *= world_scale;
  if (distSq < maxDistSq) {
    REAL_TYPE f = distSq / maxDistSq;
    result = static_cast<int>(100 - (100.0 * f));
  }
  return result;
}

void sound_set_lock(int lock)
{
  soundLock = lock;
}

void sound_set_active(int active)
{
  if (!active && soundActive) sound_off_all();
  soundActive = active;
}

int sound_get_active(void)
{
  return (sound_avail && soundActive);
}

void sound_toggle_active(void)
{
  soundActive = !soundActive;
  if (!soundActive) sound_off_all();
}

void sound_set_affiliation(int affiliation)
{
  soundAffiliation = affiliation;
}

int sound_get_affiliation(void)
{
  return soundAffiliation;
}

int sound_error_check(int err)
{
  if (err != SOUND_OK) {
    if (err != SOUND_NOT_FOUND)
      sim_printf("sound error: %s\n", soundErr2String(err));
  }
  return err;
}

const char *soundErr2String(int err)
{
  switch (err) {
  case SOUND_OK:           return "SOUND_OK";
  case SOUND_FULL:         return "SOUND_FULL";
  case SOUND_ERROR_INIT:   return "SOUND_ERROR_INIT";
  case SOUND_ERROR_CREATE: return "SOUND_ERROR_CREATE";
  case SOUND_ERROR_LOCK:   return "SOUND_ERROR_LOCK";
  case SOUND_ERROR_UNLOCK: return "SOUND_ERROR_UNLOCK";
  case SOUND_NOT_FOUND:    return "SOUND_NOT_FOUND";
  case SOUND_NOT_LOADED:   return "SOUND_NOT_LOADED";
  case SOUND_ERROR_SETPOS: return "SOUND_ERROR_SETPOS";
  case SOUND_ERROR_PLAY:   return "SOUND_ERROR_PLAY";
  case SOUND_ERROR_VOL:    return "SOUND_ERROR_VOL";
  case SOUND_ERROR_FREQ:   return "SOUND_ERROR_FREQ";
  case SOUND_ERROR_PAN:    return "SOUND_ERROR_PAN";
  case WAV_PATH_NOT_FOUND: return "WAV_PATH_NOT_FOUND";
  case WAV_NO_SECTION:     return "WAV_NO_SECTION";
  case WAV_NO_FORMAT:      return "WAV_NO_FORMAT";
  case WAV_NO_DATA:        return "WAV_NO_DATA";
  case WAV_BAD_FORMAT:     return "WAV_BAD_FORMAT";
  case WAV_CANT_ASCEND:    return "WAV_CANT_ASCEND";
  case WAV_NO_DATA_CHUNK:  return "WAV_NO_DATA_CHUNK";
  }
  return "unknown";
}

void sound_set_master_volume(int percent)
{
  if (percent < 0) percent = 0;
  if (percent > 100) percent = 100;
  masterVolume = percent;
#ifdef HAVE_LIBSDL
  if (sound_avail)
    Mix_Volume(-1, (masterVolume * MIX_MAX_VOLUME) / 100);
#endif
}

int sound_get_master_volume(void)
{
  return masterVolume;
}
