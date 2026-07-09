#include <windows.h>

// Ultra-minimal Win32 dummy process.
// No CRT, no console, no allocations — just an infinite kernel wait.
// Compiled with /Os and /ENTRY:WinMainCRTStartup for smallest possible binary.
#pragma comment(linker, "/SUBSYSTEM:WINDOWS")

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    (void)hInstance;
    (void)hPrevInstance;
    (void)lpCmdLine;
    (void)nCmdShow;

    // Single kernel wait — zero CPU, zero wakeups, zero heap allocations.
    // The process will be terminated externally via TerminateProcess/SIGTERM.
    WaitForSingleObject(GetCurrentThread(), INFINITE);

    return 0;
}
