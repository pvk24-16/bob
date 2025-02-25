#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#if defined(_WIN32)
#include <gl/gl.h>
#elif defined(__APPLE__)
#include <OpenGL/gl.h>
#else
#include <GL/gl.h>
#endif

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

int slider = -1;
int checkbox = -1;

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
  slider = api.register_float_slider(api.context, "Floatiness", 0.0, 1.0, 0.5);
  checkbox = api.register_checkbox(api.context, "Enable booleans", 0);
  return NULL;
}

EXPORT void update(void *userdata)
{
  (void) userdata;
  float value = api.get_ui_float_value(api.context, slider);
  glClearColor(value, value / 2.0f, 1.0f-value, 1.0f);
  if (api.ui_element_is_updated(api.context, checkbox)) {
    const char *value = api.get_ui_bool_value(api.context, checkbox) ? "enabled" : "disabled";
    printf("visualizer: booleans are %s\n", value);
  }
}

EXPORT void destroy(void *userdata)
{
  (void) userdata;
}
