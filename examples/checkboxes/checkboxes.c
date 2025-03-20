#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#include "glad/glad.h"

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

static int boxr = -1, boxg = -1, boxb = -1;

static struct bob_visualization_info info = {
  .name = "Checkboxes",
  .description = "Let's you set background color using checkboxes.\n"
                 "This is stupid and only exists to test switching between visualizations.\n",
  .enabled = 0,
};

EXPORT const struct bob_visualization_info *get_info(void)
{
  return &info;
}

EXPORT void *create(void)
{
  gladLoadGLLoader(bob_get_proc_address);
  boxr = bob_register_checkbox("Red", 0);
  boxg = bob_register_checkbox("Green", 0);
  boxb = bob_register_checkbox("Blue", 0);
  return NULL;
}

EXPORT void update(void *userdata)
{
  (void) userdata;

  float r = bob_get_ui_bool_value(boxr) ? 0.8f : 0.2f;
  float g = bob_get_ui_bool_value(boxg) ? 0.8f : 0.2f;
  float b = bob_get_ui_bool_value(boxb) ? 0.8f : 0.2f;

  glClearColor(r, g, b, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
}

EXPORT void destroy(void *userdata)
{
  (void) userdata;
}
