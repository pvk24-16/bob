#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#include "glad/glad.h"

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

static float rgb[3] = {0.2, 0.2, 0.2};
static int handle;

static struct bob_visualization_info info = {
  .name = "Colorpicker Demo",
  .description = "Just another example, this time with a color picker",
  .enabled = 0,
};

EXPORT const struct bob_visualization_info *get_info(void)
{
  return &info;
}

EXPORT void *create(void)
{
  gladLoadGLLoader(bob_get_proc_address);
  handle = bob_register_colorpicker("Pick a nice color", rgb);
  return NULL;
}

EXPORT void update(void *userdata)
{
  (void) userdata;
  if (bob_ui_element_is_updated(handle))
    bob_get_ui_colorpicker_value(handle, rgb);
  glClearColor(rgb[0], rgb[1], rgb[2], 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
}

EXPORT void destroy(void *userdata)
{
  (void) userdata;
}
