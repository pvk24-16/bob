#include "params.h"

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

void register_params(void)
{
  s_smooth_handle = bob_register_checkbox("Smooth", 0);
  s_radius_handle = bob_register_float_slider("Radius", .1f, 1.f, s_radius);
  s_scale_handle = bob_register_float_slider("Scale", .01f, 1.5f, s_scale);
  s_resolution_handle = bob_register_int_slider("Resolution", 16, 512, s_resolution);
  s_bg_color_handle = bob_register_colorpicker("Background", &s_bg_color);
  s_border_color_handle = bob_register_colorpicker("Border", &s_border_color);
  s_center_color_handle = bob_register_colorpicker("Center", &s_center_color);
}

void update_params(void)
{
  s_resolution_changed = 0;
  if (bob_ui_element_is_updated(s_radius_handle))
    s_radius = bob_get_ui_float_value(s_radius_handle);
  if (bob_ui_element_is_updated(s_smooth_handle))
    s_smooth = bob_get_ui_bool_value(s_smooth_handle);
  if (bob_ui_element_is_updated(s_scale_handle))
    s_scale = bob_get_ui_float_value(s_scale_handle);
  if (bob_ui_element_is_updated(s_resolution_handle)) {
    s_resolution = bob_get_ui_int_value(s_resolution_handle);
    s_resolution_changed = 1;
  }
  if (bob_ui_element_is_updated(s_bg_color_handle))
    bob_get_ui_colorpicker_value(s_bg_color_handle, s_bg_color);
  if (bob_ui_element_is_updated(s_border_color_handle))
    bob_get_ui_colorpicker_value(s_border_color_handle, s_border_color);
  if (bob_ui_element_is_updated(s_center_color_handle))
    bob_get_ui_colorpicker_value(s_center_color_handle, s_center_color);
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
