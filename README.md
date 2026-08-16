# ch32x035-bsp

CH32X035 系列（CH32X035）的 CMake BSP 基座，以子目录形式被应用工程引用（git-submodule 形态）。
基于 WCH CH32X035EVT 官方标准库封装。

## 目录结构

```
ch32x035-bsp/
├── CMakeLists.txt                 # 静态库 libwch_periph.a
├── inc/                           # 0层头文件
├── src/
│   ├── cpu/
│   │   ├── rv32imacxw/            # RISC-V 内核支撑
│   │   └── chrisc8b/              # PIOC/eMCU 微核支撑
│   └── peri/                      # 外设驱动
├── references/
│   ├── USB/                       # 示例私有 USB 驱动
│   ├── debug/                     # UART Printf/Delay 调试参考
│   └── pioc/                      # PIOC 参考
├── tools/pioc/                    # PIOC 交叉编译工具
└── cmake/
    ├── ch32x035-bsp.cmake         # 对外cmake接口实现
    ├── toolchain-riscv-wch.cmake  # 交叉工具链声明，外部无需感知
    ├── wch_link.ld.in             # 链接脚本模板，外部无需感知
    └── wch_size_report.cmake      # 段大小打印脚本，外部无需感知
```

## 使用方法

### step1. 设置环境变量
工具链路径设置到环境变量 `WCH_TOOLCHAIN_ROOT`（**必填**，未设置时 configure 直接报错）。
示例：`C:/01_Tools/riscv32-wch-elf-gcc`（GCC15）。

调试（`add_wch_debug_target()`）还需 `WCH_OPENOCD_ROOT` 指向 OpenOCD 安装根目录
（**必填**，含 `bin/openocd[.exe]`，未设置时 configure 直接报错）。
示例：`C:/01_Tools/MounRiverStudio/MounRiver_Studio2/resources/app/resources/win32/components/WCH/OpenOCD/OpenOCD`。

### step2. 在项目中引用BSP库

单 elf、无 bootloader 场景，使用默认链接脚本与启动汇编：

```cmake
cmake_minimum_required(VERSION 3.20)

set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/ch32x035-bsp/cmake/toolchain-riscv-wch.cmake)  # 必须在 project 之前
project(my_app C ASM)

add_subdirectory(ch32x035-bsp)

add_executable(my_app.elf src/main.c)
target_link_libraries(my_app.elf PRIVATE wch_periph)   # 链接外设驱动静态库
target_link_wch_startup(my_app.elf CH32X035)           # 注入 CPU 三件套(启动汇编/system/core) + 链接脚本
wch_generate_hex(my_app.elf CH32X035)                  # 生成 hex + 打印各段大小
add_wch_debug_target(my_app.elf openocd-debug)         # make openocd-debug 启动 OpenOCD GDB server
```

**职责划分**：`wch_periph` 静态库只含外设驱动（`src/peri/*.c`）；CPU 启动/系统初始化代码
（`startup_ch32x035.S`、`system_ch32x035.c`、`core_riscv.c`）由 `target_link_wch_startup()`
编译进目标可执行文件——外设驱动对 `SystemCoreClock`/`NVIC_*` 等符号的引用在链接期由该目标解析。

多段分散加载场景：链接 `wch_periph` 静态库即可（不调用 `target_link_wch_startup`，
不注入启动/链接脚本），CPU 启动代码由引导程序（bootloader）或其他加载段自行提供。

### step3. 构建

```bash
cmake -B build -G "MinGW Makefiles"
cmake --build build
```

产物：`build/my_app.elf`、`build/my_app.hex`、`build/my_app.map`，并打印各段大小报告。

### step4. 调试（可选）

`add_wch_debug_target()` 会为 elf 生成一个"连接设备并启动 OpenOCD GDB server"的 make target：

```bash
make openocd-debug
```

该命令先构建 elf，再连接 WCH probe（WCH-Link / WCH-LinkE / WCH-LinkW，RISC-V 模式）并
前台启动 OpenOCD（GDB server 默认端口 **3333**）。OpenOCD 路径来自环境变量
`WCH_OPENOCD_ROOT`（step1，未设置时 configure 直接报错），前端由开发者自选，例如
VSCode **Cortex-Debug** 以 external/attach 模式连接：

```json
{
    "type": "cortex-debug",
    "request": "attach",
    "servertype": "external",
    "gdbTarget": "localhost:3333",
    "executable": "${workspaceRoot}/build/my_app.elf",
    "gdbPath": "C:/01_Tools/riscv32-wch-elf-gcc/bin/riscv32-wch-elf-gdb.exe",
    "svdFile": "<MRS2>/WCH/SDK/default/RISC-V/CH32X035/NoneOS/CH32X035xx.svd",
    "targetProcessor": 0
}
```

**停止**：`Ctrl+C` **无法可靠终止 OpenOCD**（进程可能残留并继续占用 probe）。请用配套的 stop target：

```bash
make openocd-debug-stop
```

`add_wch_debug_target()` 为每个 debug target 生成配套的 `${target}-stop`（本示例即
`openocd-debug-stop`），终止本机 openocd 进程并释放 probe（Windows 下为
`taskkill /F /IM openocd.exe`，会终止本机所有 openocd 实例；幂等，无残留时不报错）。
若 `make openocd-debug` 报端口 3333 被占或设备被占，先执行 stop target 再重试。

可配置缓存变量（`cmake -D<NAME>=<value>` 覆盖）：

| 变量 | 默认 | 说明 |
|---|---|---|
| `WCH_OPENOCD_GDB_PORT` | 3333 | GDB server 端口（前端 `gdbTarget` 需一致） |
| `WCH_OPENOCD_SPEED` | 6000 | adapter 时钟 kHz |

生成的 OpenOCD 配置在 `build/wch/<CHIP>.openocd.cfg`（仅调试不烧录）。

## 对外接口

| 接口 | 说明 |
|---|---|
| `target_link_wch_startup(<target> [CHIP])` | 注入启动文件 + 链接脚本（+ 必要的 -nostartfiles） |
| `wch_generate_hex(<target> [CHIP])` | 生成 hex 并打印各段大小 |
| `add_wch_debug_target(<exec> <target> [CHIP])` | 创建"连接设备 + 启动 OpenOCD GDB server"的 make target，并配套生成 `${target}-stop`（终止残留 openocd 释放 probe） |

## 支持芯片

| 芯片 | Flash | RAM |
|---|---|---|
| CH32X035 | 62K | 20K |

## 定制

- 链接脚本 / 启动文件：应用工程根目录放自己的 `Link.ld` / `startup.S`，自动优先
- 时钟频率：`system_ch32x035.c` 中 `SYSCLK_FREQ_48MHz_HSI` 等宏，改 BSP 源码或应用侧覆盖
- `ch32x035_conf.h` / `ch32x035_it.h` 覆盖（include 路径顺序：应用 `src/` 优先于 BSP `inc/`）
- PIOC 协处理器：`PIOC_SFR.h` 已含于 `inc/`，应用直接 `#include "PIOC_SFR.h"` 操作寄存器，无需额外 CMake 配置；
  编写 PIOC 汇编与加载/通信代码前，先读 `references/pioc/Manual/CHRISC8B.PDF`（指令集）与
  `references/pioc/Manual/PIOC.PDF`（SFR 手册），参考 `references/pioc/examples/` 下的完整示例
  （1_Wire/RGB1W、PIOC_IIC：.ASM 源 + 官方 main.c 加载序列）
- 库优化等级：configure 时 `-DWCH_PERIPH_OPT=-Os` 可覆盖 `wch_periph` 库编译优化等级（默认 `-Os`，对齐官方示例构建）

## License

本仓库为**双许可**结构：

- 本仓库原创内容（CMake 构建系统、封装接口、示例代码、文档）：**GPLv3**，见 `LICENSE`
- WCH 官方标准库源码（`inc/`、`src/`）与参考示例（`references/`）：遵循**沁恒原始许可**
  （Copyright (c) 2021 Nanjing Qinheng Microelectronics Co., Ltd.，
  仅限用于沁恒微控制器），见 `LICENSE-WCH.txt`
