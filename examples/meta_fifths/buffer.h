#ifndef BUFFER_H
#define BUFFER_H

#include <stddef.h>

struct buffer {
  size_t capacity;
  size_t size;
  float *data;
};

struct buffer buf_init(void);
void buf_append(struct buffer *b, float v);
void buf_appendv(struct buffer *b, int n, ...);
void buf_clear(struct buffer *b);
void buf_free(struct buffer *b);

#endif
