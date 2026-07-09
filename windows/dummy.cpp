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

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    (void)hPrevInstance;
    (void)lpCmdLine;
    (void)nCmdShow;

    // Register a basic window class
    const char CLASS_NAME[] = "OrbyDummyClass";
    
    WNDCLASS wc = { };
    wc.lpfnWndProc   = WindowProc;
    wc.hInstance     = hInstance;
    wc.lpszClassName = CLASS_NAME;

    RegisterClass(&wc);

    // Create a hidden window. Discord uses EnumWindows -> GetWindowThreadProcessId 
    // to find running games. Without a window, Discord ignores the process.
    HWND hwnd = CreateWindowEx(
        0,                              // Optional window styles
        CLASS_NAME,                     // Window class
        "Orby Dummy Game Window",       // Window text
        WS_OVERLAPPEDWINDOW,            // Window style (standard)
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
        NULL,       // Parent window    
        NULL,       // Menu
        hInstance,  // Instance handle
        NULL        // Additional application data
    );

    if (hwnd == NULL) {
        return 0;
    }

    // Do NOT call ShowWindow(hwnd, ...). The window remains completely invisible,
    // but the handle exists for Discord's EnumWindows scanner to find.

    // Run the standard message loop — uses zero CPU while waiting for messages.
    MSG msg = { };
    while (GetMessage(&msg, NULL, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return 0;
}
