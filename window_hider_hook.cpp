#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>

void log_message(const char* format, ...) {
    FILE* f = fopen("C:\\window_hider_hook.log", "a");
    if (f) {
        va_list args;
        va_start(args, format);
        vfprintf(f, format, args);
        va_end(args);
        fclose(f);
    }
}

// ANSI_STRING structure definition used by ntdll
typedef struct _STRING {
    USHORT Length;
    USHORT MaximumLength;
    PCHAR  Buffer;
} STRING, *PSTRING, ANSI_STRING, *PANSI_STRING;

// Global target address for calling the trampoline (original function execution)
void* g_trampoline_LdrGetProcedureAddress = NULL;

// Function pointers for original user32 APIs that we bypass detouring for (called dynamically)
typedef BOOL(WINAPI* SetWindowPos_t)(HWND, HWND, int, int, int, int, UINT);
typedef HDWP(WINAPI* DeferWindowPos_t)(HDWP, HWND, HWND, int, int, int, int, UINT);
typedef HWND(WINAPI* GetCapture_t)(VOID);
typedef HWND(WINAPI* SetCapture_t)(HWND);
typedef BOOL(WINAPI* ReleaseCapture_t)(VOID);
typedef BOOL(WINAPI* GetMessageW_t)(LPMSG, HWND, UINT, UINT);
typedef BOOL(WINAPI* PeekMessageW_t)(LPMSG, HWND, UINT, UINT, UINT);

SetWindowPos_t g_orig_SetWindowPos = NULL;
DeferWindowPos_t g_orig_DeferWindowPos = NULL;
GetCapture_t g_orig_GetCapture = NULL;
SetCapture_t g_orig_SetCapture = NULL;
ReleaseCapture_t g_orig_ReleaseCapture = NULL;
GetMessageW_t g_orig_GetMessageW = NULL;
PeekMessageW_t g_orig_PeekMessageW = NULL;

// Window tracking and drag-drop emulation variables
CRITICAL_SECTION g_cs_window_tracker;
HWND g_atas_windows[10] = {0};
WNDPROC g_orig_WndProcs[10] = {0};
int g_window_monitors[10] = {0}; // Track which physical monitor index the window is on
int g_atas_count = 0;

HWND g_main_window_capture = NULL; // Stores the main window that currently has active drag capture

// Dynamic Monitor Enumeration structures
struct MonitorInfo {
    RECT rect;
};
MonitorInfo g_monitors[10] = {0};
int g_monitor_count = 0;

// Enumerate display monitors callback
BOOL CALLBACK MonitorEnumProc(HMONITOR hMonitor, HDC hdcMonitor, LPRECT lprcMonitor, LPARAM dwData) {
    if (g_monitor_count < 10) {
        g_monitors[g_monitor_count].rect = *lprcMonitor;
        g_monitor_count++;
    }
    return TRUE;
}

// Query display monitor layout dynamically from Wine/compositor configuration
void query_monitors() {
    EnterCriticalSection(&g_cs_window_tracker);
    g_monitor_count = 0;
    EnumDisplayMonitors(NULL, NULL, MonitorEnumProc, 0);
    
    // Sort monitors by left coordinate (left-to-right) so they map logically
    for (int i = 0; i < g_monitor_count - 1; i++) {
        for (int j = i + 1; j < g_monitor_count; j++) {
            if (g_monitors[i].rect.left > g_monitors[j].rect.left) {
                MonitorInfo temp = g_monitors[i];
                g_monitors[i] = g_monitors[j];
                g_monitors[j] = temp;
            }
        }
    }
    log_message("Detected %d physical monitor(s):\n", g_monitor_count);
    for (int i = 0; i < g_monitor_count; i++) {
        log_message("  Monitor %d: bounds (%ld, %ld) - (%ld, %ld)\n",
                    i, g_monitors[i].rect.left, g_monitors[i].rect.top,
                    g_monitors[i].rect.right, g_monitors[i].rect.bottom);
    }
    LeaveCriticalSection(&g_cs_window_tracker);
}

// Update window's virtual position in Wine to match the monitor it is physically on
void update_window_virtual_monitor(HWND hWnd, int idx) {
    if (idx < 0 || idx >= 10 || !g_orig_SetWindowPos) return;
    
    POINT pt;
    if (GetCursorPos(&pt)) {
        EnterCriticalSection(&g_cs_window_tracker);
        int active_monitor = 0;
        
        // Find which enumerated monitor bounds contain the mouse cursor
        for (int i = 0; i < g_monitor_count; i++) {
            if (PtInRect(&g_monitors[i].rect, pt)) {
                active_monitor = i;
                break;
            }
        }
        
        // If monitor changed, update the tracked monitor index
        if (g_window_monitors[idx] != active_monitor) {
            g_window_monitors[idx] = active_monitor;
            log_message("Window HWND=%p moved physically to Monitor %d\n", hWnd, active_monitor);
        }
        
        // Ensure Wine's virtual coordinates match the physical monitor offset
        if (active_monitor < g_monitor_count) {
            RECT r;
            GetWindowRect(hWnd, &r);
            int target_x = g_monitors[active_monitor].rect.left;
            int target_y = g_monitors[active_monitor].rect.top;
            if (r.left != target_x || r.top != target_y) {
                log_message("Syncing window HWND=%p virtual origin from (%ld, %ld) to (%d, %d)\n", 
                            hWnd, r.left, r.top, target_x, target_y);
                g_orig_SetWindowPos(hWnd, NULL, target_x, target_y, r.right - r.left, r.bottom - r.top, 
                                    SWP_NOZORDER | SWP_NOACTIVATE);
            }
        }
        LeaveCriticalSection(&g_cs_window_tracker);
    }
}

// Forward declaration of window match helper
int get_atas_window_index(HWND hWnd);

// Subclass window procedure to swallow focus-loss, track drag start, and follow monitor changes
LRESULT CALLBACK Hooked_WndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    int idx = -1;
    EnterCriticalSection(&g_cs_window_tracker);
    for (int i = 0; i < g_atas_count; i++) {
        if (g_atas_windows[i] == hWnd) {
            idx = i;
            break;
        }
    }
    LeaveCriticalSection(&g_cs_window_tracker);
    
    WNDPROC orig = (idx >= 0 && idx < 10) ? g_orig_WndProcs[idx] : ::DefWindowProcW;
    
    // Dynamic hotplug re-querying when displays configurations change
    if (uMsg == WM_DISPLAYCHANGE) {
        log_message("Display geometry change detected! Re-querying layout...\n");
        query_monitors();
    }
    
    // Dynamically track monitor, but ONLY when window is clicked or actively focused, NEVER during dragging or deactivation!
    if (idx >= 0 && g_main_window_capture == NULL) {
        if (uMsg == WM_LBUTTONDOWN || (uMsg == WM_ACTIVATE && LOWORD(wParam) != WA_INACTIVE)) {
            update_window_virtual_monitor(hWnd, idx);
        }
    }
    
    // If another window has active drag capture, make this window blind to mouse events
    // to prevent it from stealing capture (calling SetCapture on hover)
    if (g_main_window_capture != NULL && hWnd != g_main_window_capture) {
        if (uMsg == WM_SETCURSOR || uMsg == WM_MOUSEACTIVATE || uMsg == WM_NCHITTEST ||
            (uMsg >= WM_MOUSEFIRST && uMsg <= WM_MOUSELAST)) {
            if (uMsg == WM_MOUSEACTIVATE) {
                return MA_NOACTIVATEANDEAT; // Block focus and discard mouse click
            }
            return 0; // Swallow event
        }
    }
    
    if (uMsg == WM_CAPTURECHANGED || uMsg == WM_CANCELMODE) {
        if ((GetAsyncKeyState(VK_LBUTTON) & 0x8000) || (GetAsyncKeyState(VK_RBUTTON) & 0x8000)) {
            log_message("Subclass swallowed message %u for HWND=%p during mouse drag\n", uMsg, hWnd);
            return 0; // Block cancellation!
        }
    }
    
    if (orig) {
        return CallWindowProcW(orig, hWnd, uMsg, wParam, lParam);
    }
    return ::DefWindowProcW(hWnd, uMsg, wParam, lParam);
}

// Automating the window spacing in memory (from window_fixer.exe logic)
int get_atas_window_index(HWND hWnd) {
    if (!hWnd) return -1;
    
    EnterCriticalSection(&g_cs_window_tracker);
    int found_idx = -1;
    for (int i = 0; i < g_atas_count; i++) {
        if (g_atas_windows[i] == hWnd) {
            found_idx = i;
            break;
        }
    }
    
    if (found_idx == -1) {
        char className[256] = {0};
        char title[256] = {0};
        GetClassNameA(hWnd, className, sizeof(className));
        GetWindowTextA(hWnd, title, sizeof(title));
        LONG style = GetWindowLongA(hWnd, GWL_STYLE);
        LONG exStyle = GetWindowLongA(hWnd, GWL_EXSTYLE);
        
        // Match only visible main windows with class Avalonia and exact title "ATAS X"
        if (strcmp(title, "ATAS X") == 0 && strncmp(className, "Avalonia-", 9) == 0) {
            log_message("Evaluating ATAS window HWND=%p | style=0x%08lX | exStyle=0x%08lX\n", hWnd, style, exStyle);
            if ((style & WS_VISIBLE) && !(style & WS_CHILD) && !(exStyle & WS_EX_TOOLWINDOW)) {
                if (g_atas_count < 10) {
                    g_atas_windows[g_atas_count] = hWnd;
                    
                    int initial_monitor = 0;
                    if (g_monitor_count > 0) {
                        initial_monitor = g_atas_count % g_monitor_count;
                    }
                    g_window_monitors[g_atas_count] = initial_monitor; // Initial guess matching logical order
                    found_idx = g_atas_count;
                    log_message("Matched main window HWND=%p at index %d (Default monitor %d)\n", hWnd, found_idx, g_window_monitors[found_idx]);
                    
                    // Subclass the window to intercept SendMessage messages directly
                    g_orig_WndProcs[found_idx] = (WNDPROC)SetWindowLongPtrW(hWnd, GWLP_WNDPROC, (LONG_PTR)Hooked_WndProc);
                    log_message("Subclassed window HWND=%p\n", hWnd);
                    
                    g_atas_count++;
                }
            } else {
                log_message("Rejected ATAS window HWND=%p (visible=%d, child=%d, toolwindow=%d)\n",
                            hWnd, (style & WS_VISIBLE) != 0, (style & WS_CHILD) != 0, (exStyle & WS_EX_TOOLWINDOW) != 0);
            }
        }
    }
    LeaveCriticalSection(&g_cs_window_tracker);
    return found_idx;
}

// Redirect mouse messages to the dragging source window with mapped client coordinates
void redirect_mouse_message(LPMSG lpMsg) {
    if (lpMsg && (lpMsg->message >= WM_MOUSEFIRST && lpMsg->message <= WM_MOUSELAST)) {
        if (g_main_window_capture != NULL) {
            HWND captureWnd = g_main_window_capture;
            if (lpMsg->hwnd != captureWnd) {
                POINT pt = lpMsg->pt; // Global screen cursor coordinates
                ScreenToClient(captureWnd, &pt);
                
                lpMsg->hwnd = captureWnd;
                lpMsg->lParam = MAKELPARAM(pt.x, pt.y);
            }
        }
    }
}

// Hooked wrappers (we just call standard untouched Win32 APIs after our overrides)
extern "C" BOOL WINAPI Hooked_SetWindowPos(HWND hWnd, HWND hWndInsertAfter, int X, int Y, int cx, int cy, UINT uFlags) {
    if (X >= -150 && X <= -50 && Y >= -150 && Y <= -50) {
        X = -2000;
        Y = -2000;
    } else {
        int idx = get_atas_window_index(hWnd);
        if (idx >= 0) {
            // Keep the window aligned to its detected monitor bounds
            int monitor = g_window_monitors[idx];
            EnterCriticalSection(&g_cs_window_tracker);
            if (monitor < g_monitor_count) {
                X = g_monitors[monitor].rect.left;
                Y = g_monitors[monitor].rect.top;
                if (uFlags & SWP_NOMOVE) {
                    uFlags &= ~SWP_NOMOVE;
                }
            }
            LeaveCriticalSection(&g_cs_window_tracker);
        }
    }
    if (g_orig_SetWindowPos) {
        return g_orig_SetWindowPos(hWnd, hWndInsertAfter, X, Y, cx, cy, uFlags);
    }
    return ::SetWindowPos(hWnd, hWndInsertAfter, X, Y, cx, cy, uFlags);
}

extern "C" HDWP WINAPI Hooked_DeferWindowPos(HDWP hWinPosInfo, HWND hWnd, HWND hWndInsertAfter, int x, int y, int cx, int cy, UINT uFlags) {
    if (x >= -150 && x <= -50 && y >= -150 && y <= -50) {
        x = -2000;
        y = -2000;
    } else {
        int idx = get_atas_window_index(hWnd);
        if (idx >= 0) {
            int monitor = g_window_monitors[idx];
            EnterCriticalSection(&g_cs_window_tracker);
            if (monitor < g_monitor_count) {
                x = g_monitors[monitor].rect.left;
                y = g_monitors[monitor].rect.top;
                if (uFlags & SWP_NOMOVE) {
                    uFlags &= ~SWP_NOMOVE;
                }
            }
            LeaveCriticalSection(&g_cs_window_tracker);
        }
    }
    if (g_orig_DeferWindowPos) {
        return g_orig_DeferWindowPos(hWinPosInfo, hWnd, hWndInsertAfter, x, y, cx, cy, uFlags);
    }
    return ::DeferWindowPos(hWinPosInfo, hWnd, hWndInsertAfter, x, y, cx, cy, uFlags);
}

// Hook GetCapture to fake mouse capture during dragging even when focus is lost
extern "C" HWND WINAPI Hooked_GetCapture(VOID) {
    HWND result = NULL;
    if (g_orig_GetCapture) {
        result = g_orig_GetCapture();
    } else {
        result = ::GetCapture();
    }
    
    // Only fake capture if a main window drag is actively registered and mouse is held
    if (result == NULL && g_main_window_capture != NULL && 
        ((GetAsyncKeyState(VK_LBUTTON) & 0x8000) || (GetAsyncKeyState(VK_RBUTTON) & 0x8000))) {
        result = g_main_window_capture;
    }
    return result;
}

// Hook SetCapture to detect when the main window requests mouse grab for DnD
extern "C" HWND WINAPI Hooked_SetCapture(HWND hWnd) {
    int idx = get_atas_window_index(hWnd);
    if (idx >= 0) {
        g_main_window_capture = hWnd;
        log_message("Drag start detected: SetCapture on main window HWND=%p\n", hWnd);
    } else {
        g_main_window_capture = NULL;
    }
    
    if (g_orig_SetCapture) {
        return g_orig_SetCapture(hWnd);
    }
    return ::SetCapture(hWnd);
}

// Hook ReleaseCapture to reset active drag state when DnD ends
extern "C" BOOL WINAPI Hooked_ReleaseCapture(VOID) {
    log_message("Drag release: ReleaseCapture called\n");
    g_main_window_capture = NULL;
    
    if (g_orig_ReleaseCapture) {
        return g_orig_ReleaseCapture();
    }
    return ::ReleaseCapture();
}

// Hook GetMessageW to swallow drag cancellation and redirect mouse input
extern "C" BOOL WINAPI Hooked_GetMessageW(LPMSG lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax) {
    BOOL result = FALSE;
    if (g_orig_GetMessageW) {
        result = g_orig_GetMessageW(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax);
    } else {
        result = ::GetMessageW(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax);
    }
    
    if (result && lpMsg) {
        if (g_main_window_capture != NULL && (lpMsg->message == WM_CAPTURECHANGED || lpMsg->message == WM_CANCELMODE) &&
            ((GetAsyncKeyState(VK_LBUTTON) & 0x8000) || (GetAsyncKeyState(VK_RBUTTON) & 0x8000))) {
            lpMsg->message = WM_NULL; // Discard cancel message
        } else {
            redirect_mouse_message(lpMsg);
        }
    }
    return result;
}

// Hook PeekMessageW to swallow drag cancellation and redirect mouse input
extern "C" BOOL WINAPI Hooked_PeekMessageW(LPMSG lpMsg, HWND hWnd, UINT wMsgFilterMin, UINT wMsgFilterMax, UINT wRemoveMsg) {
    BOOL result = FALSE;
    if (g_orig_PeekMessageW) {
        result = g_orig_PeekMessageW(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax, wRemoveMsg);
    } else {
        result = ::PeekMessageW(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax, wRemoveMsg);
    }
    
    if (result && lpMsg) {
        if (g_main_window_capture != NULL && (lpMsg->message == WM_CAPTURECHANGED || lpMsg->message == WM_CANCELMODE) &&
            ((GetAsyncKeyState(VK_LBUTTON) & 0x8000) || (GetAsyncKeyState(VK_RBUTTON) & 0x8000))) {
            lpMsg->message = WM_NULL; // Discard cancel message
        } else {
            redirect_mouse_message(lpMsg);
        }
    }
    return result;
}

// Detoured LdrGetProcedureAddress from ntdll.dll to redirect procedure resolves
extern "C" NTSTATUS WINAPI Hooked_LdrGetProcedureAddress(HMODULE hModule, const ANSI_STRING* name, WORD ordinal, void** address) {
    // Thread-safe call to the original LdrGetProcedureAddress via our trampoline
    typedef NTSTATUS(WINAPI* LdrGetProcedureAddress_t)(HMODULE, const ANSI_STRING*, WORD, void**);
    NTSTATUS status = ((LdrGetProcedureAddress_t)g_trampoline_LdrGetProcedureAddress)(hModule, name, ordinal, address);

    if (status == 0 && name && name->Buffer) {
        if (strcmp(name->Buffer, "SetWindowPos") == 0) {
            log_message("Redirected LdrGetProcedureAddress for SetWindowPos\n");
            *address = (void*)Hooked_SetWindowPos;
        }
        else if (strcmp(name->Buffer, "DeferWindowPos") == 0) {
            log_message("Redirected LdrGetProcedureAddress for DeferWindowPos\n");
            *address = (void*)Hooked_DeferWindowPos;
        }
        else if (strcmp(name->Buffer, "GetMessageW") == 0) {
            log_message("Redirected LdrGetProcedureAddress for GetMessageW\n");
            *address = (void*)Hooked_GetMessageW;
        }
        else if (strcmp(name->Buffer, "PeekMessageW") == 0) {
            log_message("Redirected LdrGetProcedureAddress for PeekMessageW\n");
            *address = (void*)Hooked_PeekMessageW;
        }
    }

    return status;
}

// Helper to hook API stubs in user32.dll atomically by overwriting the jump target pointer
void* hook_stub(void* func_addr, void* hook_func) {
    if (!func_addr) return NULL;
    BYTE* p = (BYTE*)func_addr;
    
    // Search for the absolute JMP instruction (0xFF 0x25) in the first 16 bytes of the stub
    for (int i = 0; i < 16; i++) {
        if (p[i] == 0xFF && p[i+1] == 0x25) {
            // Extrapolate the RIP-relative offset address from the instruction
            int32_t offset = *(int32_t*)&p[i+2];
            void** ptr_addr = (void**)(p + i + 6 + offset);
            
            // Overwrite the jump target pointer atomically
            DWORD oldProtect;
            VirtualProtect(ptr_addr, sizeof(void*), PAGE_READWRITE, &oldProtect);
            void* orig = *ptr_addr;
            *ptr_addr = hook_func;
            VirtualProtect(ptr_addr, sizeof(void*), oldProtect, &oldProtect);
            
            return orig;
        }
    }
    return NULL;
}

void install_all_hooks() {
    InitializeCriticalSection(&g_cs_window_tracker);
    query_monitors();
    
    HMODULE hNtdll = GetModuleHandleA("ntdll.dll");
    if (!hNtdll) return;
    
    void* target_addr = (void*)GetProcAddress(hNtdll, "LdrGetProcedureAddress");
    if (!target_addr) return;
    
    // Verify that the prologue matches what we expect (for safety)
    BYTE expected_prologue[16] = {
        0x55, 0x41, 0x57, 0x41, 0x56, 0x41, 0x55, 0x41, 0x54, 0x57, 0x56, 0x53, 0x48, 0x83, 0xEC, 0x58
    };
    if (memcmp(target_addr, expected_prologue, 16) != 0) {
        log_message("Error: LdrGetProcedureAddress prologue mismatch! Aborting hook.\n");
        return;
    }
    
    // Allocate memory for the thread-safe static trampoline
    g_trampoline_LdrGetProcedureAddress = VirtualAlloc(NULL, 32, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if (!g_trampoline_LdrGetProcedureAddress) {
        log_message("Error: VirtualAlloc for trampoline failed.\n");
        return;
    }
    
    // Construct the trampoline
    memcpy(g_trampoline_LdrGetProcedureAddress, expected_prologue, 16);
    
    BYTE jump_back[14] = {
        0xFF, 0x25, 0x00, 0x00, 0x00, 0x00, 
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
    };
    uint64_t return_addr = (uint64_t)target_addr + 16;
    memcpy(&jump_back[6], &return_addr, 8);
    memcpy((BYTE*)g_trampoline_LdrGetProcedureAddress + 16, jump_back, 14);
    
    // Apply the detour hook to LdrGetProcedureAddress entry point
    DWORD oldProtect;
    VirtualProtect(target_addr, 16, PAGE_EXECUTE_READWRITE, &oldProtect);
    
    BYTE jump_to_hook[14] = {
        0xFF, 0x25, 0x00, 0x00, 0x00, 0x00, 
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
    };
    uint64_t hook_addr = (uint64_t)Hooked_LdrGetProcedureAddress;
    memcpy(&jump_to_hook[6], &hook_addr, 8);
    
    memcpy(target_addr, jump_to_hook, 14);
    ((BYTE*)target_addr)[14] = 0x90;
    ((BYTE*)target_addr)[15] = 0x90;
    
    VirtualProtect(target_addr, 16, oldProtect, &oldProtect);
    log_message("LdrGetProcedureAddress thread-safe hook installed successfully!\n");
    
    // Pre-resolve original pointers for window functions
    HMODULE hUser32 = LoadLibraryA("user32.dll");
    if (hUser32) {
        typedef NTSTATUS(WINAPI* LdrGetProcedureAddress_t)(HMODULE, const ANSI_STRING*, WORD, void**);
        LdrGetProcedureAddress_t orig_ldr = (LdrGetProcedureAddress_t)g_trampoline_LdrGetProcedureAddress;
        
        ANSI_STRING name;
        
        name.Buffer = "SetWindowPos";
        name.Length = strlen(name.Buffer);
        name.MaximumLength = name.Length + 1;
        orig_ldr(hUser32, &name, 0, (void**)&g_orig_SetWindowPos);
        
        name.Buffer = "DeferWindowPos";
        name.Length = strlen(name.Buffer);
        name.MaximumLength = name.Length + 1;
        orig_ldr(hUser32, &name, 0, (void**)&g_orig_DeferWindowPos);
        
        name.Buffer = "GetMessageW";
        name.Length = strlen(name.Buffer);
        name.MaximumLength = name.Length + 1;
        orig_ldr(hUser32, &name, 0, (void**)&g_orig_GetMessageW);
        
        name.Buffer = "PeekMessageW";
        name.Length = strlen(name.Buffer);
        name.MaximumLength = name.Length + 1;
        orig_ldr(hUser32, &name, 0, (void**)&g_orig_PeekMessageW);
        
        // Dynamically hook SetCapture, ReleaseCapture, and GetCapture stubs in user32.dll
        void* pSetCapture = (void*)GetProcAddress(hUser32, "SetCapture");
        void* pReleaseCapture = (void*)GetProcAddress(hUser32, "ReleaseCapture");
        void* pGetCapture = (void*)GetProcAddress(hUser32, "GetCapture");
        
        g_orig_SetCapture = (SetCapture_t)hook_stub(pSetCapture, (void*)Hooked_SetCapture);
        g_orig_ReleaseCapture = (ReleaseCapture_t)hook_stub(pReleaseCapture, (void*)Hooked_ReleaseCapture);
        g_orig_GetCapture = (GetCapture_t)hook_stub(pGetCapture, (void*)Hooked_GetCapture);
        
        log_message("Hooked SetCapture, ReleaseCapture, and GetCapture stubs successfully!\n");
    }
}

extern "C" __declspec(dllexport) void Dummy() {}

extern "C" BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    if (fdwReason == DLL_PROCESS_ATTACH) {
        FILE* f = fopen("C:\\window_hider_hook.log", "w");
        if (f) fclose(f);
        log_message("DLL loaded successfully!\n");
        install_all_hooks();
    }
    return TRUE;
}
