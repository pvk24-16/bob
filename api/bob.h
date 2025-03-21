#ifndef BOB_H
#define BOB_H

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN32
# ifdef __GNUC__
#  define BOB_RUNTIME_API __attribute__((weak))
#  define BOB_VISUALIZER_API __attribute__((dllexport))
# else
#  define BOB_RUNTIME_API __declspec(selectany)
#  define BOB_VISUALIZER_API __declspec(dllexport)
# endif
#else
# define BOB_RUNTIME_API
# define BOB_VISUALIZER_API
#endif

#include <stddef.h>

enum bob_channel {
    BOB_MONO_CHANNEL,
    BOB_LEFT_CHANNEL,
    BOB_RIGHT_CHANNEL,
};

/**
 * Information about this visualization
 * returned by `getInfo`.
 */
struct bob_visualization_info {
    /* The name of this visualization */
    const char *name;

    /* A description of this visualization */
    const char *description;

    /* Enabled analysis tools */
    int enabled;
};

/**
 * Types of audio analysis.
 */
enum bob_audio_flags {
    /* Raw audio data */
    BOB_AUDIO_TIME_DOMAIN_MONO = (1 << 0),
    BOB_AUDIO_TIME_DOMAIN_STEREO = (1 << 1),

    /* Frequency domain data */
    BOB_AUDIO_FREQUENCY_DOMAIN_MONO = (1 << 2),
    BOB_AUDIO_FREQUENCY_DOMAIN_STEREO = (1 << 3),

    /* Chromagram */
    BOB_AUDIO_CHROMAGRAM_MONO = (1 << 4),
    BOB_AUDIO_CHROMAGRAM_STEREO = (1 << 5),

    /* Pulse data */
    BOB_AUDIO_PULSE_MONO = (1 << 6),
    BOB_AUDIO_PULSE_STEREO = (1 << 7),

    /* Tempo data */
    BOB_AUDIO_TEMPO_MONO = (1 << 8),
    BOB_AUDIO_TEMPO_STEREO = (1 << 9),
};

struct bob_float_buffer {
    const float *ptr;
    size_t size;
};

/**
 * BoB API.
 */

/**
 * For use with OpenGL loaders.
 */
BOB_RUNTIME_API extern void *(*bob_get_proc_address)(const char *name);

/**
 * Get delta time in seconds.
 */
BOB_RUNTIME_API float bob_get_deltatime(void);

/**
 * Get window size. Returns non zero if window was resized since last call.
 */
BOB_RUNTIME_API int bob_get_window_size(int *x, int *y);

/**
 * Get time domain data for specified channel.
 */
BOB_RUNTIME_API struct bob_float_buffer bob_get_time_data(int channel);

/**
 * Get frequency domain data for specified channel.
 */
BOB_RUNTIME_API struct bob_float_buffer bob_get_frequency_data(int channel);

/**
 * Get chromagram for specified channel.
 * `buf` should point to an array of 12 floats.
 */
BOB_RUNTIME_API void bob_get_chromagram(float *buf, int channel);

/**
 * Get pulse data for specified channel.
 */
BOB_RUNTIME_API struct bob_float_buffer bob_get_pulse_data(int channel);

/**
 * Get tempo for specified channel.
 */
BOB_RUNTIME_API float bob_get_tempo(int channel);

/**
 * Register a float slider.
 */
BOB_RUNTIME_API int bob_register_float_slider(const char *name, float min, float max, float default_value);

/**
 * Register a int slider.
 */
BOB_RUNTIME_API int bob_register_int_slider(const char *name, int min, int max, int default_value);

/**
 * Register a checkbox.
 */
BOB_RUNTIME_API int bob_register_checkbox(const char *name, int default_value);

/**
 * Register a color picker.
 */
BOB_RUNTIME_API int bob_register_colorpicker(const char *name, float *default_color);

/**
 * Check if a UI element is updated since last read.
 */
BOB_RUNTIME_API int bob_ui_element_is_updated(int handle);

/**
 * Get float value from a UI element.
 */
BOB_RUNTIME_API float bob_get_ui_float_value(int handle);

/**
 * Get int value from a UI element.
 */
BOB_RUNTIME_API int bob_get_ui_int_value(int handle);

/**
 * Get boolean value from a UI element.
 */
BOB_RUNTIME_API int bob_get_ui_bool_value(int handle);

/**
 * Get RGB values from a colorpicker.
 */
BOB_RUNTIME_API void bob_get_ui_colorpicker_value(int handle, float *color);

/**
 * Set the referenc pitch for C3 used in chromagram computation.
 */
BOB_RUNTIME_API void bob_set_chromagram_c3(float pitch);

/**
 * Set the number of octaves to consider during chromagram computation.
 */
BOB_RUNTIME_API void bob_set_chromagram_num_octaves(size_t num);

/**
 * Set the number of partials to consider during chromagram computation.
 */
BOB_RUNTIME_API void bob_set_chromagram_num_partials(size_t num);

/********************************************
 * The following symbols need to be defined *
 * in the visualization instance.           *
 ********************************************/

/**
 * Return some info about this visualization.
 */
const struct bob_visualization_info *get_info(void);

/**
 * Initialize visualization.
 * UI parameters should be registered here.
 * Return a pointer to user data, or NULL.
 */
void *create(void);

/**
 * Called for each frame.
 * Audio analysis data is passed in `data`.
 */
void update(void *userdata);

/**
 * Perform potential visualization cleanup.
 */
void destroy(void *userdata);

#ifdef __cplusplus
}
#endif

#endif /* BOB_H */
