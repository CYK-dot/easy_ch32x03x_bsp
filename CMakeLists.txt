# ch32x035-bsp/CMakeLists.txt - CH32X035 BSP 基座（被应用工程 add_subdirectory 引用）
# 用法详见 README.md

cmake_minimum_required(VERSION 3.20)

get_filename_component(WCH_BSP_DIR "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
if(NOT DEFINED WCH_ARCH)
    message(FATAL_ERROR
        "ch32x035-bsp: WCH_ARCH is not defined.\n"
        "  Must configure with BSP toolchain file, e.g.\n"
        "  cmake -DCMAKE_TOOLCHAIN_FILE=<bsp>/cmake/toolchain-riscv-wch.cmake ...")
endif()

include(${WCH_BSP_DIR}/cmake/ch32x035-bsp.cmake)

# ---- 静态库 libwch_periph.a -------------------------------------------------
add_library(wch_periph STATIC
    ${WCH_BSP_DIR}/src/cpu/startup_ch32x035.S
    ${WCH_BSP_DIR}/src/cpu/system_ch32x035.c
    ${WCH_BSP_DIR}/src/cpu/core_riscv.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_adc.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_awu.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_dbgmcu.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_dma.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_exti.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_flash.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_gpio.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_i2c.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_iwdg.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_misc.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_opa.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_pwr.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_rcc.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_spi.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_tim.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_usart.c
    ${WCH_BSP_DIR}/src/peri/ch32x035_wwdg.c
    ${WCH_BSP_DIR}/src/debug/debug.c
)

target_include_directories(wch_periph PUBLIC ${WCH_BSP_DIR}/inc)

# 契约选项: 编译侧 PRIVATE+INTERFACE（与官方 StdPeriphDriver 对齐）
# 与 ch57x-bsp 的差异: 无 -DDEBUG=0（ch32x035 debug.h 用 #ifndef DEBUG 默认 DEBUG_UART1），
#                      无 --param=highcode-gen-section-name=1（CH32X035 无 highcode 段）
# 优化等级: 外部可定制（决策表: 库的优化等级可外部定制），默认 -Os 对齐官方示例构建
set(WCH_PERIPH_OPT "-Os"
    CACHE STRING "wch_periph optimization level (e.g. -Os, -O2, empty for none)")
set(_contract_compile
    "-march=${WCH_ARCH}"
    "-mabi=${WCH_ABI}"
    ${WCH_PERIPH_OPT}
    -mcmodel=medany
    -msmall-data-limit=8
    -msave-restore
    -ffunction-sections
    -fdata-sections
    -fno-common
    -std=gnu99
    -fsigned-char)
target_compile_options(wch_periph PRIVATE ${_contract_compile})
target_compile_options(wch_periph INTERFACE ${_contract_compile})

# 契约选项: 链接侧（--gc-sections 与 function-sections 配套；-lm 对齐官方）
target_link_options(wch_periph INTERFACE
    "-march=${WCH_ARCH}"
    "-mabi=${WCH_ABI}"
    -mcmodel=medany
    -msmall-data-limit=8
    -msave-restore
    -Xlinker --gc-sections)
target_link_libraries(wch_periph INTERFACE m)
