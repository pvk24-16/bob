#include "chroma.h"
#include "params.h"

#include <bob.h>
#include <math.h>

static float s_target_chroma[12];
static float s_chroma[12] = {0};

void update_chroma(void)
{
  const float snap = .001f;
  const float threshold = .8f;

  bob_get_chromagram(s_target_chroma, BOB_MONO_CHANNEL);

  for (size_t i = 0; i < 12; ++i) {
    const float v = s_target_chroma[i];
    const float target = v > threshold ? powf(v, 6.f) : .02f;
    const float diff = target - s_chroma[i];
    const float speed = .05f;
    s_chroma[i] = -snap < diff && diff < snap ? target : s_chroma[i] + speed * diff;
  }
}

float *get_chroma(void)
{
  return s_chroma;
}

