#ifndef LATTICE_H
#define LATTICE_H

float *lattice(void);
float *lattice_point(int x, int y);
int lattice_w(void);
int lattice_h(void);
float lattice_x(int i);
float lattice_y(int j);
void lattice_set_size(int w, int h, int h_res);
void set_lattice_values(float *chroma);
void lattice_destroy(void);

#endif
