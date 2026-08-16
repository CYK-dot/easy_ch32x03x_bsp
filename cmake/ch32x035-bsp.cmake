function(_wch_resolve_chip target out_var)
    set(_opts "")
    set(_one CHIP)
    set(_multi "")
    cmake_parse_arguments(ARG "${_opts}" "${_one}" "${_multi}" ${ARGN})
    set(_chip ${ARG_CHIP})
    if(NOT _chip AND ARG_UNPARSED_ARGUMENTS)
        list(GET ARG_UNPARSED_ARGUMENTS 0 _chip)
    endif()
    if(NOT _chip)
        get_target_property(_prop ${target} WCH_CHIP)
        if(_prop)
            set(_chip ${_prop})
        elseif(DEFINED WCH_DEFAULT_CHIP)
            set(_chip ${WCH_DEFAULT_CHIP})
        else()
            message(FATAL_ERROR
                "target_link_wch_startup: no chip specified for '${target}'.\n"
                "  Use: target_link_wch_startup(${target} CH32X035)")
        endif()
    endif()
    set(${out_var} ${_chip} PARENT_SCOPE)
endfunction()

####################################################################################################
# @name target_link_wch_startup
# @brief 为可独立启动的elf添加wch提供的启动代码
#
# @param target 可执行 target（通常已调用 target_link_wch_startup）
# @param chip   可选，芯片型号（打印芯片总 Flash/RAM 容量）
####################################################################################################
function(target_link_wch_startup target)
    # ---- 链接脚本生成 --------------------------
    set(_bsp "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/..")
    set(_chip_params
        FLASH_ORIGIN 0x00000000 FLASH_LENGTH 62K
        RAM_ORIGIN   0x20000000 RAM_LENGTH   20K
        STACK_SIZE   2048
        STARTUP      "${_bsp}/src/cpu/rv32imacxw/startup_ch32x035.S"
        SYSTEM       "${_bsp}/src/cpu/rv32imacxw/system_ch32x035.c"
        CORE         "${_bsp}/src/cpu/rv32imacxw/core_riscv.c")
    _wch_resolve_chip(${target} _chip ${ARGN})
    if(NOT _chip STREQUAL "CH32X035")
        message(FATAL_ERROR
            "target_link_wch_startup: unsupported chip '${_chip}'.\n"
            "  Supported: CH32X035")
    endif()
    set(_params ${_chip_params})
    list(LENGTH _params _n)
    math(EXPR _n "${_n} - 1")
    foreach(_i RANGE 0 ${_n} 2)
        list(GET _params ${_i} _key)
        math(EXPR _j "${_i} + 1")
        list(GET _params ${_j} _val)
        set(${_key} ${_val})
    endforeach()
    set(_ld "${CMAKE_BINARY_DIR}/wch/${_chip}.ld")
    configure_file("${_bsp}/cmake/wch_link.ld.in" "${_ld}" @ONLY)
    message(STATUS "WCH: generated ${_ld} for ${_chip}")

    # ---- 启动脚本 ------------------------------
    set(_startup "${STARTUP}")
    target_sources(${target} PRIVATE
        ${_startup}
        "${SYSTEM}"
        "${CORE}")
    target_link_options(${target} PRIVATE
        "-T${_ld}" -nostartfiles
        "-Wl,-Map=${CMAKE_BINARY_DIR}/${target}.map"
        --specs=nano.specs
        --specs=nosys.specs)
endfunction()

####################################################################################################
# @name wch_generate_hex
# @brief 为 elf target 生成 ihex 烧录文件，并打印各段大小
#        实现为独立自定义 target（依赖 elf），链接失败时不会生成 hex
#
# @param target 可执行 target（通常已调用 target_link_wch_startup）
# @param chip   可选，芯片型号（打印芯片总 Flash/RAM 容量）
####################################################################################################
function(wch_generate_hex target)
    set(_bsp "${CMAKE_CURRENT_FUNCTION_LIST_DIR}")
    set(_hex "${CMAKE_BINARY_DIR}/${target}.hex")
    set(_hex_target "${target}_hex")

    set(_flash_total "")
    set(_ram_total "")
    if(ARGN)
        list(GET ARGN 0 _chip)
        if(_chip MATCHES "^CH32X035")
            set(_flash_total "62K")
            set(_ram_total "20K")
        endif()
    endif()

    add_custom_command(
        OUTPUT "${_hex}"
        COMMAND ${CMAKE_OBJCOPY} -O ihex "$<TARGET_FILE:${target}>" "${_hex}"
        COMMAND ${CMAKE_COMMAND} -P "${_bsp}/wch_size_report.cmake" --
            "$<TARGET_FILE:${target}>" "${CMAKE_SIZE}" "${target}" "${_flash_total}" "${_ram_total}"
        COMMENT "Generate ${target}.hex"
        DEPENDS "$<TARGET_FILE:${target}>"
        VERBATIM)
    add_custom_target(${_hex_target} ALL DEPENDS "${_hex}")
endfunction()

####################################################################################################
# @name add_wch_debug_target
# @brief 为 elf target 创建"连接设备并启动 OpenOCD GDB server"的 make target
#
#        执行 `make <target>` 会:先构建 elf → 连接 WCH probe → 前台启动 OpenOCD(GDB server)。
#        前端由开发者自选(如 VSCode cortex-debug 以 external/attach 模式连 localhost:<port>)。
#
# @param exec   可执行 target 名(如 my_app.elf)
# @param target 生成的 make target 名(如 openocd-debug)
# @option CHIP  芯片型号(默认:查 exec 的 WCH_CHIP 属性 → WCH_DEFAULT_CHIP → CH32X035)
#
# 依赖环境变量:
#   WCH_OPENOCD_ROOT  OpenOCD 安装根目录(含 bin/openocd[.exe]), 未设置直接报错
#
# 相关缓存变量(configure 时 -D 覆盖):
#   WCH_OPENOCD_GDB_PORT   GDB server 端口(默认 3333)
#   WCH_OPENOCD_SPEED      adapter 时钟 kHz(默认 6000)
####################################################################################################
function(add_wch_debug_target exec target)
    cmake_parse_arguments(ARG "" "CHIP" "" ${ARGN})

    # ---- 芯片解析 ------------------------------
    if(ARG_CHIP)
        set(_chip ${ARG_CHIP})
    else()
        get_target_property(_prop ${exec} WCH_CHIP)
        if(_prop)
            set(_chip ${_prop})
        elseif(DEFINED WCH_DEFAULT_CHIP)
            set(_chip ${WCH_DEFAULT_CHIP})
        else()
            set(_chip CH32X035)
        endif()
    endif()

    # ---- OpenOCD 定位 --------------------------
    # 仅支持环境变量 WCH_OPENOCD_ROOT 指向 OpenOCD 安装根目录
    # (要求其 bin/ 下有 openocd.exe / openocd), 未设置直接报错
    if(NOT DEFINED ENV{WCH_OPENOCD_ROOT} OR "$ENV{WCH_OPENOCD_ROOT}" STREQUAL "")
        message(FATAL_ERROR
            "add_wch_debug_target: env WCH_OPENOCD_ROOT is not set.\n"
            "  Set it to the OpenOCD install root, e.g.\n"
            "    set WCH_OPENOCD_ROOT=<MRS2>/WCH/OpenOCD/OpenOCD  (contains bin/openocd.exe)")
    endif()
    if(EXISTS "$ENV{WCH_OPENOCD_ROOT}/bin/openocd.exe")
        set(_openocd "$ENV{WCH_OPENOCD_ROOT}/bin/openocd.exe")
    elseif(EXISTS "$ENV{WCH_OPENOCD_ROOT}/bin/openocd")
        set(_openocd "$ENV{WCH_OPENOCD_ROOT}/bin/openocd")
    else()
        message(FATAL_ERROR
            "add_wch_debug_target: no openocd[.exe] under '$ENV{WCH_OPENOCD_ROOT}/bin'.\n"
            "  Check WCH_OPENOCD_ROOT.")
    endif()

    # ---- 生成 OpenOCD 配置 ---------------------
    set(WCH_OPENOCD_GDB_PORT 3333 CACHE STRING "GDB server port used by add_wch_debug_target()")
    set(WCH_OPENOCD_SPEED 6000 CACHE STRING "OpenOCD adapter clock in kHz")
    set(WCH_CHIP ${_chip})   # 供 configure_file 模板 @WCH_CHIP@ 替换
    set(_bsp "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/..")
    set(_cfg "${CMAKE_BINARY_DIR}/wch/${_chip}.openocd.cfg")
    configure_file("${_bsp}/cmake/wch_openocd.cfg.in" "${_cfg}" @ONLY)

    # ---- make target ---------------------------
    add_custom_target(${target}
        COMMAND ${CMAKE_COMMAND} -E echo
            "============================================================"
        COMMAND ${CMAKE_COMMAND} -E echo " WCH OpenOCD GDB server"
        COMMAND ${CMAKE_COMMAND} -E echo "   openocd : ${_openocd}"
        COMMAND ${CMAKE_COMMAND} -E echo "   config  : ${_cfg}"
        COMMAND ${CMAKE_COMMAND} -E echo "   elf     : $<TARGET_FILE:${exec}>"
        COMMAND ${CMAKE_COMMAND} -E echo
            "   gdb     : target remote localhost:${WCH_OPENOCD_GDB_PORT}"
        COMMAND ${CMAKE_COMMAND} -E echo
            " stop with: make ${target}-stop  (Ctrl+C unreliable on Windows)"
        COMMAND ${CMAKE_COMMAND} -E echo
            "============================================================"
        # gdb_port 必须先于 cfg 中的 init 执行, 故放在 -f 之前
        COMMAND ${_openocd} -c "gdb_port ${WCH_OPENOCD_GDB_PORT}" -f "${_cfg}"
        WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
        VERBATIM
        USES_TERMINAL)
    add_dependencies(${target} ${exec})

    # ---- stop target(兜底清理) ----------------
    # Windows 下 mingw32-make 的 console handler 会消费 Ctrl+C 事件而不传给子进程,
    # 导致 OpenOCD 残留并继续占用 probe, 故提供显式停止 target。
    # 注意: taskkill /F /IM 会终止本机所有 openocd.exe 实例。
    if(CMAKE_HOST_WIN32)
        add_custom_target(${target}-stop
            COMMAND ${CMAKE_COMMAND} -E echo
                "WCH: killing openocd.exe to release probe ..."
            COMMAND cmd /c "taskkill /F /IM openocd.exe & exit 0"
            VERBATIM)
    else()
        add_custom_target(${target}-stop
            COMMAND ${CMAKE_COMMAND} -E echo
                "WCH: killing openocd to release probe ..."
            COMMAND sh -c "pkill -f '${_cfg}' || true"
            VERBATIM)
    endif()
endfunction()
