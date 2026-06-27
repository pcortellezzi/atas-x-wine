#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>

CRITICAL_SECTION g_cs_swp;
BYTE original_bytes_swp[14];
void* target_address_swp = NULL;
bool hook_swp_installed = false;

CRITICAL_SECTION g_cs_defer;
BYTE original_bytes_defer[14];
void* target_address_defer = NULL;
bool hook_defer_installed = false;

void log_message(const char* format, ...) {
    // Logging disabled for production performance
}

extern "C" BOOL WINAPI Hooked_SetWindowPos(HWND hWnd, HWND hWndInsertAfter, int X, int Y, int cx, int cy, UINT uFlags) {
    if (X >= -150 && X <= -50 && Y >= -150 && Y <= -50) {
        log_message("Intercepted SetWindowPos: HWND=%p, X=%d, Y=%d -> changing to -2000,-2000\n", hWnd, X, Y);
        X = -2000;
        Y = -2000;
    }

    EnterCriticalSection(&g_cs_swp);

    DWORD oldProtect;
    VirtualProtect(target_address_swp, 14, PAGE_EXECUTE_READWRITE, &oldProtect);
    memcpy(target_address_swp, original_bytes_swp, 14);

    typedef BOOL(WINAPI* SetWindowPos_t)(HWND, HWND, int, int, int, int, UINT);
    BOOL result = ((SetWindowPos_t)target_address_swp)(hWnd, hWndInsertAfter, X, Y, cx, cy, uFlags);

    BYTE jump_instructions[14] = {
        0xFF, 0x25, 0x00, 0x00, 0x00, 0x00, 
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
    };
    uint64_t addr = (uint64_t)Hooked_SetWindowPos;
    memcpy(&jump_instructions[6], &addr, 8);
    memcpy(target_address_swp, jump_instructions, 14);
    VirtualProtect(target_address_swp, 14, oldProtect, &oldProtect);

    LeaveCriticalSection(&g_cs_swp);

    return result;
}

extern "C" HDWP WINAPI Hooked_DeferWindowPos(HDWP hWinPosInfo, HWND hWnd, HWND hWndInsertAfter, int x, int y, int cx, int cy, UINT uFlags) {
    if (x >= -150 && x <= -50 && y >= -150 && y <= -50) {
        log_message("Intercepted DeferWindowPos: HWND=%p, X=%d, Y=%d -> changing to -2000,-2000\n", hWnd, x, y);
        x = -2000;
        y = -2000;
    }

    EnterCriticalSection(&g_cs_defer);

    DWORD oldProtect;
    VirtualProtect(target_address_defer, 14, PAGE_EXECUTE_READWRITE, &oldProtect);
    memcpy(target_address_defer, original_bytes_defer, 14);

    typedef HDWP(WINAPI* DeferWindowPos_t)(HDWP, HWND, HWND, int, int, int, int, UINT);
    HDWP result = ((DeferWindowPos_t)target_address_defer)(hWinPosInfo, hWnd, hWndInsertAfter, x, y, cx, cy, uFlags);

    BYTE jump_instructions[14] = {
        0xFF, 0x25, 0x00, 0x00, 0x00, 0x00, 
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
    };
    uint64_t addr = (uint64_t)Hooked_DeferWindowPos;
    memcpy(&jump_instructions[6], &addr, 8);
    memcpy(target_address_defer, jump_instructions, 14);
    VirtualProtect(target_address_defer, 14, oldProtect, &oldProtect);

    LeaveCriticalSection(&g_cs_defer);

    return result;
}

void install_hooks() {
    InitializeCriticalSection(&g_cs_swp);
    InitializeCriticalSection(&g_cs_defer);

    HMODULE hUser32 = GetModuleHandleA("user32.dll");
    if (!hUser32) {
        log_message("Error: Failed to get user32.dll handle\n");
        return;
    }

    target_address_swp = (void*)GetProcAddress(hUser32, "SetWindowPos");
    if (target_address_swp) {
        DWORD oldProtect;
        VirtualProtect(target_address_swp, 14, PAGE_EXECUTE_READWRITE, &oldProtect);
        memcpy(original_bytes_swp, target_address_swp, 14);

        BYTE jump_instructions[14] = {
            0xFF, 0x25, 0x00, 0x00, 0x00, 0x00, 
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
        };
        uint64_t addr = (uint64_t)Hooked_SetWindowPos;
        memcpy(&jump_instructions[6], &addr, 8);
        memcpy(target_address_swp, jump_instructions, 14);
        VirtualProtect(target_address_swp, 14, oldProtect, &oldProtect);
        hook_swp_installed = true;
        log_message("Hook installed successfully on SetWindowPos at %p\n", target_address_swp);
    } else {
        log_message("Error: Failed to get SetWindowPos address\n");
    }

    target_address_defer = (void*)GetProcAddress(hUser32, "DeferWindowPos");
    if (target_address_defer) {
        DWORD oldProtect;
        VirtualProtect(target_address_defer, 14, PAGE_EXECUTE_READWRITE, &oldProtect);
        memcpy(original_bytes_defer, target_address_defer, 14);

        BYTE jump_instructions[14] = {
            0xFF, 0x25, 0x00, 0x00, 0x00, 0x00, 
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
        };
        uint64_t addr = (uint64_t)Hooked_DeferWindowPos;
        memcpy(&jump_instructions[6], &addr, 8);
        memcpy(target_address_defer, jump_instructions, 14);
        VirtualProtect(target_address_defer, 14, oldProtect, &oldProtect);
        hook_defer_installed = true;
        log_message("Hook installed successfully on DeferWindowPos at %p\n", target_address_defer);
    } else {
        log_message("Error: Failed to get DeferWindowPos address\n");
    }
}

extern "C" __declspec(dllexport) void Dummy() {}

extern "C" BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    if (fdwReason == DLL_PROCESS_ATTACH) {
        log_message("DLL_PROCESS_ATTACH: window_hider_hook.dll loaded\n");
        install_hooks();
    }
    return TRUE;
}
