#include "params.h"

#include <stdlib.h>
#include <bob.h>

static float s_radius = .8f;
static int s_radius_handle = -1;
static int s_smooth = 0;
static int s_smooth_handle = -1;
static float s_scale = .1f;
static int s_scale_handle = -1;
static int s_resolution = 128;
static int s_resolution_handle = -1;
static int s_resolution_changed = 0;
static int s_bg_color_handle = -1;
static float s_bg_color[3] = { .0f, .0f, .0f, };
static int s_border_color_handle = -1;
static float s_border_color[3] = { 1.f, .0f, .0f, };
static int s_center_color_handle = -1;
static float s_center_color[3] = { .2f, 0.f, 0.f, };
static int s_randomize_handle = -1;
static int s_randomize = 0;

void register_params(void)
{
  s_smooth_handle = api.register_checkbox(api.context, "Smooth", 0);
  s_randomize_handle = api.register_checkbox(api.context, "Randomize colors on song change", 0);
  s_radius_handle = api.register_float_slider(api.context, "Radius", .1f, 1.f, s_radius);
  s_scale_handle = api.register_float_slider(api.context, "Scale", .01f, 1.5f, s_scale);
  s_resolution_handle = api.register_int_slider(api.context, "Resolution", 16, 512, s_resolution);
  s_bg_color_handle = api.register_colorpicker(api.context, "Background", &s_bg_color);
  s_border_color_handle = api.register_colorpicker(api.context, "Border", &s_border_color);
  s_center_color_handle = api.register_colorpicker(api.context, "Center", &s_center_color);
}

static void randomize_colors(void)
{
  s_bg_color[0] = (float) rand() / (float) RAND_MAX;
  s_bg_color[1] = (float) rand() / (float) RAND_MAX;
  s_bg_color[2] = (float) rand() / (float) RAND_MAX;
  s_border_color[0] = (float) rand() / (float) RAND_MAX;
  s_border_color[1] = (float) rand() / (float) RAND_MAX;
  s_border_color[2] = (float) rand() / (float) RAND_MAX;
  s_center_color[0] = (float) rand() / (float) RAND_MAX;
  s_center_color[1] = (float) rand() / (float) RAND_MAX;
  s_center_color[2] = (float) rand() / (float) RAND_MAX;
}

void update_params(void)
{
  s_resolution_changed = 0;
  if (api.ui_element_is_updated(api.context, s_radius_handle))
    s_radius = api.get_ui_float_value(api.context, s_radius_handle);
  if (api.ui_element_is_updated(api.context, s_smooth_handle))
    s_smooth = api.get_ui_bool_value(api.context, s_smooth_handle);
  if (api.ui_element_is_updated(api.context, s_scale_handle))
    s_scale = api.get_ui_float_value(api.context, s_scale_handle);
  if (api.ui_element_is_updated(api.context, s_resolution_handle)) {
    s_resolution = api.get_ui_int_value(api.context, s_resolution_handle);
    s_resolution_changed = 1;
  }
  if (api.ui_element_is_updated(api.context, s_bg_color_handle))
    api.get_ui_colorpicker_value(api.context, s_bg_color_handle, s_bg_color);
  if (api.ui_element_is_updated(api.context, s_border_color_handle))
    api.get_ui_colorpicker_value(api.context, s_border_color_handle, s_border_color);
  if (api.ui_element_is_updated(api.context, s_center_color_handle))
    api.get_ui_colorpicker_value(api.context, s_center_color_handle, s_center_color);
  if (api.get_ui_bool_value(api.context, s_randomize_handle) &&
      api.in_break(api.context, BOB_MONO_CHANNEL))
    randomize_colors();
}

float get_radius(void)
{
  return s_radius;
}

float *get_bg_color(void)
{
  return s_bg_color;
}

float *get_border_color(void)
{
  return s_border_color;
}

float *get_center_color(void)
{
  return s_center_color;
}

int get_smooth(void)
{
  return s_smooth;
}

float get_scale(void)
{
  return s_scale;
}

int get_resolution(void)
{
  return s_resolution;
}

int resolution_changed(void)
{
  return s_resolution_changed;
}
