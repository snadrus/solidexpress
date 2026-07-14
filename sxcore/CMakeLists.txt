# sxcore: GDExtension shared library bridging sxkernel to Godot.

file(GLOB SXCORE_SOURCES CONFIGURE_DEPENDS src/*.cpp)
add_library(sxcore SHARED ${SXCORE_SOURCES})
target_link_libraries(sxcore PRIVATE sxkernel sxvoice godot-cpp)
set_target_properties(sxcore PROPERTIES
    OUTPUT_NAME "sxcore"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/game/bin"
)
