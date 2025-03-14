#include "params.h"

#include <bob.h>

static float s_radius = .8f;
static int s_radius_handle = -1;
static float s_scale = .1f;
static int s_scale_handle = -1;
static int s_resolution = 128;
static int s_resolution_handle = -1;
static int s_resolution_changed = 0;

void register_params(void)
{
  s_radius_handle = api.register_float_slider(api.context, "Radius", .1f, 1.f, s_radius);
  s_scale_handle = api.register_float_slider(api.context, "Scale", .01f, .5f, s_scale);
  s_resolution_handle = api.register_int_slider(api.context, "Resolution", 16, 512, s_resolution);
}

void update_params(void)
{
  s_resolution_changed = 0;
  if (api.ui_element_is_updated(api.context, s_radius_handle))
    s_radius = api.get_ui_float_value(api.context, s_radius_handle);
  if (api.ui_element_is_updated(api.context, s_scale_handle))
    s_scale = api.get_ui_float_value(api.context, s_scale_handle);
  if (api.ui_element_is_updated(api.context, s_resolution_handle)) {
    s_resolution = api.get_ui_int_value(api.context, s_resolution_handle);
    s_resolution_changed = 1;
  }
}

float get_radius(void)
{
  return s_radius;
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
