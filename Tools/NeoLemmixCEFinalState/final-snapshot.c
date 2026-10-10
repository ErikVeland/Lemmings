/*
 * Read-only state controller for NeoLemmix CE 1.2.0, executable SHA-256
 * 58d2fccd31e20d5513ee8d2d5eafb6d368f847d8d2cb4a152efeedcb6d4eaf36.
 * Addresses and object offsets are tied to that reviewed 32-bit Delphi build.
 */
#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include <wctype.h>

#define GAME_VMT 0x00b98474u
#define GAME_SIZE 0x514u
#define LEMMING_SIZE 0xe4u

typedef struct {
    DWORD pid;
    HWND preview;
    HWND game_window;
} context_t;

static BOOL CALLBACK choose_duplicate(HWND window, LPARAM value) {
    wchar_t class_name[64], title[128];
    HWND list_box, load_button;
    (void)value;
    if (!IsWindowVisible(window)) return TRUE;
    GetClassNameW(window, class_name, 64);
    GetWindowTextW(window, title, 128);
    if (wcscmp(class_name, L"TFLevelListDialog") != 0 || wcscmp(title, L"Select Level") != 0) {
        return TRUE;
    }
    list_box = FindWindowExW(window, NULL, L"TListBox", NULL);
    load_button = FindWindowExW(window, NULL, L"TButton", L"Load");
    if (list_box && load_button) {
        SendMessageW(list_box, LB_SETCURSEL, 0, 0);
        SendMessageW(load_button, BM_CLICK, 0, 0);
    }
    return FALSE;
}

static BOOL CALLBACK find_child(HWND window, LPARAM value) {
    context_t *context = (context_t *)value;
    wchar_t class_name[64];
    GetClassNameW(window, class_name, 64);
    if (IsWindowVisible(window) && wcscmp(class_name, L"TGamePreviewScreen") == 0) {
        context->preview = window;
    }
    if (IsWindowVisible(window) && wcscmp(class_name, L"TGameWindow") == 0) {
        context->game_window = window;
        GetWindowThreadProcessId(window, &context->pid);
    }
    return TRUE;
}

static BOOL CALLBACK find_windows(HWND window, LPARAM value) {
    EnumChildWindows(window, find_child, value);
    return TRUE;
}

static void refresh_windows(context_t *context) {
    context->preview = NULL;
    context->game_window = NULL;
    EnumWindows(choose_duplicate, 0);
    EnumWindows(find_windows, (LPARAM)context);
}

static void press_key(HWND window, WORD key) {
    SendMessageW(window, WM_KEYDOWN, key, 0);
    SendMessageW(window, WM_KEYUP, key, 0xc0000001);
}

static BOOL read_exact(HANDLE process, ULONG_PTR address, void *buffer, SIZE_T size) {
    SIZE_T read = 0;
    return ReadProcessMemory(process, (void *)address, buffer, size, &read) && read == size;
}

static DWORD read_dword(HANDLE process, ULONG_PTR address, BOOL *ok) {
    DWORD value = 0;
    *ok = read_exact(process, address, &value, sizeof(value));
    return value;
}

static BOOL wait_for_settled_lemmings(HANDLE process, ULONG_PTR game_address, DWORD timeout_ms) {
    DWORD started = GetTickCount();
    do {
        BYTE game[GAME_SIZE];
        DWORD list, item_array, count, active, removed;
        DWORD counted_active = 0, counted_removed = 0, counted_saved = 0;
        BOOL consistent = TRUE;
        if (!read_exact(process, game_address, game, sizeof(game))) return FALSE;
        list = *(DWORD *)(game + 0x50);
        active = *(DWORD *)(game + 0xf0);
        removed = *(DWORD *)(game + 0xfc);
        if (!read_exact(process, list + 4, &item_array, 4) ||
            !read_exact(process, list + 8, &count, 4) || count > 10000) return FALSE;
        for (DWORD index = 0; index < count; index++) {
            DWORD pointer;
            BYTE action_and_removed[2];
            if (!read_exact(process, item_array + index * 4, &pointer, 4) ||
                !read_exact(process, pointer + 0x58, action_and_removed, 2)) return FALSE;
            if (action_and_removed[1]) {
                counted_removed++;
                if (action_and_removed[0] == 13) counted_saved++;
            } else {
                counted_active++;
            }
        }
        consistent = active == counted_active && removed == counted_removed &&
                     *(DWORD *)(game + 0xf8) == counted_saved;
        if (consistent) return TRUE;
        Sleep(1);
    } while (GetTickCount() - started < timeout_ms);
    return FALSE;
}

static ULONG_PTR find_game(HANDLE process) {
    ULONG_PTR address = 0x10000;
    MEMORY_BASIC_INFORMATION info;
    BYTE *buffer = NULL;
    SIZE_T capacity = 0;
    while (address < 0x7fff0000 && VirtualQueryEx(process, (void *)address, &info, sizeof(info))) {
        ULONG_PTR next = (ULONG_PTR)info.BaseAddress + info.RegionSize;
        if (info.State == MEM_COMMIT && !(info.Protect & (PAGE_NOACCESS | PAGE_GUARD)) &&
            (info.Protect & (PAGE_READWRITE | PAGE_WRITECOPY | PAGE_EXECUTE_READWRITE | PAGE_EXECUTE_WRITECOPY)) &&
            info.RegionSize <= 64 * 1024 * 1024) {
            if (capacity < info.RegionSize) {
                if (buffer) HeapFree(GetProcessHeap(), 0, buffer);
                buffer = (BYTE *)HeapAlloc(GetProcessHeap(), 0, info.RegionSize);
                capacity = info.RegionSize;
            }
            SIZE_T read = 0;
            if (buffer && ReadProcessMemory(process, info.BaseAddress, buffer, info.RegionSize, &read)) {
                for (SIZE_T offset = 0; offset + GAME_SIZE <= read; offset += 4) {
                    if (*(DWORD *)(buffer + offset) != GAME_VMT) continue;
                    DWORD list = *(DWORD *)(buffer + offset + 0x50);
                    DWORD bitmap = *(DWORD *)(buffer + offset + 0x54);
                    DWORD tick = *(DWORD *)(buffer + offset + 0xd8);
                    DWORD list_vmt = 0, bitmap_vmt = 0;
                    SIZE_T item_read = 0;
                    if (tick < 10000000 &&
                        ReadProcessMemory(process, (void *)(ULONG_PTR)list, &list_vmt, 4, &item_read) && item_read == 4 &&
                        ReadProcessMemory(process, (void *)(ULONG_PTR)bitmap, &bitmap_vmt, 4, &item_read) && item_read == 4 &&
                        bitmap_vmt == 0x00af58e8u) {
                        if (buffer) HeapFree(GetProcessHeap(), 0, buffer);
                        return (ULONG_PTR)info.BaseAddress + offset;
                    }
                }
            }
        }
        if (next <= address) break;
        address = next;
    }
    if (buffer) HeapFree(GetProcessHeap(), 0, buffer);
    return 0;
}

static BOOL write_file(const wchar_t *directory, const wchar_t *name, const void *bytes, DWORD size) {
    wchar_t path[1024];
    HANDLE file;
    DWORD written = 0;
    swprintf(path, 1024, L"%ls\\%ls", directory, name);
    file = CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return FALSE;
    BOOL result = WriteFile(file, bytes, size, &written, NULL) && written == size;
    CloseHandle(file);
    return result;
}

static BOOL move_output(const wchar_t *directory, const wchar_t *from, const wchar_t *to) {
    wchar_t source[1024], destination[1024];
    swprintf(source, 1024, L"%ls\\%ls", directory, from);
    swprintf(destination, 1024, L"%ls\\%ls", directory, to);
    return MoveFileExW(source, destination, MOVEFILE_REPLACE_EXISTING);
}

static BOOL snapshot(HANDLE process, ULONG_PTR game_address, const wchar_t *directory) {
    BYTE game[GAME_SIZE];
    DWORD list, item_array, count, physics_bitmap, renderer, layers, layer_items, terrain_bitmap;
    DWORD physics_backend, terrain_backend, physics_bits, terrain_bits, width, height;
    DWORD *pointers = NULL;
    BYTE *lemmings = NULL, *physics = NULL, *terrain = NULL, *renderer_bytes = NULL, *gadgets = NULL;
    DWORD renderer_vmt, renderer_size, gadget_list, gadget_items, gadget_count;
    DWORD gadgets_size = 4;
    BOOL ok = FALSE;
    SIZE_T pixel_bytes;

    if (!read_exact(process, game_address, game, sizeof(game))) goto done;
    list = *(DWORD *)(game + 0x50);
    physics_bitmap = *(DWORD *)(game + 0x54);
    renderer = *(DWORD *)(game + 0xb4);
    if (!read_exact(process, renderer, &renderer_vmt, 4) ||
        !read_exact(process, renderer_vmt - 52, &renderer_size, 4) ||
        renderer_size == 0 || renderer_size > 1024 * 1024) goto done;
    renderer_bytes = (BYTE *)HeapAlloc(GetProcessHeap(), 0, renderer_size);
    if (!renderer_bytes || !read_exact(process, renderer, renderer_bytes, renderer_size)) goto done;
    if (!read_exact(process, list + 4, &item_array, 4) ||
        !read_exact(process, list + 8, &count, 4) || count > 10000) goto done;
    pointers = (DWORD *)HeapAlloc(GetProcessHeap(), 0, count * 4);
    lemmings = (BYTE *)HeapAlloc(GetProcessHeap(), 0, count * LEMMING_SIZE);
    if (!pointers || !lemmings || !read_exact(process, item_array, pointers, count * 4)) goto done;
    for (DWORD index = 0; index < count; index++) {
        if (!read_exact(process, pointers[index], lemmings + index * LEMMING_SIZE, LEMMING_SIZE)) goto done;
    }

    gadget_list = *(DWORD *)(game + 0x370);
    if (!read_exact(process, gadget_list + 4, &gadget_items, 4) ||
        !read_exact(process, gadget_list + 8, &gadget_count, 4) || gadget_count > 10000) goto done;
    for (DWORD index = 0; index < gadget_count; index++) {
        DWORD pointer, vmt, size;
        if (!read_exact(process, gadget_items + index * 4, &pointer, 4) ||
            !read_exact(process, pointer, &vmt, 4) ||
            !read_exact(process, vmt - 52, &size, 4) || size == 0 || size > 65536) goto done;
        gadgets_size += 4 + size;
    }
    gadgets = (BYTE *)HeapAlloc(GetProcessHeap(), 0, gadgets_size);
    if (!gadgets) goto done;
    *(DWORD *)gadgets = gadget_count;
    DWORD gadget_offset = 4;
    for (DWORD index = 0; index < gadget_count; index++) {
        DWORD pointer, vmt, size;
        read_exact(process, gadget_items + index * 4, &pointer, 4);
        read_exact(process, pointer, &vmt, 4);
        read_exact(process, vmt - 52, &size, 4);
        *(DWORD *)(gadgets + gadget_offset) = size;
        gadget_offset += 4;
        if (!read_exact(process, pointer, gadgets + gadget_offset, size)) goto done;
        gadget_offset += size;
    }

    if (!read_exact(process, physics_bitmap + 0x48, &height, 4) ||
        !read_exact(process, physics_bitmap + 0x4c, &width, 4) ||
        !read_exact(process, physics_bitmap + 0x58, &physics_backend, 4) ||
        !read_exact(process, physics_backend + 0x48, &physics_bits, 4) ||
        width == 0 || height == 0 || width > 10000 || height > 10000) goto done;
    if (!read_exact(process, renderer + 0x1c, &layers, 4) ||
        !read_exact(process, layers + 4, &layer_items, 4) ||
        !read_exact(process, layer_items + 4 * 4, &terrain_bitmap, 4) ||
        !read_exact(process, terrain_bitmap + 0x58, &terrain_backend, 4) ||
        !read_exact(process, terrain_backend + 0x48, &terrain_bits, 4)) goto done;
    pixel_bytes = (SIZE_T)width * height * 4;
    physics = (BYTE *)HeapAlloc(GetProcessHeap(), 0, pixel_bytes);
    terrain = (BYTE *)HeapAlloc(GetProcessHeap(), 0, pixel_bytes);
    if (!physics || !terrain ||
        !read_exact(process, physics_bits, physics, pixel_bytes) ||
        !read_exact(process, terrain_bits, terrain, pixel_bytes)) goto done;

    CreateDirectoryW(directory, NULL);
    if (!write_file(directory, L"game.bin", game, sizeof(game)) ||
        !write_file(directory, L"lemming-pointers.bin", pointers, count * 4) ||
        !write_file(directory, L"lemmings.bin", lemmings, count * LEMMING_SIZE) ||
        !write_file(directory, L"renderer.bin", renderer_bytes, renderer_size) ||
        !write_file(directory, L"gadgets.bin", gadgets, gadgets_size) ||
        !write_file(directory, L"physics.bin", physics, (DWORD)pixel_bytes) ||
        !write_file(directory, L"terrain.bin", terrain, (DWORD)pixel_bytes)) goto done;
    wchar_t dimensions[128];
    swprintf(dimensions, 128, L"width=%lu\r\nheight=%lu\r\nlemmings=%lu\r\n",
             (unsigned long)width, (unsigned long)height, (unsigned long)count);
    char utf8[256];
    int length = WideCharToMultiByte(CP_UTF8, 0, dimensions, -1, utf8, sizeof(utf8), NULL, NULL);
    if (length <= 1 || !write_file(directory, L"metadata.txt", utf8, (DWORD)(length - 1))) goto done;
    ok = TRUE;

done:
    if (pointers) HeapFree(GetProcessHeap(), 0, pointers);
    if (lemmings) HeapFree(GetProcessHeap(), 0, lemmings);
    if (physics) HeapFree(GetProcessHeap(), 0, physics);
    if (terrain) HeapFree(GetProcessHeap(), 0, terrain);
    if (renderer_bytes) HeapFree(GetProcessHeap(), 0, renderer_bytes);
    if (gadgets) HeapFree(GetProcessHeap(), 0, gadgets);
    return ok;
}

int wmain(int argc, wchar_t **argv) {
    context_t context = {0};
    HANDLE process;
    ULONG_PTR game_address;
    DWORD target, started, tick = 0, next;
    BOOL read_ok;
    if (argc != 3) {
        fwprintf(stderr, L"usage: final-snapshot TARGET_TICK OUTPUT_DIRECTORY\n");
        return 64;
    }
    target = wcstoul(argv[1], NULL, 0);
    started = GetTickCount();
    while (GetTickCount() - started < 30000) {
        refresh_windows(&context);
        if (context.preview) break;
        Sleep(25);
    }
    if (!context.preview) { fwprintf(stderr, L"preview window not found\n"); return 2; }
    press_key(context.preview, VK_SPACE);
    started = GetTickCount();
    while (GetTickCount() - started < 30000) {
        refresh_windows(&context);
        if (context.game_window && context.pid) break;
        Sleep(25);
    }
    if (!context.game_window) { fwprintf(stderr, L"game window not found\n"); return 3; }
    process = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ | PROCESS_TERMINATE, FALSE, context.pid);
    if (!process) { fwprintf(stderr, L"process open failed: %lu\n", GetLastError()); return 4; }
    game_address = find_game(process);
    if (!game_address) { fwprintf(stderr, L"game object not found\n"); return 5; }

    started = GetTickCount();
    do {
        Sleep(10);
        tick = read_dword(process, game_address + 0xd8, &read_ok);
        if (!read_ok) return 6;
    } while (tick == 0 && GetTickCount() - started < 5000);
    press_key(context.game_window, VK_SPACE);
    Sleep(150);
    DWORD paused_tick = read_dword(process, game_address + 0xd8, &read_ok);
    Sleep(100);
    tick = read_dword(process, game_address + 0xd8, &read_ok);
    if (!read_ok || tick != paused_tick) {
        fwprintf(stderr, L"could not pause initial playback at %lu/%lu\n", paused_tick, tick);
        return 6;
    }
    press_key(context.game_window, VK_F1);
    started = GetTickCount();
    do {
        Sleep(10);
        tick = read_dword(process, game_address + 0xd8, &read_ok);
        if (!read_ok) return 6;
    } while (tick != 0 && GetTickCount() - started < 5000);
    if (tick != 0 || tick > target) { fwprintf(stderr, L"could not restart at tick zero: %lu\n", tick); return 6; }
    if (!wait_for_settled_lemmings(process, game_address, 5000) ||
        !snapshot(process, game_address, argv[2]) ||
        !move_output(argv[2], L"physics.bin", L"initial-physics.bin") ||
        !move_output(argv[2], L"terrain.bin", L"initial-terrain.bin")) {
        fwprintf(stderr, L"initial snapshot failed: %lu\n", GetLastError());
        return 11;
    }

    while (target - tick >= 170) {
        next = tick + 170;
        press_key(context.game_window, '6');
        started = GetTickCount();
        DWORD last_change = started;
        DWORD prior_tick = tick;
        do {
            Sleep(1);
            tick = read_dword(process, game_address + 0xd8, &read_ok);
            if (!read_ok) return 7;
            if (tick != prior_tick) {
                prior_tick = tick;
                last_change = GetTickCount();
            }
        } while (tick < next && GetTickCount() - started < 30000 && GetTickCount() - last_change < 100);
        while (tick < next) {
            press_key(context.game_window, '3');
            Sleep(10);
            tick = read_dword(process, game_address + 0xd8, &read_ok);
            if (!read_ok) return 7;
        }
        while (tick > next) {
            press_key(context.game_window, '2');
            Sleep(10);
            tick = read_dword(process, game_address + 0xd8, &read_ok);
            if (!read_ok) return 7;
        }
        if (tick != next) { fwprintf(stderr, L"skip stopped at %lu, expected %lu\n", tick, next); return 8; }
    }
    while (tick < target) {
        next = tick + 1;
        press_key(context.game_window, '3');
        started = GetTickCount();
        do {
            Sleep(1);
            tick = read_dword(process, game_address + 0xd8, &read_ok);
            if (!read_ok) return 9;
        } while (tick < next && GetTickCount() - started < 5000);
        while (tick > next) {
            press_key(context.game_window, '2');
            Sleep(10);
            tick = read_dword(process, game_address + 0xd8, &read_ok);
            if (!read_ok) return 9;
        }
        if (tick != next) { fwprintf(stderr, L"step stopped at %lu, expected %lu\n", tick, next); return 10; }
    }

    // The replay skip/step handler can publish the target iteration before its
    // lemming pass and render-normalisation callbacks have returned. Let that
    // work drain before taking a cross-object snapshot.
    Sleep(100);
    if (!wait_for_settled_lemmings(process, game_address, 5000) ||
        !snapshot(process, game_address, argv[2])) {
        fwprintf(stderr, L"snapshot failed: %lu\n", GetLastError());
        return 11;
    }
    wprintf(L"captured tick %lu from %08lx with pid %lu\n", tick, (unsigned long)game_address, context.pid);
    TerminateProcess(process, 0);
    CloseHandle(process);
    return 0;
}
