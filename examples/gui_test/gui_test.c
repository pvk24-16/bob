#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#include "glad/glad.h"

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

int label = -1;
int counter = 0;

EXPORT struct bob_api api;

static struct bob_visualization_info info = {
  .name = "GUI test",
  .description = "This visualization just demonstrates the different GUI elements that can be used with bob",
  .enabled = 0,
};

EXPORT const struct bob_visualization_info *get_info(void)
{
  return &info;
}

EXPORT const char *create(void)
{
  /* TODO: add more elements */
  label = api.register_label(api.context);
  return NULL;
}

EXPORT void update(void)
{
  counter++;
  api.set_label_content(api.context, label, "update was called %d times", counter);
}

EXPORT void destroy(void)
{
}
