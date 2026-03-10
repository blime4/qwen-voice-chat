#ifndef CHATLLM_BRIDGE_H
#define CHATLLM_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void* chatllm_context_t;

typedef enum {
    CHATLLM_OK = 0,
    CHATLLM_ERROR_NULL_CONTEXT = -1,
    CHATLLM_ERROR_MODEL_LOAD = -2,
    CHATLLM_ERROR_TTS_GENERATE = -3,
    CHATLLM_ERROR_INVALID_TEXT = -4,
    CHATLLM_ERROR_MEMORY = -5,
} chatllm_error_t;

chatllm_context_t chatllm_create(const char* model_path);
void chatllm_free(chatllm_context_t ctx);

chatllm_error_t chatllm_tts_generate(
    chatllm_context_t ctx,
    const char* text,
    float** out_audio,
    int32_t* out_samples,
    int32_t* out_sample_rate
);

void chatllm_free_audio(float* audio);
const char* chatllm_get_error(chatllm_context_t ctx);

#ifdef __cplusplus
}
#endif

#endif
