cmake_minimum_required(VERSION 3.16)
project(Orby VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Network)

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
    PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network
)

# ── Release optimization flags for main executable ──
# Use generator expressions for MSVC multi-config compatibility
if(MSVC)
    target_compile_options(appOrby PRIVATE
        $<$<CONFIG:Release>:/O2>
    )
else()
    target_compile_options(appOrby PRIVATE
        $<$<CONFIG:Release>:-O2 -ffunction-sections -fdata-sections>
    )
    target_link_options(appOrby PRIVATE
        $<$<CONFIG:Release>:-Wl,--gc-sections -s>
    )
endif()

# ── Platform targets ──
if(WIN32)
    set_target_properties(appOrby PROPERTIES
        OUTPUT_NAME "Orby-Windows"
        WIN32_EXECUTABLE FALSE
    )

    # ── Minimal dummy executable ──
    add_executable(dummy WIN32 windows/dummy.cpp)
    set_target_properties(dummy PROPERTIES
        WIN32_EXECUTABLE TRUE
    )

    # Size-optimized compiler flags for dummy
    if(MSVC)
        target_compile_options(dummy PRIVATE $<$<CONFIG:Release>:/Os>)
    else()
        target_compile_options(dummy PRIVATE -Os -fno-exceptions -fno-rtti -ffunction-sections -fdata-sections)
        target_link_options(dummy PRIVATE -Wl,--gc-sections -s)
    endif()

else()
    set_target_properties(appOrby PROPERTIES
        OUTPUT_NAME "orby"
    )
endif()
