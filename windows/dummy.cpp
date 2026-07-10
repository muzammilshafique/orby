#include <windows.h>

// Ultra-minimal Win32 dummy process.
// No console window, no allocations — just an infinite kernel wait.
// Subsystem is set to WINDOWS via CMake (WIN32_EXECUTABLE TRUE).

LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    if (uMsg == WM_DESTROY) {
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

// Replace your WinMain in windows/dummy.cpp with this:
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    (void)hPrevInstance;
    (void)nCmdShow;

    const char CLASS_NAME[] = "OrbyDummyClass";
    WNDCLASS wc = { };
    wc.lpfnWndProc   = WindowProc;
    wc.hInstance     = hInstance;
    wc.lpszClassName = CLASS_NAME;
    RegisterClass(&wc);

    // Use the command line argument as the window title
    LPCSTR windowTitle = (lpCmdLine && lpCmdLine[0] != '\0') ? lpCmdLine : "Default Game Window";

    HWND hwnd = CreateWindowEx(
        0, CLASS_NAME, windowTitle, WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
        NULL, NULL, hInstance, NULL
    );

    if (hwnd == NULL) return 0;

    MSG msg = { };
    while (GetMessage(&msg, NULL, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    return 0;
}
