#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

EXPORT struct bob_api api;

static struct bob_visualizer_info info = {
  .name = "Error",
  .description = "This visualizer just generates an error",
  .enabled = 0,
};

EXPORT const struct bob_visualizer_info *get_info(void)
{
  return &info;
}

EXPORT const char *create(void)
{
  return "An error occured. Please give up.";
}

EXPORT void update(void)
{
}

EXPORT void destroy(void)
{
}

