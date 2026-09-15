cmake_minimum_required(VERSION 3.16)
project(Orby VERSION 1.1.2 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 Network)

qt_standard_project_setup()

# ── Platform-specific source selection ──
if(WIN32)
    set(SPOOFER_SRC src/ProcessSpoofer_windows.cpp)
    set(ORBY_RC windows/orby.rc)
else()
    set(SPOOFER_SRC src/ProcessSpoofer_linux.cpp)
    set(ORBY_RC "")
endif()

# ── Main GUI executable ──
qt_add_executable(appOrby
    src/main.cpp
    src/ProcessSpoofer.h
    ${SPOOFER_SRC}
    src/DiscordApi.h
    src/DiscordApi.cpp
    src/TrayManager.h
    src/TrayManager.cpp
    ${ORBY_RC}
)

qt_add_resources(appOrby "app_icons"
    PREFIX "/"
    FILES
        icons/orby.png
        icons/orby.svg
        icons/orby-tray.svg
        icons/orby-tray-dark.svg
)

qt_add_resources(appOrby "app_fonts"
    PREFIX "/"
    FILES
        fonts/GoogleSansFlex.ttf
        fonts/MaterialSymbolsRounded.ttf
)

qt_add_qml_module(appOrby
    URI Orby
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

target_link_libraries(appOrby
    PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Network
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
        $<$<CONFIG:Release>:-Wl,--gc-sections>
    )
endif()

# ── Platform targets ──
if(WIN32)
    set_target_properties(appOrby PROPERTIES
        OUTPUT_NAME "Orby-Windows"
        WIN32_EXECUTABLE TRUE
    )

    # ── Minimal dummy executable with embedded icon ──
    add_executable(dummy WIN32 windows/dummy.cpp ${ORBY_RC})
    set_target_properties(dummy PROPERTIES
        WIN32_EXECUTABLE TRUE
    )
    target_link_libraries(dummy PRIVATE user32 gdi32 shell32)

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

# ── Installation rules (Linux / UNIX) ──
if(UNIX AND NOT APPLE)
    include(GNUInstallDirs)

    install(TARGETS appOrby
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )

    install(FILES linux/orby.desktop
        DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
    )

    install(FILES
        icons/orby.svg
        icons/orby-tray.svg
        icons/orby-tray-dark.svg
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
    )

    install(FILES icons/orby.png
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/256x256/apps
    )

    install(FILES LICENSE
        DESTINATION ${CMAKE_INSTALL_DATADIR}/licenses/orby
    )
endif()

# ── Packaging (CPack) ──
if(UNIX AND NOT APPLE)
    set(CPACK_PACKAGE_NAME "orby")
    set(CPACK_PACKAGE_VENDOR "Muzammil Shafique")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Safe Discord quest game process spoofer")
    set(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/muzammilshafique/orby")
    set(CPACK_PACKAGE_CONTACT "Muzammil Shafique <muzu@duck.com>")
    set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
    set(CPACK_RESOURCE_FILE_README "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
    set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")

    # Debian (.deb) packaging
    set(CPACK_DEB_COMPONENT_INSTALL OFF)
    set(CPACK_DEBIAN_PACKAGE_NAME "orby")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Muzammil Shafique <muzu@duck.com>")
    set(CPACK_DEBIAN_PACKAGE_SECTION "utils")
    set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
    set(CPACK_DEBIAN_PACKAGE_HOMEPAGE "https://github.com/muzammilshafique/orby")
    set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
    set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
    set(CPACK_DEBIAN_PACKAGE_DEPENDS "libc6, libqt6core6 (>= 6.2.0) | libqt6core6t64 (>= 6.2.0), libqt6gui6 | libqt6gui6t64, libqt6widgets6 | libqt6widgets6t64, libqt6qml6 | libqt6qml6t64, libqt6quick6 | libqt6quick6t64, libqt6quickcontrols2-6 | libqt6quickcontrols2-6t64, libqt6network6 | libqt6network6t64, qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-layouts, qml6-module-qtquick-window, qml6-module-qtquick-templates")

    include(CPack)
endif()

