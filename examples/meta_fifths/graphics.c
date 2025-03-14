#include "graphics.h"
#include "params.h"

#include <bob.h>
#include <glad/glad.h>

static GLuint s_vbo;
static GLuint s_vao;
static GLuint s_program;

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

void graphics_init(void)
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

void graphics_deinit(void)
{
  glDeleteBuffers(1, &s_vbo);
  glDeleteVertexArrays(1, &s_vao);
  glDeleteProgram(s_program);
}

void draw_buffer(struct buffer *b)
{
  float *bg = get_bg_color();
  glClearColor(bg[0], bg[1], bg[2], 1.f);
  glClear(GL_COLOR_BUFFER_BIT);
  glBindVertexArray(s_vao);
  glUseProgram(s_program);
  glBindBuffer(GL_ARRAY_BUFFER, s_vbo);
  glBufferData(GL_ARRAY_BUFFER, b->size * sizeof(*b->data), b->data, GL_DYNAMIC_DRAW);
  glDrawArrays(GL_TRIANGLES, 0, b->size / 6);
}
