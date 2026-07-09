#include <windows.h>

// Ultra-minimal Win32 dummy process.
// No console window, no allocations — just an infinite kernel wait.
// Subsystem is set to WINDOWS via CMake (WIN32_EXECUTABLE TRUE).

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    (void)hInstance;
    (void)hPrevInstance;
    (void)lpCmdLine;
    (void)nCmdShow;

    // Sleep infinitely — zero CPU, zero wakeups, zero heap allocations.
    // The process will be terminated externally via TerminateProcess/SIGTERM.
    Sleep(INFINITE);

    return 0;
}
