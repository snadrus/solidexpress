# sxvoice: optional offline STT bridge over whisper.cpp (MIT).
# Always builds a small library. With SX_BUILD_VOICE=OFF (default), the API is a
# stub that returns error="voice STT not built".
#
# Enable whisper later:
#   1. Clone MIT whisper.cpp into thirdparty/whisper.cpp
#        git clone --depth 1 https://github.com/ggml-org/whisper.cpp.git thirdparty/whisper.cpp
#   2. Download tiny.en (do not commit weights):
#        mkdir -p tools/whisper
#        # e.g. from https://huggingface.co/ggerganov/whisper.cpp
#        # -> tools/whisper/ggml-tiny.en.bin
#   3. Configure with -DSX_BUILD_VOICE=ON
#
# whisper stays a separate target (not mixed into LGPL/GPL code).

set(SX_VOICE_HAS_WHISPER 0)
set(SX_WHISPER_DIR "${CMAKE_SOURCE_DIR}/thirdparty/whisper.cpp")

if(SX_BUILD_VOICE)
    if(EXISTS "${SX_WHISPER_DIR}/CMakeLists.txt")
        set(SX_VOICE_HAS_WHISPER 1)
        message(STATUS "sxvoice: building with whisper.cpp from ${SX_WHISPER_DIR}")

        set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
        set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
        set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
        # Keep whisper static; do not clobber this project's shared targets.
        set(_sx_saved_build_shared_libs "${BUILD_SHARED_LIBS}")
        set(BUILD_SHARED_LIBS OFF)
        add_subdirectory("${SX_WHISPER_DIR}" "${CMAKE_BINARY_DIR}/thirdparty/whisper.cpp" EXCLUDE_FROM_ALL)
        set(BUILD_SHARED_LIBS "${_sx_saved_build_shared_libs}")
        unset(_sx_saved_build_shared_libs)
    else()
        message(WARNING
            "SX_BUILD_VOICE=ON but ${SX_WHISPER_DIR} is missing. "
            "Building sxvoice stub only. Populate thirdparty/whisper.cpp to enable STT.")
    endif()
else()
    message(STATUS "sxvoice: stub only (SX_BUILD_VOICE=OFF)")
endif()

add_library(sxvoice STATIC src/voice_stt.cpp)
target_include_directories(sxvoice PUBLIC include)
target_compile_definitions(sxvoice
    PUBLIC SX_VOICE_HAS_WHISPER=${SX_VOICE_HAS_WHISPER}
    PRIVATE SX_WHISPER_DEFAULT_MODEL="${CMAKE_SOURCE_DIR}/tools/whisper/ggml-tiny.en.bin"
)

if(SX_VOICE_HAS_WHISPER)
    # Prefer the modern 'whisper' target; fall back to whisper::whisper if needed.
    if(TARGET whisper)
        target_link_libraries(sxvoice PRIVATE whisper)
    elseif(TARGET whisper::whisper)
        target_link_libraries(sxvoice PRIVATE whisper::whisper)
    else()
        message(FATAL_ERROR "sxvoice: whisper.cpp was added but no 'whisper' CMake target found")
    endif()
endif()

if(SX_BUILD_TESTS)
    add_executable(sxvoice_tests tests/test_main.cpp tests/test_voice_stt.cpp)
    target_include_directories(sxvoice_tests PRIVATE ${CMAKE_SOURCE_DIR}/thirdparty/catch2)
    target_link_libraries(sxvoice_tests PRIVATE sxvoice)
    enable_testing()
    add_test(NAME sxvoice_tests COMMAND sxvoice_tests)
endif()
