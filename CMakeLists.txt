## 项目构建检查 -------------------------------------------------------------------------------------
cmake_minimum_required(VERSION 3.20)
get_filename_component(WCH_BSP_DIR "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
if(NOT DEFINED WCH_ARCH)
    message(FATAL_ERROR
        "ch32x035-bsp: WCH_ARCH is not defined.\n"
        "  Must configure with BSP toolchain file, e.g.\n"
        "  cmake -DCMAKE_TOOLCHAIN_FILE=<bsp>/cmake/toolchain-riscv-wch.cmake ...")
endif()

## 组件引入 -----------------------------------------------------------------------------------------
include(${WCH_BSP_DIR}/cmake/ch32x035-bsp.cmake)

# bsp静态库 -----------------------------------------------------------------------------------------
add_library(wch_periph STATIC
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
)

## bsp库头文件 --------------------------------------------------------------------------------------
target_include_directories(wch_periph PUBLIC ${WCH_BSP_DIR}/inc)

## bsp库编译参数 ------------------------------------------------------------------------------------
set(_contract_compile
    "-march=${WCH_ARCH}"
    "-mabi=${WCH_ABI}"
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

## bsp库链接参数 ------------------------------------------------------------------------------------
target_link_options(wch_periph INTERFACE
    "-march=${WCH_ARCH}"
    "-mabi=${WCH_ABI}"
    -mcmodel=medany
    -msmall-data-limit=8
    -msave-restore
    -Xlinker --gc-sections)
target_link_libraries(wch_periph INTERFACE m)
