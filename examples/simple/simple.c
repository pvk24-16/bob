#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#include "glad/glad.h"

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

int slider = -1;
int checkbox = -1;

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
  gladLoadGLLoader(bob_get_proc_address);
  slider = bob_register_float_slider("Floatiness", 0.0, 1.0, 0.5);
  checkbox = bob_register_checkbox("Enable booleans", 0);
  return NULL;
}

EXPORT void update(void *userdata)
{
  (void) userdata;
  float value = bob_get_ui_float_value(slider);
  glClearColor(value, value / 2.0f, 1.0f-value, 1.0f);
  glClear(GL_COLOR_BUFFER_BIT);
  if (bob_ui_element_is_updated(checkbox)) {
    const char *value = bob_get_ui_bool_value(checkbox) ? "enabled" : "disabled";
    printf("visualizer: booleans are %s\n", value);
  }
}

EXPORT void destroy(void *userdata)
{
  (void) userdata;
}
