#include "lattice.h"
#include "params.h"

#include <assert.h>
#include <stdlib.h>
#include <math.h>
#include <stdio.h>

static float *s_lattice = NULL;
static int s_width = 0, s_height = 0;

float *lattice(void)
{
  assert(s_lattice);
  return s_lattice;
}

float *lattice_point(int x, int y)
{
  return &s_lattice[x + s_width * y];
}

int lattice_w(void)
{
  assert(s_lattice);
  return s_width;
}

int lattice_h(void)
{
  assert(s_lattice);
  return s_height;
}

float lattice_x(int i)
{
  return 2.f * ((float) i / (float) (s_width - 1)) - 1.f;
}

float lattice_y(int j)
{
  return 2.f * ((float) j / (float) (s_height - 1)) - 1.f;
}

void lattice_set_size(int w, int h, int h_res)
{
  s_width = h_res;
  s_height = h_res * h / w;
  s_lattice = realloc(s_lattice, s_width * s_height * sizeof (*s_lattice));
}

static void precompute_trigs(float *coss, float *sins)
{
  static int done = 0;
  if (done)
    return;

  for (int i = 0; i < 12; ++i) {
    float a = 2.f * M_PI * (float) i * 7.f / 12.f;
    coss[i] = cosf(a);
    sins[i] = sinf(a);
  }

  done = 1;
}

void set_lattice_values(float *chroma)
{
  const float r = get_radius();
  const float s = get_scale();

  const float min = s_width < s_height ? s_width : s_height;
  const float sx = (float) s_width / min;
  const float sy = (float) s_height / min;

  static float coss[12], sins[12];
  precompute_trigs(coss, sins);

  for (int li = 0; li < s_width; ++li) {
    for (int lj = 0; lj < s_height; ++lj) {

      const float lx = sx * lattice_x(li);
      const float ly = sy * lattice_y(lj);

      float v = 0.f;

      for (int ci = 0; ci < 12; ++ci) {

        const float cv = s * chroma[ci];

        const float cx = r * coss[ci];
        const float cy = r * sins[ci];

        const float dx = lx - cx;
        const float dy = ly - cy;
        const float d = dx * dx + dy * dy;

        v += cv * cv / d;
      }

      s_lattice[li + s_width * lj] = v - 1.f;
    }
  }
}

void lattice_destroy(void)
{
  free(s_lattice);
  s_lattice = NULL;
}
