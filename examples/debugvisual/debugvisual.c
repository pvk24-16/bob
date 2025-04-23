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

static float s_scale = 0.5f;
static int s_scale_handle;
static size_t s_buffer_size = 0;
static size_t s_buffer_capacity = 128;
static float *s_buffer = NULL;
static float s_draw_x;
static float s_draw_y;
static float s_draw_max_w;
static GLuint s_vbo;
static GLuint s_vao;
static GLuint s_program;
static float s_break_r[3];
static float s_break_g[3];
static float s_break_b[3];

#define CHROMAGRAM_SPACING (0.01f * s_scale)
#define CHROMAGRAM_CELL_SIZE (0.1f * s_scale)
#define SPECTROGRAM_RESOLUTION 48

const char *const s_vsource =
  "#version 330 core\n"
  "in vec2 v_pos;\n"
  "in vec4 v_col;\n"
  "out vec4 f_col;\n"
  "void main() {\n"
  "  f_col = v_col;\n"
  "  gl_Position = vec4(v_pos, 0.0, 1.0);\n"
  "}\n";

const char *const s_fsource =
  "#version 330 core\n"
  "in vec4 f_col;\n"
  "out vec4 o_col;\n"
  "void main() {\n"
  "  o_col = f_col;\n"
  "}\n";

static void init_buffer(void)
{
  s_buffer = malloc(sizeof(*s_buffer) * s_buffer_capacity);
}

static void clear_buffer(void)
{
  s_buffer_size = 0;
}

static void destroy_buffer(void)
{
  free(s_buffer);
}

static void push_float(float f)
{
  if (s_buffer_size == s_buffer_capacity) {
    s_buffer_capacity *= 2;
    s_buffer = realloc(s_buffer, sizeof(*s_buffer) * s_buffer_capacity);
  }

  s_buffer[s_buffer_size++] = f;
}

static void push_quad(float x, float y, float w, float h, float r, float g, float b, float a)
{
  push_float(x);
  push_float(y);
  push_float(r);
  push_float(g);
  push_float(b);
  push_float(a);

  push_float(x + w);
  push_float(y);
  push_float(r);
  push_float(g);
  push_float(b);
  push_float(a);

  push_float(x);
  push_float(y + h);
  push_float(r);
  push_float(g);
  push_float(b);
  push_float(a);

  push_float(x + w);
  push_float(y);
  push_float(r);
  push_float(g);
  push_float(b);
  push_float(a);

  push_float(x);
  push_float(y + h);
  push_float(r);
  push_float(g);
  push_float(b);
  push_float(a);

  push_float(x + w);
  push_float(y + h);
  push_float(r);
  push_float(g);
  push_float(b);
  push_float(a);

}

static void reset_draw_state(void)
{
  s_draw_x = -1.f;
  s_draw_y = -1.f;
  s_draw_max_w = 0.f;
}

static void draw_quad(float x, float y, float w, float h, float r, float g, float b)
{
  push_quad(s_draw_x + x, s_draw_y + y, w, h, r, g, b, 1.f);
  s_draw_y += y + h;
  s_draw_max_w = x + w > s_draw_max_w ? x + w : s_draw_max_w;
}

static void new_column(void)
{
  s_draw_y = -1.f;
  s_draw_x += s_draw_max_w;
  s_draw_max_w = 0.f;
}

static void do_the_drawing(void)
{
  glClearColor(0.f, 0.f, 0.f, 1.f);
  glClear(GL_COLOR_BUFFER_BIT);
  glBindVertexArray(s_vao);
  glUseProgram(s_program);
  glBindBuffer(GL_ARRAY_BUFFER, s_vbo);
  glBufferData(GL_ARRAY_BUFFER, s_buffer_size * sizeof(*s_buffer), s_buffer, GL_DYNAMIC_DRAW);
  glDrawArrays(GL_TRIANGLES, 0, s_buffer_size / 6);
}

static void setup_drawing(void)
{
  gladLoadGLLoader(api.get_proc_address);

  glGenBuffers(1, &s_vbo);
  glBindBuffer(GL_ARRAY_BUFFER, s_vbo);

  glGenVertexArrays(1, &s_vao);
  glBindVertexArray(s_vao);

  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 6, (const void *) 0);
  glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(float) * 6, (const void *) (sizeof(float) * 2));
  glEnableVertexAttribArray(0);
  glEnableVertexAttribArray(1);

  GLint vshader, fshader;
  vshader = glCreateShader(GL_VERTEX_SHADER);
  glShaderSource(vshader, 1, &s_vsource, NULL);
  glCompileShader(vshader);

  fshader = glCreateShader(GL_FRAGMENT_SHADER);
  glShaderSource(fshader, 1, &s_fsource, NULL);
  glCompileShader(fshader);

  s_program = glCreateProgram();
  glAttachShader(s_program, vshader);
  glAttachShader(s_program, fshader);
  glLinkProgram(s_program);

  glDeleteShader(vshader);
  glDeleteShader(fshader);
}

static void stop_drawing(void)
{
  glDeleteBuffers(1, &s_vbo);
  glDeleteVertexArrays(1, &s_vao);
  glDeleteProgram(s_program);
}

static void draw_chromagram(enum bob_channel ch)
{
  float chroma[12];
  api.get_chromagram(api.context, chroma, ch);

  float r = (float) ch == BOB_LEFT_CHANNEL;
  float g = (float) ch == BOB_MONO_CHANNEL;
  float b = (float) ch == BOB_RIGHT_CHANNEL;

  new_column();
  for (size_t i = 0; i < 12; ++i) {
    // TODO: maybe remove this power, feels like cheating
    //       also it's not even correct in low octaves
    float v = powf(chroma[i], 10.00f);
    draw_quad(CHROMAGRAM_SPACING, 
              CHROMAGRAM_SPACING, 
              CHROMAGRAM_CELL_SIZE, 
              CHROMAGRAM_CELL_SIZE, 
              v * r,
              v * g,
              v * b);
  }
}

static void draw_spectrogram(enum bob_channel ch)
{
  struct bob_float_buffer buf = api.get_frequency_data(api.context, ch);

  float height = 12 * CHROMAGRAM_CELL_SIZE + 11 * CHROMAGRAM_SPACING;
  float size = height / SPECTROGRAM_RESOLUTION;

  new_column();
  float r = (float) ch == BOB_LEFT_CHANNEL;
  float g = (float) ch == BOB_MONO_CHANNEL;
  float b = (float) ch == BOB_RIGHT_CHANNEL;


  for (size_t i = 0; i < SPECTROGRAM_RESOLUTION; ++i) {
    size_t buf_index = (size_t) ((float) buf.size * (float) i / (float) SPECTROGRAM_RESOLUTION);
    float v = buf.ptr[buf_index];
    draw_quad(CHROMAGRAM_SPACING,
              i == 0 ? CHROMAGRAM_SPACING : 0,
              CHROMAGRAM_CELL_SIZE,
              size,
              v * 100.f * r,
              v * 100.f * g,
              v * 100.f * b);
  }
}

static void randomize_break_color(enum bob_channel ch)
{
  s_break_r[ch] = (float) rand() / (float) RAND_MAX;
  s_break_g[ch] = (float) rand() / (float) RAND_MAX;
  s_break_b[ch] = (float) rand() / (float) RAND_MAX;
}

static void draw_break(enum bob_channel ch)
{
  if (api.in_break(api.context, ch))
    randomize_break_color(ch);

  float height = 12 * CHROMAGRAM_CELL_SIZE + 11 * CHROMAGRAM_SPACING;

  new_column();
  draw_quad(CHROMAGRAM_SPACING,
            CHROMAGRAM_SPACING,
            CHROMAGRAM_CELL_SIZE,
            height,
            s_break_r[ch],
            s_break_g[ch],
            s_break_b[ch]);
}

struct bob_api api;

static struct bob_visualization_info info = {
  .name = "Debug visualizer",
  .description = "Hej hej",
  .enabled =
    BOB_AUDIO_FREQUENCY_DOMAIN_MONO |
    BOB_AUDIO_FREQUENCY_DOMAIN_STEREO |
    BOB_AUDIO_CHROMAGRAM_MONO |
    BOB_AUDIO_CHROMAGRAM_STEREO |
    BOB_AUDIO_BREAKS_MONO |
    BOB_AUDIO_BREAKS_STEREO,
};

const struct bob_visualization_info *get_info(void)
{
  return &info;
}

const char *create(void)
{
  init_buffer();
  setup_drawing();
  reset_draw_state();

  randomize_break_color(BOB_LEFT_CHANNEL);
  randomize_break_color(BOB_MONO_CHANNEL);
  randomize_break_color(BOB_RIGHT_CHANNEL);

  s_scale_handle = api.register_float_slider(api.context, "Scale", 0.2f, 2.0f, s_scale);
  return NULL;
}

void update(void)
{
  if (api.ui_element_is_updated(api.context, s_scale_handle))
    s_scale = api.get_ui_float_value(api.context, s_scale_handle);

  int w, h;
  if (api.get_window_size(api.context, &w, &h))
    glViewport(0, 0, w, h);

  reset_draw_state();
  clear_buffer();

  static const enum bob_channel chs[] = {
    BOB_LEFT_CHANNEL,
    BOB_MONO_CHANNEL,
    BOB_RIGHT_CHANNEL,
  };

  for (size_t i = 0; i < 3; ++i) {
    enum bob_channel ch = chs[i];
    draw_chromagram(ch);
    draw_spectrogram(ch);
    draw_break(ch);
  }

  do_the_drawing();
}

void destroy(void)
{
  stop_drawing();
  destroy_buffer();
}
