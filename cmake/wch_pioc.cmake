####################################################################################################
# @name add_wch_pioc_library
# @brief 添加一个运行在wchrisc8b上的cmake接口库，编译结果写入.c/.h中供宿主引用(target_link_libraries)
#
# @param target 对象名称，生成 ${target}.c和${target}.h，供宿主引用
# @param ASM    需要参与编译的asm文件
# @param INC    可选，额外的头文件目录
# @param OUTPUT_DIR 可选，生成目录, 默认 ${CMAKE_BINARY_DIR}/pioc/<target>
#
# @attention 仅支持 Windows 主机构建，且需要具有python3环境
####################################################################################################
function(add_wch_pioc_library target)
    set(_bsp "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/..")
    set(_asm_tool "${_bsp}/tools/pioc/WASM53B.EXE")
    set(_gen      "${_bsp}/tools/pioc/wch_pioc_gen.py")

    # ---- 参数解析与校验 ------------------------------------------------------
    cmake_parse_arguments(ARG "" "ASM;OUTPUT_DIR" "INC" ${ARGN})
    if(NOT ARG_ASM)
        message(FATAL_ERROR "add_wch_pioc_library(${target}): ASM <file> is required")
    endif()
    if(TARGET ${target})
        message(FATAL_ERROR "add_wch_pioc_library(${target}): target '${target}' already exists")
    endif()
    if(NOT CMAKE_HOST_WIN32)
        message(FATAL_ERROR
            "add_wch_pioc_library(${target}): WASM53B.EXE is a 32-bit Windows program.\n"
            "  PIOC could only be built on win32/win64")
    endif()
    if(NOT EXISTS "${_asm_tool}")
        message(FATAL_ERROR
            "add_wch_pioc_library(${target}): WASM53B.EXE missing in ${_bsp}/tools/pioc/")
    endif()
    if(NOT EXISTS "${_bsp}/src/cpu/chrisc8b/PIOC_INC.ASM")
        message(FATAL_ERROR
            "add_wch_pioc_library(${target}): builtin asm include missing: ${_bsp}/src/cpu/chrisc8b/PIOC_INC.ASM")
    endif()
    find_package(Python3 COMPONENTS Interpreter REQUIRED)

    set(_src "${ARG_OUTPUT_DIR}")
    if(NOT _src)
        set(_src "${CMAKE_BINARY_DIR}/pioc/${target}")
    endif()
    file(MAKE_DIRECTORY "${_src}")
    get_filename_component(_asm "${ARG_ASM}" ABSOLUTE)

    # ---- 1. 源文件进工作目录(WASM53B 只按文件名在当前目录找输入) ---------------
    set(_asm_src "${_src}/${target}.ASM")
    add_custom_command(
        OUTPUT "${_asm_src}"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_asm}" "${_asm_src}"
        DEPENDS "${_asm}"
        COMMENT "Copy PIOC source ${target}.ASM"
        VERBATIM)
    set(_inc_srcs "${_asm_src}")

    # ---- 2. 内置 PIOC_INC.ASM(用户 INC 显式提供同名文件时以用户为准) -----------
    set(_use_builtin TRUE)
    foreach(_inc ${ARG_INC})
        get_filename_component(_inc_target "${_inc}" NAME)
        if(_inc_target STREQUAL "PIOC_INC.ASM")
            set(_use_builtin FALSE)
        endif()
    endforeach()
    if(_use_builtin)
        set(_builtin_inc "${_src}/PIOC_INC.ASM")
        add_custom_command(
            OUTPUT "${_builtin_inc}"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_bsp}/src/cpu/chrisc8b/PIOC_INC.ASM" "${_builtin_inc}"
            DEPENDS "${_bsp}/src/cpu/chrisc8b/PIOC_INC.ASM"
            COMMENT "Copy builtin PIOC_INC.ASM"
            VERBATIM)
        list(APPEND _inc_srcs "${_builtin_inc}")
    endif()

    # ---- 3. 用户额外 INC 文件 -------------------------------------------------
    foreach(_inc ${ARG_INC})
        get_filename_component(_inc "${_inc}" ABSOLUTE)
        get_filename_component(_inc_target "${_inc}" NAME)
        set(_inc_out "${_src}/${_inc_target}")
        add_custom_command(
            OUTPUT "${_inc_out}"
            COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_inc}" "${_inc_out}"
            DEPENDS "${_inc}"
            COMMENT "Copy PIOC include ${_inc_target}"
            VERBATIM)
        list(APPEND _inc_srcs "${_inc_out}")
    endforeach()

    # ---- 4. WASM53B 汇编: .ASM -> .BIN/.LST -----------------------------------
    set(_bin "${_src}/${target}.BIN")
    set(_lst "${_src}/${target}.LST")
    add_custom_command(
        OUTPUT "${_bin}" "${_lst}"
        COMMAND "${_asm_tool}" "${target}"
        WORKING_DIRECTORY "${_src}"
        DEPENDS ${_inc_srcs}
        COMMENT "Assemble PIOC ${target}.ASM"
        VERBATIM)

    # ---- 5. Python 生成 C 接口: .BIN -> .c/.h ----------------------------------
    set(_c "${_src}/${target}.c")
    set(_h "${_src}/${target}.h")
    add_custom_command(
        OUTPUT "${_c}" "${_h}"
        COMMAND "${Python3_EXECUTABLE}" "${_gen}"
            --bin "${_bin}" --c "${_c}" --h "${_h}" --name "${target}"
        DEPENDS "${_bin}"
        COMMENT "Generate PIOC interface ${target}.c/.h"
        VERBATIM)

    # ---- 6. INTERFACE target: 链接者自动编译 .c 并获得 .h include 路径 ----------
    add_library(${target} INTERFACE)
    target_sources(${target} INTERFACE "${_c}")
    target_include_directories(${target} INTERFACE "${_src}")

    message(STATUS "WCH-PIOC: ${target} (${_asm}) -> ${_c} + ${_h}")
endfunction()
