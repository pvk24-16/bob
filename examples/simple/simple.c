#include <stdlib.h>
#include <bob.h>

struct bob_api api;

struct bob_visualization_info info;

const struct bob_visualization_info *get_info(void)
{
  info.name = "Simple example";
  info.description = "This is a description that is not very useful";
  info.enabled = BOB_AUDIO_CHROMAGRAM_STEREO | BOB_AUDIO_TEMPO_MONO;
  return &info;
}

void *create(void)
{
  return NULL;
}

void update(void *userdata)
{
  (void) userdata;
}

void destroy(void *userdata)
{
  (void) userdata;
}
