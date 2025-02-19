#include <stdlib.h>
#include <bob.h>

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

EXPORT struct bob_api api;

static struct bob_visualization_info info = {
  .name = "Simple example",
  .description = "This is a description that is not very useful",
  .enabled = BOB_AUDIO_CHROMAGRAM_STEREO | BOB_AUDIO_TEMPO_MONO,
};

EXPORT const struct bob_visualization_info *get_info(void)
{
  return &info;
}

EXPORT void *create(void)
{
  return NULL;
}

EXPORT void update(void *userdata)
{
  (void) userdata;
}

EXPORT void destroy(void *userdata)
{
  (void) userdata;
}
