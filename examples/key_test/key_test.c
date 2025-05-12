#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#include "glad/glad.h"

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

EXPORT struct bob_api api;

static struct bob_visualizer_info info = {
  .name = "Key detection test",
  .description = "Check the terminal",
  .enabled = BOB_AUDIO_KEY_MONO,
};

EXPORT const struct bob_visualizer_info *get_info(void)
{
  return &info;
}

EXPORT const char *create(void)
{
  gladLoadGLLoader(api.get_proc_address);
  return NULL;
}

EXPORT void update(void)
{
  glClearColor(.1f, .1f, .1f, 1.f);
  glClear(GL_COLOR_BUFFER_BIT);

  struct bob_key key = api.get_key(api.context, BOB_MONO_CHANNEL);

  static const char *pitch_strs[] = {
      "C", "C#/Db", "D", "D#/Eb",
      "E", "F", "F#/Gb", "G",
      "G#/Ab", "A", "A#/Bb", "B",
  };

  static const char *type_strs[] = {
      [BOB_KEY_MAJOR] = "major",
      [BOB_KEY_MINOR] = "minor",
  };

  const char *pitch_str = pitch_strs[key.pitch_class];
  const char *type_str = type_strs[key.type];

  printf("\x1b[2K\x1b[0G%s\t%s\t%f", pitch_str, type_str, key.confidence);
  fflush(stdout);
}

EXPORT void destroy(void)
{
}

