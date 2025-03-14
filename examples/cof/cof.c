#include <stdlib.h>
#include <stdio.h>
#include <bob.h>
#include <math.h>

#include "glad/glad.h"

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

const char *const vsource =
  "#version 330 core\n"
  "in vec2 v_pos;\n"
  "in vec4 v_col;\n"
  "out vec4 f_col;\n"
  "void main() {\n"
  "  f_col = v_col;\n"
  "  gl_Position = vec4(v_pos, 0.0, 1.0);\n"
  "}\n";

const char *const fsource =
  "#version 330 core\n"
  "in vec4 f_col;\n"
  "out vec4 o_col;\n"
  "void main() {\n"
  "  o_col = f_col;\n"
  "}\n";

static int radius_handle;
static int base_octave_handle;
static int num_partials_handle;
static int num_octaves_handle;
static float radius = .8f;
static size_t base_octave = 3;
static size_t num_partials = 3;
static size_t num_octaves = 2;
static GLuint vbo;
static GLuint ibo;
static GLuint vao;
static GLuint program;
static float vertex_data[12 * 6] = {0};
static unsigned int index_data[2 * 66 /* 12 chose 2 */] = {0};

EXPORT struct bob_api api;

static struct bob_visualization_info info = {
  .name = "Circle of fifths",
  .description = "Visualizes the pitch class content of the audio source in the form of a circle of fifths.",
  .enabled = BOB_AUDIO_CHROMAGRAM_MONO,
};

EXPORT const struct bob_visualization_info *get_info(void)
{
  return &info;
}

static void push_gl_state(void);
static void pop_gl_state(void);

EXPORT void *create(void)
{
  gladLoadGLLoader(api.get_proc_address);

  /* Register GUI elements */
  radius_handle = api.register_float_slider(api.context, "Radius", .2f, .9f, radius);
  base_octave_handle = api.register_int_slider(api.context, "Base octave", 3, 6, base_octave);
  num_octaves_handle = api.register_int_slider(api.context, "Number of octaves", 1, 6, num_octaves);
  num_partials_handle = api.register_int_slider(api.context, "Number of partials", 0, 5, num_partials);

  /* Create vertex buffer and vertex array */
  glGenBuffers(1, &vbo);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);

  glGenVertexArrays(1, &vao);
  glBindVertexArray(vao);

  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 6, (const void *) 0);
  glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(float) * 6, (const void *) (sizeof(float) * 2));
  glEnableVertexAttribArray(0);
  glEnableVertexAttribArray(1);

  /* Compile shader program */
  GLint vshader, fshader;
  vshader = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vshader, 1, &vsource, NULL);
  glCompileShader(vshader);

  fshader = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fshader, 1, &fsource, NULL);
  glCompileShader(fshader);

  program = glCreateProgram();
  glAttachShader(program, vshader);
  glAttachShader(program, fshader);
  glLinkProgram(program);

  glDeleteShader(vshader);
  glDeleteShader(fshader);

  /* Compute index data (connect all vertices with line segments) */
  size_t i = 0;
  for (size_t j = 0; j < 12; ++j) {
    for (size_t k = j + 1; k < 12; ++k) {
      index_data[i] = j;
      index_data[i + 1] = k;
      i += 2;
    }
  }

  return NULL;
}

EXPORT void update(void *userdata)
{
  (void) userdata;

  push_gl_state();

  static float chroma[12] = {0};
  float target_chroma[12];
  api.get_chromagram(api.context, target_chroma, BOB_MONO_CHANNEL);

  const float snap = .001f;
  const float threshold = .8f;

  for (size_t i = 0; i < 12; ++i) {
    const float v = target_chroma[i];
    const float target = v > threshold ? powf(v, 1.f) : .0f;
    const float diff = target - chroma[i];
    const float speed = diff > -1.f ? .1f : .7f; 
    chroma[i] = -snap < diff && diff < snap ? target : chroma[i] + speed * diff;
  }

  radius = api.get_ui_float_value(api.context, radius_handle);

  /* Compute vertex data */
  for (size_t i = 0; i < 12; ++i) {
    const float angle = 2.f * M_PI * 7.f * i / 12.f;
    const float x = radius * cosf(angle);
    const float y = radius * sinf(angle);

    const size_t off = i * 6;
    vertex_data[off + 0] = x;
    vertex_data[off + 1] = y;
    vertex_data[off + 2] = 1.f;
    vertex_data[off + 3] = 1.f;
    vertex_data[off + 4] = 1.f;
    vertex_data[off + 5] = chroma[i];
  }

  /* Draw the stuff */
  glClearColor(.1f, .1f, .1f, 1.f);
  glClear(GL_COLOR_BUFFER_BIT);

  glBindVertexArray(vao);
  glBindBuffer(GL_ARRAY_BUFFER, vbo);
  glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_data), vertex_data, GL_DYNAMIC_DRAW);
  glUseProgram(program);

  glDrawElements(GL_LINES, sizeof(index_data), GL_UNSIGNED_INT, index_data);

  pop_gl_state();

  base_octave = api.get_ui_int_value(api.context, base_octave_handle);
  num_partials = api.get_ui_int_value(api.context, num_partials_handle);
  num_octaves = api.get_ui_int_value(api.context, num_octaves_handle);

  api.set_chromagram_c3(api.context, 130.81f * powf(2.f, (float) base_octave));
  api.set_chromagram_num_partials(api.context, num_partials);
  api.set_chromagram_num_octaves(api.context, num_octaves);
}

EXPORT void destroy(void *userdata)
{
  (void) userdata;
  glDeleteBuffers(1, &vbo);
  glDeleteVertexArrays(1, &vao);
  glDeleteProgram(program);
}

/* Restoring some global OpenGL state before returning.
   Maybe this should be done in bob? */

static GLboolean saved_gl_blend;
static GLint saved_gl_blend_src_alpha;
static GLint saved_gl_blend_dst_alpha;
static GLboolean saved_gl_line_smooth;
static GLfloat saved_gl_line_width;

static void push_gl_state(void)
{
  glGetBooleanv(GL_BLEND, &saved_gl_blend);
  glGetIntegerv(GL_BLEND_SRC_ALPHA, &saved_gl_blend_src_alpha);
  glGetIntegerv(GL_BLEND_DST_ALPHA, &saved_gl_blend_dst_alpha);
  glGetBooleanv(GL_LINE_SMOOTH, &saved_gl_line_smooth);
  glGetFloatv(GL_LINE_WIDTH, &saved_gl_line_width);

  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glEnable(GL_LINE_SMOOTH);
  glLineWidth(5.f);
}

static void pop_gl_state(void)
{
  if (saved_gl_blend)
    glEnable(GL_BLEND);
  else
    glDisable(GL_BLEND);

  if (saved_gl_line_smooth)
    glEnable(GL_LINE_SMOOTH);
  else
    glDisable(GL_LINE_SMOOTH);

  glBlendFunc(saved_gl_blend_src_alpha, saved_gl_blend_dst_alpha);
  glLineWidth(saved_gl_line_width);
}
