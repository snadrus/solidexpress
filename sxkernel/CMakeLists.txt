# sxkernel: pure C++ modeling kernel. No Godot dependencies — headless testable.

set(SXKERNEL_SOURCES
    src/ids.cpp
    src/entity.cpp
    src/log.cpp
    src/cards.cpp
    src/document.cpp
    src/command.cpp
    src/commands_basic.cpp
    src/shape_utils.cpp
    src/tessellate.cpp
    src/pick.cpp
    src/sxp.cpp
)

add_library(sxkernel STATIC ${SXKERNEL_SOURCES})
target_include_directories(sxkernel PUBLIC include)
target_include_directories(sxkernel SYSTEM PUBLIC ${OpenCASCADE_INCLUDE_DIR})
target_link_libraries(sxkernel
    PUBLIC
        TKernel TKMath TKG2d TKG3d TKGeomBase TKBRep TKGeomAlgo TKTopAlgo
        TKPrim TKBO TKShHealing TKBool TKFillet TKOffset TKFeat TKMesh TKHLR
        TKXSBase TKDESTEP TKDEIGES TKDESTL
        miniz
        sx_json
)

if(SX_BUILD_TESTS)
    file(GLOB SXKERNEL_TEST_SOURCES tests/*.cpp)
    add_executable(sxkernel_tests ${SXKERNEL_TEST_SOURCES})
    target_include_directories(sxkernel_tests PRIVATE ${CMAKE_SOURCE_DIR}/thirdparty/catch2)
    target_link_libraries(sxkernel_tests PRIVATE sxkernel)
    enable_testing()
    add_test(NAME sxkernel_tests COMMAND sxkernel_tests)
endif()
