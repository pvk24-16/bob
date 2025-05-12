#include <stdlib.h>
#include <stdio.h>
#include <bob.h>
#include "glad/glad.h"

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

struct bob_api api;

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

static struct bob_visualizer_info info = {
    .name = "Volume bar",
    .description = "A really cool volume bar to test audio capture",
    .enabled = BOB_AUDIO_TIME_DOMAIN_MONO | BOB_AUDIO_FREQUENCY_DOMAIN_MONO | BOB_AUDIO_FREQUENCY_DOMAIN_STEREO ,
};

const struct bob_visualizer_info *get_info(void) {
    return &info;
}

const char *create(void) {
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

    return NULL;
}

static float sum_freqs(const struct bob_float_buffer *buf, const size_t start, const size_t end) {
    float acc = 0.f;
    
    for (size_t i = start; i < end; ++i) {
        const float v = buf->ptr[i];
        acc += v * v;
    }

    return acc;
}

void update(void) {
    (void) userdata;
    
    glBindVertexArray(vao);
    glUseProgram(program);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);

    const struct bob_float_buffer mono = api.get_frequency_data(api.context, BOB_MONO_CHANNEL);
    // const struct bob_float_buffer spec = api.get_frequency_data(api.context, BOB_RIGHT_CHANNEL);
    const size_t N = 32;
    const size_t step = mono.size / N;
    const float stepx = 2.0 / (float)N;
    
    float px = -1;
    size_t h = N;
    size_t t = 0;
    
    glClearColor(0.f, 0.f, 0.f, 1.f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    for (size_t i = 0; i < N; i++) {
        const float vol = 40 * sum_freqs(&mono, t, h) - 0.9;

        vertex_data[1] = vol;
        vertex_data[9] = vol;
        vertex_data[11] = vol;

        vertex_data[0] = px + stepx;
        vertex_data[2] = px + stepx;
        vertex_data[10] = px + stepx;
        
        vertex_data[4] = px;
        vertex_data[6] = px;
        vertex_data[8] = px;

        glBufferData(GL_ARRAY_BUFFER, sizeof(vertex_data), vertex_data, GL_STREAM_DRAW);
        glDrawArrays(GL_TRIANGLES, 0, 6);
        
        t = h;
        h += N;
        px += stepx;
    }

    glDrawArrays(GL_TRIANGLES, 0, 6);
}

void destroy(void) {
    (void) userdata;

    glDeleteBuffers(1, &vbo);
    glDeleteVertexArrays(1, &vao);
    glDeleteProgram(program);
}
