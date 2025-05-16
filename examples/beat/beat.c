#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <bob.h>
#include <glad/glad.h>

#ifdef WIN32
# define EXPORT __attribute__((dllexport))
#else
# define EXPORT
#endif

static struct bob_visualizer_info info =
{
	.name = "Beat test",
	.description = "Visualizer for testing beat detection.",
	.enabled = BOB_AUDIO_PULSE_MONO | BOB_AUDIO_TEMPO_MONO,
};

static int C_handle;
static int M_handle;
static int Vl_handle;
static float C = 2.25f;
static float M = 25.f;
static float Vl = -5.5f;

static const char *vsh_src =
	"#version 330 core\n"
	"\n"
	"in  vec2 v_pos;\n"
	"in  vec4 v_col;\n"
	"out vec4 f_col;"
	"\n"
	"void main()\n"
	"{\n"
	"    gl_Position = vec4(v_pos, 0.0, 1.0);\n"
	"    f_col = v_col;\n"
	"}\n";

static const char *fsh_src =
	"#version 330 core\n"
	"\n"
	"in  vec4 f_col;\n"
	"out vec4 col;\n"
	"\n"
	"void main()\n"
	"{\n"
	"    col = f_col;\n"
	"}\n";

typedef struct
{
	float x;
	float y;
} Vec2f;

typedef struct
{
	float x;
	float y;
	float z;
	float w;
} Vec4f;

static GLuint vbo;
static GLuint vao;
static GLuint prog;
static struct
{
	Vec2f v_pos[2048];
	Vec4f v_col[2048];
} v_buf;

EXPORT struct bob_api api;

EXPORT const struct bob_visualizer_info *get_info(void)
{
	return &info;
}

EXPORT const char *create(void)
{
	gladLoadGLLoader(api.get_proc_address);

	glGenVertexArrays(1, &vao);
	glBindVertexArray(vao);

	glGenBuffers(1, &vbo);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, sizeof(v_buf), &v_buf, GL_STREAM_DRAW);

	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(Vec2f), (const void *) 0);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(Vec4f), (const void *) sizeof(v_buf.v_pos));
	glEnableVertexAttribArray(1);

	GLuint vsh;
	vsh = glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(vsh, 1, &vsh_src, NULL);
	glCompileShader(vsh);

	GLuint fsh;
	fsh = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(fsh, 1, &fsh_src, NULL);
	glCompileShader(fsh);

	prog = glCreateProgram();
	glAttachShader(prog, vsh);
	glAttachShader(prog, fsh);
	glLinkProgram(prog);

	glDeleteShader(vsh);
	glDeleteShader(fsh);

	glUseProgram(prog);

	C_handle = api.register_float_slider(api.context, "Magnitude threshold", 0.1f, 10.f, C);
	Vl_handle = api.register_float_slider(api.context, "Variance threshold log", -10.f, -3.f, Vl);
	M_handle = api.register_float_slider(api.context, "Graph scale", 1.f, 100.f, M);

	return NULL;
}

EXPORT void update(void)
{
	struct bob_float_buffer pulse = api.get_pulse_data(api.context, BOB_MONO_CHANNEL);
	struct bob_float_buffer graph = api.get_pulse_graph(api.context, BOB_MONO_CHANNEL);
	const size_t B = pulse.size;

	C = api.get_ui_float_value(api.context, C_handle);
	Vl = api.get_ui_float_value(api.context, Vl_handle);
	M = api.get_ui_float_value(api.context, M_handle);

	api.set_pulse_params(api.context, BOB_MONO_CHANNEL, C, Vl);

	glClearColor(0, 0, 0, 0);
	glClear(GL_COLOR_BUFFER_BIT);

	glBindVertexArray(vao);
	glUseProgram(prog);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);

	glEnable(GL_LINE_SMOOTH);
	glDisable(GL_FILL);
	glLineWidth(1.25f);

	for (size_t i = 0; i < B; i++)
	{
		static float Eh[128];

		float h = pulse.ptr[i];
		float s = graph.ptr[i];

		{
			float w = 2.f / B;

			if (h != 0)
			{
				Eh[i] = 1.f;
			}

			Eh[i] -= 0.1;

			if (Eh[i] < 0)
			{
				Eh[i] = 0;
			}

			{
				Vec2f v[] =
				{
					{ -1.f + (i + 0) * w, 0 },
					{ -1.f + (i + 0) * w, s * M },
					{ -1.f + (i + 1) * w, s * M },
					{ -1.f + (i + 1) * w, 0 },
				};

				v_buf.v_pos[6 * i + 0] = v[0];
				v_buf.v_pos[6 * i + 1] = v[1];
				v_buf.v_pos[6 * i + 2] = v[2];
				v_buf.v_pos[6 * i + 3] = v[0];
				v_buf.v_pos[6 * i + 4] = v[2];
				v_buf.v_pos[6 * i + 5] = v[3];
			}

			{
				Vec4f v =
				{
					Eh[i], 0.f, 1.f - Eh[i], 1.f,
				};

				v_buf.v_col[6 * i + 0] = v;
				v_buf.v_col[6 * i + 1] = v;
				v_buf.v_col[6 * i + 2] = v;
				v_buf.v_col[6 * i + 3] = v;
				v_buf.v_col[6 * i + 4] = v;
				v_buf.v_col[6 * i + 5] = v;
			}
		}
	}

	struct bob_float_buffer bpm_graph;
	bpm_graph = api.get_tempo_graph(api.context, BOB_MONO_CHANNEL);

	for (size_t i = 0; i < bpm_graph.size; i++)
	{
		Vec2f p =
		{
			(float) i / (bpm_graph.size - 1) * 2 - 1,
			bpm_graph.ptr[i],
		};
		Vec4f c =
		{
			1.f, 1.f, 1.f, 1.f,
		};

		v_buf.v_pos[6 * B + i] = p;
		v_buf.v_col[6 * B + i] = c;
	}

	glBufferData(GL_ARRAY_BUFFER, sizeof(v_buf), &v_buf, GL_STREAM_DRAW);
	glDrawArrays(GL_TRIANGLES, 0, 6 * B);
	glDrawArrays(GL_LINE_STRIP, 6 * B, bpm_graph.size);

	{
		static float bpm = 0;
		float new_bpm = api.get_tempo(api.context, BOB_MONO_CHANNEL);

		if (bpm != new_bpm)
		{
			bpm = new_bpm;

			fprintf(stderr, "BPM: %g\n", bpm);
		}
	}
}

EXPORT void destroy(void)
{
}
