cmake_minimum_required(VERSION 3.16)
project(Orby VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Network)

qt_standard_project_setup()

# ── Platform-specific source selection ──
if(WIN32)
    set(SPOOFER_SRC src/ProcessSpoofer_windows.cpp)
else()
    set(SPOOFER_SRC src/ProcessSpoofer_linux.cpp)
endif()

# ── Main GUI executable ──
qt_add_executable(appOrby
    src/main.cpp
    src/ProcessSpoofer.h
    ${SPOOFER_SRC}
    src/DiscordApi.h
    src/DiscordApi.cpp
)

qt_add_qml_module(appOrby
    URI Orby
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

target_link_libraries(appOrby
    PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Network
)

# ── Release optimization flags for main executable ──
if(CMAKE_BUILD_TYPE STREQUAL "Release" OR CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
    if(MSVC)
        target_compile_options(appOrby PRIVATE /O2 /GL)
        target_link_options(appOrby PRIVATE /LTCG /OPT:REF /OPT:ICF)
    else()
        target_compile_options(appOrby PRIVATE -O2 -ffunction-sections -fdata-sections)
        target_link_options(appOrby PRIVATE -Wl,--gc-sections -s)
    endif()
endif()

# ── Platform targets ──
if(WIN32)
    set_target_properties(appOrby PROPERTIES
        OUTPUT_NAME "Orby-Windows"
        WIN32_EXECUTABLE TRUE
    )

    # ── Ultra-minimal dummy executable ──
    add_executable(dummy WIN32 windows/dummy.cpp)
    set_target_properties(dummy PROPERTIES
        WIN32_EXECUTABLE TRUE
        RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
    )

    # Size-optimized compiler flags for dummy (smallest possible binary)
    if(MSVC)
        target_compile_options(dummy PRIVATE /Os /GS- /GL)
        target_link_options(dummy PRIVATE
            /LTCG
            /OPT:REF
            /OPT:ICF
            /ENTRY:WinMainCRTStartup
            /NODEFAULTLIB:libcmt
        )
    else()
        target_compile_options(dummy PRIVATE -Os -fno-exceptions -fno-rtti -ffunction-sections -fdata-sections)
        target_link_options(dummy PRIVATE -Wl,--gc-sections -s -nostdlib)
    endif()

else()
    set_target_properties(appOrby PROPERTIES
        OUTPUT_NAME "orby"
    )
endif()
