#include <dlfcn.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

// Diagnostic-only malloc event counter. Never linked into an application.
// Count successful allocation events on the calling benchmark thread only.
typedef void (*logger_t)(uint32_t, uintptr_t, uintptr_t, uintptr_t, uintptr_t, uint32_t);
static logger_t *slot;
static logger_t previous;
static _Thread_local bool enabled;
static _Thread_local uint64_t allocations;

static void record(uint32_t type, uintptr_t a, uintptr_t b, uintptr_t c,
                   uintptr_t result, uint32_t skip) {
    if (enabled && (type & 2) && result) allocations++;
    if (previous) previous(type, a, b, c, result, skip);
}

int benchmark_allocations_begin(void) {
    slot = (logger_t *)dlsym(RTLD_DEFAULT, "malloc_logger");
    if (!slot) return 0;
    previous = *slot;
    allocations = 0;
    *slot = record;
    enabled = true;
    return 1;
}

uint64_t benchmark_allocations_end(void) {
    enabled = false;
    if (slot) *slot = previous;
    return allocations;
}

__attribute__((noinline)) uint64_t benchmark_allocations_selftest(void) {
    if (!benchmark_allocations_begin()) return 0;
    void *volatile pointer = malloc(123);
    free(pointer);
    return benchmark_allocations_end();
}
