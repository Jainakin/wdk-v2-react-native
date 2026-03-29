/*
 * WDKEngineBridge.h — C engine declarations for the wdk-v2-react-native pod
 *
 * This header exposes the wdk-v2-engine C API to Swift code inside the pod.
 * CocoaPods generates a module map that includes this file, making all
 * declarations accessible to WDKEngineModule.swift without a bridging header.
 *
 * The actual implementations are in libwdk_all.a, linked by the app target.
 */

#ifndef WDKEngineBridge_h
#define WDKEngineBridge_h

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ════════════════════════════════════════════════════════════════════
 * Engine Lifecycle
 * ════════════════════════════════════════════════════════════════════ */

typedef struct WDKEngine WDKEngine;
struct JSContext;

WDKEngine *wdk_engine_create(void);
void       wdk_engine_destroy(WDKEngine *engine);
int        wdk_engine_eval(WDKEngine *engine, const char *js_source);
int        wdk_engine_load_bytecode(WDKEngine *engine, const uint8_t *buf, size_t len);
char      *wdk_engine_call(WDKEngine *engine, const char *func_name, const char *json_args);
const char *wdk_engine_get_error(WDKEngine *engine);
int        wdk_engine_pump(WDKEngine *engine);
void       wdk_free_string(char *str);

struct JSContext *wdk_engine_get_context(WDKEngine *engine);

/* ════════════════════════════════════════════════════════════════════
 * Pure-C Bridges (no platform provider required)
 * Call these after wdk_engine_create(), before wdk_engine_eval().
 * ════════════════════════════════════════════════════════════════════ */

void wdk_register_crypto_bridge(struct JSContext *ctx);
void wdk_register_encoding_bridge(struct JSContext *ctx);

/* ════════════════════════════════════════════════════════════════════
 * Platform Provider
 * ════════════════════════════════════════════════════════════════════ */

typedef struct {
    const char *os_name;
    const char *engine_version;
    int  (*get_random_bytes)(uint8_t *buf, size_t len);
    void (*log_message)(int level, const char *message);
} WDKPlatformProvider;

void wdk_register_platform_bridge(struct JSContext *ctx,
                                   const WDKPlatformProvider *provider);

/* ════════════════════════════════════════════════════════════════════
 * Storage Provider
 * ════════════════════════════════════════════════════════════════════ */

typedef struct {
    int   (*secure_set)(const char *key, const uint8_t *value, size_t value_len);
    int   (*secure_get)(const char *key, uint8_t **out_value, size_t *out_len);
    int   (*secure_delete)(const char *key);
    int   (*secure_has)(const char *key);
    int   (*regular_set)(const char *key, const char *value);
    char *(*regular_get)(const char *key);
    int   (*regular_delete)(const char *key);
} WDKStorageProvider;

void wdk_register_storage_bridge(struct JSContext *ctx,
                                  const WDKStorageProvider *provider);

/* ════════════════════════════════════════════════════════════════════
 * Network Provider
 * ════════════════════════════════════════════════════════════════════ */

typedef void (*WDKFetchCallback)(void    *context,
                                  int      status_code,
                                  const char *headers_json,
                                  const uint8_t *body, size_t body_len,
                                  const char *error);

typedef struct {
    void (*fetch)(const char *url,
                  const char *method,
                  const char *headers_json,
                  const uint8_t *body, size_t body_len,
                  int timeout_ms,
                  void *context,
                  WDKFetchCallback callback);
} WDKNetProvider;

void wdk_register_net_bridge(struct JSContext *ctx,
                              const WDKNetProvider *provider);

#ifdef __cplusplus
}
#endif

#endif /* WDKEngineBridge_h */
