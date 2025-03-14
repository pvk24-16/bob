#include "buffer.h"

#include <malloc.h>
#include <string.h>
#include <stdarg.h>

struct buffer buf_init(void)
{
  return (struct buffer) {0};
}

void buf_append(struct buffer *b, float v)
{
  const size_t init_capacity = 256;

  if (b->data == NULL) {
    b->data = malloc(sizeof(*b->data) * init_capacity);
    b->capacity = init_capacity;
  }

  if (b->size == b->capacity) {
    b->capacity *= 2;
    b->data = realloc(b->data, sizeof(*b->data) * b->capacity);
  }

  b->data[b->size++] = v;
}

void buf_appendv(struct buffer *b, int n, ...)
{
  va_list ap;
  va_start(ap, n);
  while (n--) {
    float f = va_arg(ap, double);
    buf_append(b, f);
  }
  va_end(ap);
}

void buf_clear(struct buffer *b)
{
  b->size = 0;
}

void buf_free(struct buffer *b)
{
  free(b->data);
  memset(b, 0, sizeof(*b));
}
