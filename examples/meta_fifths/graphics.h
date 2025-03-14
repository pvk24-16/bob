#ifndef GRAPHICS_H
#define GRAPHICS_H

#include "buffer.h"

void graphics_init(void);
void graphics_deinit(void);
void draw_buffer(struct buffer *b);

#endif
