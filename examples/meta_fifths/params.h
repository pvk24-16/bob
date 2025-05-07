#ifndef PARAMS_H
#define PARAMS_H

void register_params(void);
void update_params(void);
float get_radius(void);
float get_scale(void);
float *get_bg_color(void);
float *get_border_color(void);
float *get_center_color(void);
int get_smooth(void);
int get_resolution(void);
int resolution_changed(void);

#endif
