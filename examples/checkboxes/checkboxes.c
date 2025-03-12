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

EXPORT struct bob_api api;

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
  gladLoadGLLoader(api.get_proc_address);
  boxr = api.register_checkbox(api.context, "Red", 0);
  boxg = api.register_checkbox(api.context, "Green", 0);
  boxb = api.register_checkbox(api.context, "Blue", 0);
  return NULL;
}

EXPORT void update(void *userdata)
{
  (void) userdata;

  float r = api.get_ui_bool_value(api.context, boxr) ? 0.8f : 0.2f;
  float g = api.get_ui_bool_value(api.context, boxg) ? 0.8f : 0.2f;
  float b = api.get_ui_bool_value(api.context, boxb) ? 0.8f : 0.2f;

  glClearColor(r, g, b, 1.0f);
}

EXPORT void destroy(void *userdata)
{
  (void) userdata;
}

