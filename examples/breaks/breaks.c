#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#include "glad/glad.h"

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

static float r = 0.f, g = 0.f, b = 0.f;

EXPORT struct bob_api api;

static struct bob_visualization_info info = {
  .name = "Breaks example",
  .description = "Detects breaks in music and changes background color",
  .enabled = BOB_AUDIO_BREAKS_MONO,
};

EXPORT const struct bob_visualization_info *get_info(void)
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
  if (api.in_break(api.context, BOB_MONO_CHANNEL)) {
    r = (float) rand() / (float) RAND_MAX;
    g = (float) rand() / (float) RAND_MAX;
    b = (float) rand() / (float) RAND_MAX;
  }

  glClearColor(r, g, b, 1.f);
  glClear(GL_COLOR_BUFFER_BIT);
}

EXPORT void destroy(void)
{
}

