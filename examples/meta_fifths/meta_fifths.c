#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#include <glad/glad.h>

#include "params.h"
#include "lattice.h"
#include "buffer.h"
#include "graphics.h"
#include "marching.h"
#include "chroma.h"

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

static struct buffer s_buffer = {0};

EXPORT struct bob_api api;

static struct bob_visualizer_info info = {
  .name = "Meta fifths",
  .description =
    "A circle of fifths made from metaballs.",
  .enabled = BOB_AUDIO_CHROMAGRAM_MONO | BOB_AUDIO_BREAKS_MONO,
};

EXPORT const struct bob_visualizer_info *get_info(void)
{
  return &info;
}

EXPORT const char *create(void)
{
  register_params();

  graphics_init();

  int w, h;
  (void) api.get_window_size(api.context, &w, &h);
  glViewport(0, 0, w, h);
  lattice_set_size(w, h, get_resolution());

  return NULL;
}

EXPORT void update(void)
{
  int w, h;
  if (api.get_window_size(api.context, &w, &h) || resolution_changed()) {
    glViewport(0, 0, w, h);
    lattice_set_size(w, h, get_resolution());
  }

  update_params();
  update_chroma();

  set_lattice_values(get_chroma());

  marching_squares(&s_buffer);

  draw_buffer(&s_buffer);
}

EXPORT void destroy(void)
{
  buf_free(&s_buffer);
  graphics_deinit();
  lattice_destroy();
}
