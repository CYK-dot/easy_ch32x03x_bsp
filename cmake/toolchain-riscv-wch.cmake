set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR riscv)

if(DEFINED ENV{WCH_TOOLCHAIN_ROOT} AND NOT "$ENV{WCH_TOOLCHAIN_ROOT}" STREQUAL "")
    set(WCH_TOOLCHAIN_ROOT "$ENV{WCH_TOOLCHAIN_ROOT}"
        CACHE PATH "WCH RISC-V toolchain root directory (contains bin/)" FORCE)
else()
    message(FATAL_ERROR
        "toolchain-riscv-wch.cmake: environment variable WCH_TOOLCHAIN_ROOT is not set.\n"
        "  Set it to the WCH RISC-V GCC toolchain root directory (must contain bin/):\n"
        "  PowerShell: $env:WCH_TOOLCHAIN_ROOT=\"C:/01_Tools/riscv32-wch-elf-gcc\"\n"
        "  cmd       : set WCH_TOOLCHAIN_ROOT=C:/01_Tools/riscv32-wch-elf-gcc\n"
        "  bash      : export WCH_TOOLCHAIN_ROOT=C:/01_Tools/riscv32-wch-elf-gcc")
endif()
set(WCH_BIN "${WCH_TOOLCHAIN_ROOT}/bin")
set(WCH_TOOLCHAIN_PREFIX "riscv32-wch-elf-")

if(NOT EXISTS "${WCH_BIN}/${WCH_TOOLCHAIN_PREFIX}gcc.exe")
    message(FATAL_ERROR
        "toolchain-riscv-wch.cmake: toolchain not found.\n"
        "  Expected: ${WCH_BIN}/${WCH_TOOLCHAIN_PREFIX}gcc.exe\n"
        "  Check WCH_TOOLCHAIN_ROOT / WCH_TOOLCHAIN_PREFIX.")
endif()

set(CMAKE_C_COMPILER   "${WCH_BIN}/${WCH_TOOLCHAIN_PREFIX}gcc.exe")
set(CMAKE_ASM_COMPILER "${WCH_BIN}/${WCH_TOOLCHAIN_PREFIX}gcc.exe")
set(CMAKE_OBJCOPY      "${WCH_BIN}/${WCH_TOOLCHAIN_PREFIX}objcopy.exe")
set(CMAKE_OBJDUMP      "${WCH_BIN}/${WCH_TOOLCHAIN_PREFIX}objdump.exe")
set(CMAKE_SIZE         "${WCH_BIN}/${WCH_TOOLCHAIN_PREFIX}size.exe")

set(WCH_ARCH "rv32imacxw")
set(WCH_ABI "ilp32")

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
set(CMAKE_EXECUTABLE_SUFFIX ".elf")