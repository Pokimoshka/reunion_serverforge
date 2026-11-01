# =============================================================================
# CMake toolchain file for cross-compiling ReUnion to Windows (MinGW-w64)
# Usage: cmake -DCMAKE_TOOLCHAIN_FILE=cmake/Toolchain-mingw-w64.cmake ..
# =============================================================================

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_VERSION 10.0)

# Cross-compiler prefix
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)

# Target architecture
set(CMAKE_C_COMPILER_TARGET x86_64-w64-mingw32)
set(CMAKE_CXX_COMPILER_TARGET x86_64-w64-mingw32)

# Search for programs in the cross-compiler environment
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# Windows-specific definitions
add_compile_definitions(
    WIN32
    _WINDOWS
    _USRDLL
    REUNION_EXPORTS
    NOMINMAX
    NDEBUG
    _GLIBCXX_USE_CXX11_ABI=0
)

# Disable the problematic Linux compatibility macros that conflict with MinGW
add_compile_definitions(
    _CRT_SECURE_NO_WARNINGS
    _CRT_NONSTDC_NO_DEPRECATE
)

# Compiler flags for Windows
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -s -fno-exceptions -fno-rtti -fvisibility=hidden -fvisibility-inlines-hidden -Wall -Wno-unknown-pragmas -Wno-write-strings -fno-builtin -Wno-strict-aliasing -fcf-protection=none")

# Linker flags for Windows DLL
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -s -static-libgcc -static-libstdc++ -Wl,--allow-multiple-definition")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -s -static-libgcc -static-libstdc++ -Wl,--allow-multiple-definition -Wl,--output-def,reunion.def")

# Output as DLL
set(CMAKE_SHARED_LIBRARY_PREFIX "")
set(CMAKE_SHARED_LIBRARY_SUFFIX ".dll")
