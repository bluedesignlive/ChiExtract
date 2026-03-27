cmake_minimum_required(VERSION 3.16)
project(ChiExtract VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Qml)
find_package(PkgConfig REQUIRED)
pkg_check_modules(LIBARCHIVE REQUIRED libarchive)

add_executable(ChiExtract
    main.cpp
    archivemanager.h
    archivemanager.cpp
    resources.qrc
)

target_include_directories(ChiExtract PRIVATE ${LIBARCHIVE_INCLUDE_DIRS})
target_link_libraries(ChiExtract PRIVATE
    Qt6::Quick
    Qt6::Qml
    ${LIBARCHIVE_LIBRARIES}
)

install(TARGETS ChiExtract RUNTIME DESTINATION bin)
