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
  .name = "CWD",
  .description = "This visualizer just checks that the working directory "
                 "is set correctly.",
  .enabled = 0,
};

EXPORT const struct bob_visualizer_info *get_info(void)
{
  return &info;
}

EXPORT const char *create(void)
{
  FILE *f = fopen("banana.txt", "r");

  if (f == NULL)
    return "banana.txt could not be found";

  fclose(f);

  return NULL;
}

EXPORT void update(void)
{
}

EXPORT void destroy(void)
{
}

