#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

EXPORT struct bob_api api;

static struct bob_visualizer_info info = {
  .name = "Performance testing",
  .description = "This is a crazy visualizer that activates all analysis",
  .enabled =
    BOB_AUDIO_TIME_DOMAIN_MONO |
    BOB_AUDIO_TIME_DOMAIN_STEREO |
    BOB_AUDIO_FREQUENCY_DOMAIN_MONO |
    BOB_AUDIO_FREQUENCY_DOMAIN_STEREO |
    BOB_AUDIO_CHROMAGRAM_MONO |
    BOB_AUDIO_CHROMAGRAM_STEREO |
    BOB_AUDIO_PULSE_MONO |
    BOB_AUDIO_PULSE_STEREO |
    BOB_AUDIO_TEMPO_MONO |
    BOB_AUDIO_TEMPO_STEREO |
    BOB_AUDIO_BREAKS_MONO |
    BOB_AUDIO_BREAKS_STEREO,
};

EXPORT const struct bob_visualizer_info *get_info(void)
{
  return &info;
}

EXPORT const char *create(void)
{
  return NULL;
}

EXPORT void update(void)
{
}

EXPORT void destroy(void)
{
}
