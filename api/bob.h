#ifndef BOB_H
#define BOB_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

enum bob_key_type {
    BOB_KEY_MAJOR,
    BOB_KEY_MINOR,
};

/**
 * Returned by get_key.
 */
struct bob_key {

    /**
     * The pitch class of the root note, starting
     * with C = 0 and increasing in half tone steps.
     */
    int pitch_class;

    /** Major/minor */
    enum bob_key_type type;

    /** Confidence value TODO: spcify range. */
    float confidence;
};

enum bob_mood {
    BOB_HAPPY = 0,
    BOB_EXUBERANT = 1,
    BOB_ENERGETIC = 2,
    BOB_FRANTIC = 3,
    BOB_ANXIOUS = 4,
    BOB_DEPRESSION = 5,
    BOB_CALM = 6,
    BOB_CONTENTMENT = 7,
};

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

    /* Breaks data */
    BOB_AUDIO_BREAKS_MONO = (1 << 10),
    BOB_AUDIO_BREAKS_STEREO = (1 << 11),

    /* Key data */
    BOB_AUDIO_KEY_MONO = (1 << 12),
    BOB_AUDIO_KEY_STEREO = (1 << 13),

    /* Mood data */
    BOB_AUDIO_MOOD_MONO = (1 << 14),
    BOB_AUDIO_MOOD_STEREO = (1 << 15),
};

struct bob_float_buffer {
    const float *ptr;
    size_t size;
};

/**
 * BoB API.
 */
struct bob_api {
    /**
     * BoB context passed to API functions.
     */
    void *context;

    /**
     * For use with OpenGL loaders.
     */
    void *(*get_proc_address)(const char *name);

    /**
     * Get delta time in seconds.
     */
    float (*get_deltatime)(void *context);

    /**
     * Get window size. Returns non zero if window was resized since last call.
     */
    int (*get_window_size)(void *context, int *x, int *y);

    /**
     * Get time domain data for specified channel.
     */
    struct bob_float_buffer (*get_time_data)(void *context, int channel);

    /**
     * Get frequency domain data for specified channel.
     */
    struct bob_float_buffer (*get_frequency_data)(void *context, int channel);

    /**
     * Get chromagram for specified channel.
     * `buf` should point to an array of 12 floats.
     */
    void (*get_chromagram)(void *context, float *buf, int channel);

    /**
     * Get pulse data for specified channel.
     */
    struct bob_float_buffer (*get_pulse_data)(void *context, int channel);

    /**
     * Get pulse debug graph for specified channel.
     */
    struct bob_float_buffer (*get_pulse_graph)(void *context, int channel);

    /**
     * Set pulse analysis parameters.
     */
    void (*set_pulse_params)(void *context, int channel, float C, float Vl);

    /**
     * Get tempo for specified channel.
     */
    float (*get_tempo)(void *context, int channel);

    /**
     * Get tempo debug graph for specified channel.
     */
    struct bob_float_buffer (*get_tempo_graph)(void *context, int channel);

    /**
     * Returns wether there is a break in the audio (slience).
     * This flag is reset when it's read.
     */
    int (*in_break)(void *context, int channel);

    /**
     * Returns the currently detected key (see definition of struct bob_key).
     */
    struct bob_key (*get_key)(void *context, int channel);

    /**
     * Returns the mood of the specified channel.
     */
    int (*get_mood)(void *context, int channel);

    /**
     * Register a float slider.
     */
    int (*register_float_slider)(void *context, const char *name, float min, float max, float default_value);

    /**
     * Register a int slider.
     */
    int (*register_int_slider)(void *context, const char *name, int min, int max, int default_value);

    /**
     * Register a checkbox.
     */
    int (*register_checkbox)(void *context, const char *name, int default_value);

    /**
     * Register a color picker.
     */
    int (*register_colorpicker)(void *context, const char *name, float *default_color);

    /**
     * Check if a UI element is updated since last read.
     */
    int (*ui_element_is_updated)(void *context, int handle);

    /**
     * Get float value from a UI element.
     */
    float (*get_ui_float_value)(void *context, int handle);

    /**
     * Get int value from a UI element.
     */
    int (*get_ui_int_value)(void *context, int handle);

    /**
     * Get boolean value from a UI element.
     */
    int (*get_ui_bool_value)(void *context, int handle);

    /**
     * Get RGB values from a colorpicker.
     */
    void (*get_ui_colorpicker_value)(void *context, int handle, float *color);

    /**
     * Set the referenc pitch for C3 used in chromagram computation.
     */
    void (*set_chromagram_c3)(void *context, float pitch);

    /**
     * Set the number of octaves to consider during chromagram computation.
     */
    void (*set_chromagram_num_octaves)(void *context, size_t num);

    /**
     * Set the number of partials to consider during chromagram computation.
     */
    void (*set_chromagram_num_partials)(void *context, size_t num);
};

/********************************************
 * The following symbols need to be defined *
 * in the visualization instance.           *
 ********************************************/

/**
 * Filled out by BoB runtime before `create` is called.
 */
extern struct bob_api api;

/**
 * Return some info about this visualization.
 */
const struct bob_visualization_info *get_info(void);

/**
 * Initialize visualization.
 * UI parameters should be registered here.
 * Return NULL, or an error string in case of failure
 * to initialize.
 */
const char *create(void);

/**
 * Called for each frame.
 */
void update(void);

/**
 * Perform potential visualization cleanup.
 */
void destroy(void);

#ifdef __cplusplus
}
#endif

#endif /* BOB_H */
