# sxcore: GDExtension shared library bridging sxkernel to Godot.

add_library(sxcore SHARED
    src/register_types.cpp
    src/sx_document.cpp
)
target_link_libraries(sxcore PRIVATE sxkernel godot-cpp)
set_target_properties(sxcore PROPERTIES
    OUTPUT_NAME "sxcore"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/game/bin"
)
