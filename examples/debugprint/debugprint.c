#include <stdlib.h>
#include <stdio.h>
#include <bob.h>

#ifdef WIN32
#define EXPORT __attribute__((dllexport))
#else
#define EXPORT
#endif

int enabled = 0;

int format_full_data = 0;
int format_average = 0;
int format_length = 0;

int print_update = 0;
int print_deltatime = 0;

int print_time_mono = 0;
int print_time_left = 0;
int print_time_right = 0;

int print_fft_mono = 0;
int print_fft_left = 0;
int print_fft_right = 0;

int print_chroma_mono = 0;
int print_chroma_left = 0;
int print_chroma_right = 0;

int print_pulse_mono = 0;
int print_pulse_left = 0;
int print_pulse_right = 0;

int print_tempo_mono = 0;
int print_tempo_left = 0;
int print_tempo_right = 0;

int print_breaks_mono = 0;
int print_breaks_left = 0;
int print_breaks_right = 0;

EXPORT struct bob_api api;

static struct bob_visualizer_info info = {
  .name = "debugprint",
  .description = "A debug visualizer used to test the BoB API.\n Select the checkboxes for things you want to be debug printed.",
  .enabled =
    BOB_AUDIO_TIME_DOMAIN_MONO |
    BOB_AUDIO_TIME_DOMAIN_STEREO |
    BOB_AUDIO_FREQUENCY_DOMAIN_MONO |
    BOB_AUDIO_FREQUENCY_DOMAIN_STEREO |
    BOB_AUDIO_CHROMAGRAM_MONO |
    BOB_AUDIO_CHROMAGRAM_STEREO |
    BOB_AUDIO_PULSE_MONO |
    BOB_AUDIO_PULSE_STEREO |
    BOB_AUDIO_TEMPO_MONO |
    BOB_AUDIO_TEMPO_STEREO |
    BOB_AUDIO_BREAKS_MONO |
    BOB_AUDIO_BREAKS_STEREO,
};

EXPORT const struct bob_visualizer_info *get_info(void)
{
  printf("get_info\n");
  return &info;
}

EXPORT const char *create(void)
{
  printf("create\n");
  enabled = api.register_checkbox(api.context, "Enable/disable all printing", 1);
  
  format_full_data = api.register_checkbox(api.context, "Format: Show full data", 0);
  format_average = api.register_checkbox(api.context, "Format: Show average", 1);
  format_length = api.register_checkbox(api.context, "Format: Show length", 0);
  
  print_update = api.register_checkbox(api.context, "Print: update function", 0);
  print_deltatime = api.register_checkbox(api.context, "Print: deltatime", 0);
  
  print_time_mono = api.register_checkbox(api.context, "Print: Time domain mono", 0);
  print_time_left = api.register_checkbox(api.context, "Print: Time domain left", 0);
  print_time_right = api.register_checkbox(api.context, "Print: Time domain right", 0);

  print_fft_mono = api.register_checkbox(api.context, "Print: FFT mono", 0);
  print_fft_left = api.register_checkbox(api.context, "Print: FFT left", 0);
  print_fft_right = api.register_checkbox(api.context, "Print: FFT right", 0);

  print_chroma_mono = api.register_checkbox(api.context, "Print: Chromagram mono", 0);
  print_chroma_left = api.register_checkbox(api.context, "Print: Chromagram left", 0);
  print_chroma_right = api.register_checkbox(api.context, "Print: Chromagram right", 0);

  print_pulse_mono = api.register_checkbox(api.context, "Print: Pulse mono", 0);
  print_pulse_left = api.register_checkbox(api.context, "Print: Pulse left", 0);
  print_pulse_right = api.register_checkbox(api.context, "Print: Pulse right", 0);

  print_tempo_mono = api.register_checkbox(api.context, "Print: Tempo mono", 0);
  print_tempo_left = api.register_checkbox(api.context, "Print: Tempo left", 0);
  print_tempo_right = api.register_checkbox(api.context, "Print: Tempo right", 0);

  print_breaks_mono = api.register_checkbox(api.context, "Print: Breaks mono", 0);
  print_breaks_left = api.register_checkbox(api.context, "Print: Breaks left", 0);
  print_breaks_right = api.register_checkbox(api.context, "Print: Breaks right", 0);

  return NULL;
}

void print_float_buffer(struct bob_float_buffer buf) {
  if (api.get_ui_bool_value(api.context, format_average)) {
    float sum = 0;
    for (int i = 0; i < buf.size; i++) {
      sum += buf.ptr[i];
    }
    float average = sum / buf.size;
    printf("%.3f\n", average);
  }
  if (api.get_ui_bool_value(api.context, format_length)) {
    printf("length: %d\n", buf.size);
  }
  if (api.get_ui_bool_value(api.context, format_full_data)) {
    printf("\n[");
    for (int i = 0; i < buf.size; i++) {
      printf("%.3f", buf.ptr[i]);
      if (i != buf.size - 1) {
        printf(", ");
      }
    }
    printf("]\n");
  }
}

EXPORT void update(void)
{
  if (!api.get_ui_bool_value(api.context, enabled)) {
    return;
  }

  if (api.get_ui_bool_value(api.context, print_update)) {
    printf("update\n");
  }

  if (api.get_ui_bool_value(api.context, print_deltatime)) {
    printf("deltatime: %f\n", api.get_deltatime(api.context));
  }

  // Time domain
  if (api.get_ui_bool_value(api.context, print_time_mono)) {
    printf("Time domain mono: ");
    print_float_buffer(api.get_time_data(api.context, BOB_MONO_CHANNEL));
  }
  if (api.get_ui_bool_value(api.context, print_time_left)) {
    printf("Time domain left: ");
    print_float_buffer(api.get_time_data(api.context, BOB_LEFT_CHANNEL));
  }
  if (api.get_ui_bool_value(api.context, print_time_right)) {
    printf("Time domain right: ");
    print_float_buffer(api.get_time_data(api.context, BOB_RIGHT_CHANNEL));
  }

  // FFT
  if (api.get_ui_bool_value(api.context, print_fft_mono)) {
    printf("FFT mono: ");
    print_float_buffer(api.get_frequency_data(api.context, BOB_MONO_CHANNEL));
  }
  if (api.get_ui_bool_value(api.context, print_fft_left)) {
    printf("FFT left: ");
    print_float_buffer(api.get_frequency_data(api.context, BOB_LEFT_CHANNEL));
  }
  if (api.get_ui_bool_value(api.context, print_fft_right)) {
    printf("FFT right: ");
    print_float_buffer(api.get_frequency_data(api.context, BOB_RIGHT_CHANNEL));
  }

  // Chroma
  if (api.get_ui_bool_value(api.context, print_chroma_mono)) {
    printf("Chromagram mono: ");
    float buf[12];
    api.get_chromagram(api.context, buf, BOB_MONO_CHANNEL);
    print_float_buffer((struct bob_float_buffer) { buf, 12 });
  }
  if (api.get_ui_bool_value(api.context, print_chroma_left)) {
    printf("Chromagram left: ");
    float buf[12];
    api.get_chromagram(api.context, buf, BOB_LEFT_CHANNEL);
    print_float_buffer((struct bob_float_buffer) { buf, 12 });
  }
  if (api.get_ui_bool_value(api.context, print_chroma_right)) {
    printf("Chromagram right: ");
    float buf[12];
    api.get_chromagram(api.context, buf, BOB_RIGHT_CHANNEL);
    print_float_buffer((struct bob_float_buffer) { buf, 12 });
  }

  // Pulse
  if (api.get_ui_bool_value(api.context, print_pulse_mono)) {
    printf("Pulse mono: ");
    print_float_buffer(api.get_pulse_data(api.context, BOB_MONO_CHANNEL));
  }
  if (api.get_ui_bool_value(api.context, print_pulse_left)) {
    printf("Pulse left: ");
    print_float_buffer(api.get_pulse_data(api.context, BOB_LEFT_CHANNEL));
  }
  if (api.get_ui_bool_value(api.context, print_pulse_right)) {
    printf("Pulse right: ");
    print_float_buffer(api.get_pulse_data(api.context, BOB_RIGHT_CHANNEL));
  }

  // Tempo
  if (api.get_ui_bool_value(api.context, print_tempo_mono)) {
    printf("Tempo mono: %f\n", api.get_tempo(api.context, BOB_MONO_CHANNEL));
  }
  if (api.get_ui_bool_value(api.context, print_tempo_left)) {
    printf("Tempo left: %f\n", api.get_tempo(api.context, BOB_LEFT_CHANNEL));
  }
  if (api.get_ui_bool_value(api.context, print_tempo_right)) {
    printf("Tempo right: %f\n", api.get_tempo(api.context, BOB_RIGHT_CHANNEL));
  }

  // Breaks
  if (api.get_ui_bool_value(api.context, print_breaks_mono)) {
    printf("Breaks mono: %d\n", api.in_break(api.context, BOB_MONO_CHANNEL));
  }
  if (api.get_ui_bool_value(api.context, print_breaks_left)) {
    printf("Breaks left: %d\n", api.in_break(api.context, BOB_LEFT_CHANNEL));
  }
  if (api.get_ui_bool_value(api.context, print_breaks_right)) {
    printf("Breaks right: %d\n", api.in_break(api.context, BOB_RIGHT_CHANNEL));
  }
}

EXPORT void destroy(void)
{
  printf("destroy\n");
}
