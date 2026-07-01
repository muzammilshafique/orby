cmake_minimum_required(VERSION 3.16)
project(Orby VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Network)

qt_standard_project_setup()

qt_add_executable(appOrby
    src/main.cpp
    src/ProcessSpoofer.h
    src/ProcessSpoofer.cpp
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

set_target_properties(appOrby PROPERTIES OUTPUT_NAME "Orby-Linux")
