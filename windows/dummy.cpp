#include <windows.h>

int WINAPI WinMain(HINSTANCE, HINSTANCE, LPSTR, int) {
    // Keep the process alive indefinitely with minimal resource usage
    while (true) {
        Sleep(1000000);
    }
    return 0;
}
