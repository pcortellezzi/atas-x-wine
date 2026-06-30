#include <windows.h>
#include <stdio.h>
#include <wchar.h>
#include <stdarg.h>

void log_launcher(const char* format, ...) {
    FILE* f = fopen("C:\\atas_launcher.log", "a");
    if (f) {
        va_list args;
        va_start(args, format);
        vfprintf(f, format, args);
        va_end(args);
        fclose(f);
    }
}

int main(int argc, char* argv[]) {
    // Clear previous log
    FILE* f = fopen("C:\\atas_launcher.log", "w");
    if (f) fclose(f);

    log_launcher("--- atas_launcher started ---\n");
    const wchar_t* targetExe = L"C:\\Program Files\\ATAS X\\OFT.PlatformX.exe";
    if (GetFileAttributesW(targetExe) == INVALID_FILE_ATTRIBUTES) {
        log_launcher("OFT.PlatformX.exe not found, falling back to OFT.Platform.exe\n");
        targetExe = L"C:\\Program Files\\ATAS X\\OFT.Platform.exe";
    }
    const char* dllPath = "C:\\window_hider_hook.dll";

    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi;
    
    wchar_t cmdLine[4096] = { 0 };
    wcscpy(cmdLine, L"\"");
    wcscat(cmdLine, targetExe);
    wcscat(cmdLine, L"\"");
    
    for (int i = 1; i < argc; i++) {
        wcscat(cmdLine, L" ");
        int len = strlen(argv[i]);
        wchar_t* warg = new wchar_t[len + 1];
        mbstowcs(warg, argv[i], len + 1);
        wcscat(cmdLine, warg);
        delete[] warg;
    }

    log_launcher("Starting target process: %S\n", cmdLine);
    if (!CreateProcessW(NULL, cmdLine, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
        log_launcher("Error: CreateProcess failed (%d)\n", (int)GetLastError());
        return 1;
    }

    // Wait only 50ms - fast enough to inject before assembly load & window creation,
    // but long enough for process memory structures to stabilize.
    log_launcher("Process created with PID %d. Sleeping 50ms for loader init...\n", (int)pi.dwProcessId);
    Sleep(50);

    log_launcher("Allocating memory in target process...\n");
    int pathLen = strlen(dllPath) + 1;
    void* remoteMem = VirtualAllocEx(pi.hProcess, NULL, pathLen, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (!remoteMem) {
        log_launcher("Error: VirtualAllocEx failed (%d)\n", (int)GetLastError());
        TerminateProcess(pi.hProcess, 1);
        return 1;
    }

    log_launcher("Writing DLL path to target memory...\n");
    if (!WriteProcessMemory(pi.hProcess, remoteMem, dllPath, pathLen, NULL)) {
        log_launcher("Error: WriteProcessMemory failed (%d)\n", (int)GetLastError());
        VirtualFreeEx(pi.hProcess, remoteMem, 0, MEM_RELEASE);
        TerminateProcess(pi.hProcess, 1);
        return 1;
    }

    void* loadLibraryAddr = (void*)GetProcAddress(GetModuleHandleA("kernel32.dll"), "LoadLibraryA");
    if (!loadLibraryAddr) {
        log_launcher("Error: GetProcAddress for LoadLibraryA failed (%d)\n", (int)GetLastError());
        VirtualFreeEx(pi.hProcess, remoteMem, 0, MEM_RELEASE);
        TerminateProcess(pi.hProcess, 1);
        return 1;
    }

    log_launcher("Creating remote thread calling LoadLibraryA...\n");
    HANDLE hThread = CreateRemoteThread(pi.hProcess, NULL, 0, (LPTHREAD_START_ROUTINE)loadLibraryAddr, remoteMem, 0, NULL);
    if (!hThread) {
        log_launcher("Error: CreateRemoteThread failed (%d)\n", (int)GetLastError());
        VirtualFreeEx(pi.hProcess, remoteMem, 0, MEM_RELEASE);
        TerminateProcess(pi.hProcess, 1);
        return 1;
    }

    log_launcher("Waiting for remote thread to finish...\n");
    WaitForSingleObject(hThread, INFINITE);
    
    DWORD exitCode = 0;
    GetExitCodeThread(hThread, &exitCode);
    log_launcher("Remote thread finished. LoadLibraryA exit code (DLL handle) = %p\n", (void*)exitCode);
    
    CloseHandle(hThread);
    VirtualFreeEx(pi.hProcess, remoteMem, 0, MEM_RELEASE);

    if (exitCode == 0) {
        log_launcher("Warning: LoadLibraryA returned NULL! DLL Injection failed.\n");
        TerminateProcess(pi.hProcess, 1);
        return 1;
    }

    log_launcher("Injected successfully, waiting for ATAS process to exit...\n");
    WaitForSingleObject(pi.hProcess, INFINITE);

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    log_launcher("Target process exited. atas_launcher exiting.\n");
    return 0;
}
