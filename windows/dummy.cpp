#include <windows.h>
#include <shellapi.h>

#define WM_TRAY_MESSAGE   (WM_USER + 1)
#define ID_TRAY_TOGGLE    1001
#define ID_TRAY_EXIT      1002

static wchar_t g_szGameName[256] = L"Orby Game Window";
static NOTIFYICONDATAW g_nid = { 0 };
static HFONT g_hFontTitle = NULL;
static HFONT g_hFontGame = NULL;
static HFONT g_hFontText = NULL;

static const wchar_t* findSubstringW(const wchar_t* str, const wchar_t* sub) {
    if (!str || !sub) return NULL;
    size_t subLen = wcslen(sub);
    while (*str) {
        if (wcsncmp(str, sub, subLen) == 0)
            return str;
        str++;
    }
    return NULL;
}

static void toggleWindow(HWND hWnd) {
    if (IsWindowVisible(hWnd)) {
        ShowWindow(hWnd, SW_HIDE);
    } else {
        ShowWindow(hWnd, SW_SHOW);
        ShowWindow(hWnd, SW_RESTORE);
        SetForegroundWindow(hWnd);
    }
}

static LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
    switch (message) {
    case WM_CREATE: {
        // Create Segoe UI fonts
        g_hFontTitle = CreateFontW(22, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
                                   DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                                   CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
        g_hFontGame = CreateFontW(17, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                                  DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                                  CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
        g_hFontText = CreateFontW(14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                                  DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                                  CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");

        HWND hTitle = CreateWindowExW(0, L"STATIC", L"Orby - Game Presence Spoofer",
                                      WS_VISIBLE | WS_CHILD | SS_CENTER,
                                      10, 16, 395, 26, hWnd, NULL, NULL, NULL);

        HWND hGame = CreateWindowExW(0, L"STATIC", g_szGameName,
                                     WS_VISIBLE | WS_CHILD | SS_CENTER,
                                     10, 48, 395, 24, hWnd, NULL, NULL, NULL);

        HWND hSub = CreateWindowExW(0, L"STATIC",
                                    L"Simulating background game process for Discord Quests.\nYou can minimize this window to the tray or keep it open.",
                                    WS_VISIBLE | WS_CHILD | SS_CENTER,
                                    15, 84, 385, 45, hWnd, NULL, NULL, NULL);

        if (g_hFontTitle) SendMessageW(hTitle, WM_SETFONT, (WPARAM)g_hFontTitle, TRUE);
        if (g_hFontGame)  SendMessageW(hGame,  WM_SETFONT, (WPARAM)g_hFontGame,  TRUE);
        if (g_hFontText)  SendMessageW(hSub,   WM_SETFONT, (WPARAM)g_hFontText,  TRUE);

        // System Tray Icon
        g_nid.cbSize = sizeof(NOTIFYICONDATAW);
        g_nid.hWnd = hWnd;
        g_nid.uID = 1;
        g_nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
        g_nid.uCallbackMessage = WM_TRAY_MESSAGE;
        g_nid.hIcon = LoadIcon(NULL, IDI_APPLICATION);
        wcsncpy_s(g_nid.szTip, g_szGameName, 127);
        Shell_NotifyIconW(NIM_ADD, &g_nid);
        break;
    }

    case WM_TRAY_MESSAGE: {
        if (lParam == WM_RBUTTONUP) {
            POINT cur;
            GetCursorPos(&cur);
            HMENU hMenu = CreatePopupMenu();
            InsertMenuW(hMenu, 0, MF_BYPOSITION | MF_STRING, ID_TRAY_TOGGLE,
                        IsWindowVisible(hWnd) ? L"Hide" : L"Show");
            InsertMenuW(hMenu, 1, MF_BYPOSITION | MF_SEPARATOR, 0, NULL);
            InsertMenuW(hMenu, 2, MF_BYPOSITION | MF_STRING, ID_TRAY_EXIT, L"Exit");
            SetForegroundWindow(hWnd);
            TrackPopupMenu(hMenu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, cur.x, cur.y, 0, hWnd, NULL);
            DestroyMenu(hMenu);
        } else if (lParam == WM_LBUTTONDBLCLK) {
            toggleWindow(hWnd);
        }
        break;
    }

    case WM_COMMAND: {
        if (LOWORD(wParam) == ID_TRAY_TOGGLE) {
            toggleWindow(hWnd);
        } else if (LOWORD(wParam) == ID_TRAY_EXIT) {
            DestroyWindow(hWnd);
        }
        break;
    }

    case WM_CTLCOLORSTATIC: {
        HDC hdcStatic = (HDC)wParam;
        SetBkMode(hdcStatic, TRANSPARENT);
        return (LRESULT)GetStockObject(COLOR_WINDOW + 1);
    }

    case WM_CLOSE: {
        // Minimize to tray instead of quitting unexpectedly
        ShowWindow(hWnd, SW_HIDE);
        return 0;
    }

    case WM_DESTROY: {
        Shell_NotifyIconW(NIM_DELETE, &g_nid);
        if (g_hFontTitle) DeleteObject(g_hFontTitle);
        if (g_hFontGame)  DeleteObject(g_hFontGame);
        if (g_hFontText)  DeleteObject(g_hFontText);
        PostQuitMessage(0);
        break;
    }

    default:
        return DefWindowProcW(hWnd, message, wParam, lParam);
    }
    return 0;
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    (void)hPrevInstance;
    (void)lpCmdLine;
    (void)nCmdShow;

    // Parse --title "<game_name>" from Unicode command line
    LPCWSTR fullCmd = GetCommandLineW();
    const wchar_t* titleFlag = L"--title";
    const wchar_t* pos = findSubstringW(fullCmd, titleFlag);

    if (pos) {
        pos += wcslen(titleFlag);
        while (*pos == L' ') pos++;

        if (*pos == L'"') {
            pos++; // skip opening quote
            int i = 0;
            while (*pos != L'"' && *pos != L'\0' && i < 255) {
                g_szGameName[i++] = *pos++;
            }
            g_szGameName[i] = L'\0';
        } else {
            int i = 0;
            while (*pos != L' ' && *pos != L'\0' && i < 255) {
                g_szGameName[i++] = *pos++;
            }
            g_szGameName[i] = L'\0';
        }
    }

    const wchar_t CLASS_NAME[] = L"OrbyGameWindow";

    WNDCLASSW wc = { 0 };
    wc.lpfnWndProc   = WndProc;
    wc.hInstance     = hInstance;
    wc.lpszClassName = CLASS_NAME;
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wc.hIcon         = LoadIcon(NULL, IDI_APPLICATION);
    RegisterClassW(&wc);

    // Create a visible top-level window titled with the game's name.
    // Discord detects active games via EnumWindows + GetWindowTextW on visible windows.
    HWND hWnd = CreateWindowExW(
        0,
        CLASS_NAME,
        g_szGameName,
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
        CW_USEDEFAULT, CW_USEDEFAULT,
        425, 200,
        NULL, NULL, hInstance, NULL
    );

    if (!hWnd) return 0;

    // Show and update window so it is immediately visible to Discord's scanner
    ShowWindow(hWnd, SW_SHOWNORMAL);
    UpdateWindow(hWnd);

    MSG msg = { 0 };
    while (GetMessageW(&msg, NULL, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    return (int)msg.wParam;
}
