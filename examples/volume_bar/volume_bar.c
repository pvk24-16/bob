#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#include "glad/glad.h"

#define ABS(x) ((x) > 0.f ? (x) : -(x))

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

static const char *vertex_source =
  "#version 330 core\n"
  "in vec2 v_pos;\n"
  "out vec2 f_pos;\n"
  "\n"
  "void main() {\n"
  "  f_pos = v_pos;\n"
  "  gl_Position = vec4(v_pos, 0.0, 1.0);\n"
  "}\n";

static const char *fragment_source =
  "#version 330 core\n"
  "in vec2 f_pos;\n"
  "out vec4 f_col;\n"
  "\n"
  "void main() {\n"
  "  f_col = vec4((f_pos.y + 1.0) / 2.0, (2.0 - f_pos.y) / 2.0, 0.0, 1.0);\n"
  "}\n";

EXPORT struct bob_api api;

static int scale_handle;
static float volume = 0;
static GLuint vbo;
static GLuint vao;
static GLuint program;
static float vertex_data[] = {
   1.f,  1.f,
   1.f, -1.f,
  -1.f, -1.f,

  -1.f, -1.f,
  -1.f,  1.f,
   1.f,  1.f,
}; 

static struct bob_visualization_info info = {
  .name = "Volume bar",
  .description = "A really cool volume bar to test audio capture",
  .enabled = BOB_AUDIO_TIME_DOMAIN_MONO,
};

EXPORT const struct bob_visualization_info *get_info(void)
{
  return &info;
}

EXPORT void *create(void)
{
  gladLoadGLLoader(api.get_proc_address);
  
  glGenVertexArrays(1, &vao);
  glBindVertexArray(vao);

  glGenBuffers(1, &vbo);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_data), vertex_data, GL_STREAM_DRAW);

  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (const void *)0);
  glEnableVertexAttribArray(0);

  GLuint vshader, fshader;
  vshader = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vshader, 1, &vertex_source, NULL);
  glCompileShader(vshader);
  
  fshader = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fshader, 1, &fragment_source, NULL);
  glCompileShader(fshader);

  program = glCreateProgram();
  glAttachShader(program, vshader);
  glAttachShader(program, fshader);
  glLinkProgram(program);

  glDeleteShader(vshader);
  glDeleteShader(fshader);

  glUseProgram(program);

  scale_handle = api.register_float_slider(api.context, "Scale factor", 0.25f, 10.0f, 1.0f);

  return NULL;
}

static float get_volume(const struct bob_float_buffer *buf)
{
  float max = 0.f;
  for (size_t i = 0; i < buf->size; ++i) {
    const float v = buf->ptr[i];
    const float v2 = v * v;
    if (v2 > max)
      max = v2;
  }
  return max;
}

EXPORT void update(void *userdata)
{
  (void) userdata;
  
  glBindVertexArray(vao);
  glUseProgram(program);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);

  const struct bob_float_buffer buf = api.get_time_data(api.context, BOB_MONO_CHANNEL);
  const float scale = api.get_ui_float_value(api.context, scale_handle);
  const float actual = (scale * get_volume(&buf) * 2.f) - 1.f;
  const float speed = 0.05f;
  const float threshold = 0.001f;
  const float diff = actual - volume;
  volume = ABS(diff) > threshold ? volume + diff * speed : actual;

  vertex_data[1] = volume;
  vertex_data[9] = volume;
  vertex_data[11] = volume;

  glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_data), vertex_data, GL_STREAM_DRAW);

  glClearColor(0.f, 0.f, 0.f, 1.f);
  glClear(GL_COLOR_BUFFER_BIT);

  glDrawArrays(GL_TRIANGLES, 0, 6);
}

EXPORT void destroy(void *userdata)
{
  (void) userdata;
  glDeleteBuffers(1, &vbo);
  glDeleteVertexArrays(1, &vao);
  glDeleteProgram(program);
}

