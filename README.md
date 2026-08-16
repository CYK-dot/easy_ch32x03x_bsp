# ch32x035-bsp

CH32X035 系列（CH32X035）的 CMake BSP 基座，以子目录形式被应用工程引用（git-submodule 形态）。
基于 WCH CH32X035EVT 官方标准库封装。

## 目录结构

```
ch32x035-bsp/
├── CMakeLists.txt                 # 静态库 libwch_periph.a + 接口注入
├── inc/                           # 0层头文件（ch32x035.h / ch32x035_*.h / PIOC_SFR.h / core_riscv.h / debug.h / system_ch32x035.h）
├── src/
│   ├── cpu/                       # 内核适配（startup_ch32x035.S / system_ch32x035.c / core_riscv.c）
│   ├── peri/                      # 外设驱动（ch32x035_*.c）
│   └── debug/                     # 调试实现（debug.c）
├── references/USB/                # 示例私有 USB 驱动（ch32x035_usbfs_device.c/h，仅参考不参与编译）
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

### step2. 在项目中引用BSP库

单 elf、无 bootloader 场景，使用默认链接脚本与启动汇编：

```cmake
cmake_minimum_required(VERSION 3.20)

set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/ch32x035-bsp/cmake/toolchain-riscv-wch.cmake)  # 必须在 project 之前
project(my_app C ASM)

add_subdirectory(ch32x035-bsp)

add_executable(my_app.elf src/main.c)
target_link_libraries(my_app.elf PRIVATE wch_periph)   # 链接bsp库
target_link_wch_startup(my_app.elf CH32X035)           # 注入启动文件 + 链接脚本
wch_generate_hex(my_app.elf CH32X035)                  # 生成 hex + 打印各段大小
```

多段分散加载场景：链接 `wch_periph` 静态库即可（不注入启动/链接脚本）。

### step3. 构建

```bash
cmake -B build -G "MinGW Makefiles"
cmake --build build
```

产物：`build/my_app.elf`、`build/my_app.hex`、`build/my_app.map`，并打印各段大小报告。

## 对外接口

| 接口 | 说明 |
|---|---|
| `target_link_wch_startup(<target> [CHIP])` | 注入启动文件 + 链接脚本（+ 必要的 -nostartfiles） |
| `wch_generate_hex(<target> [CHIP])` | 生成 hex 并打印各段大小 |

## 支持芯片

| 芯片 | Flash | RAM |
|---|---|---|
| CH32X035 | 62K | 20K |

## 定制

- 链接脚本 / 启动文件：应用工程根目录放自己的 `Link.ld` / `startup.S`，自动优先
- 时钟频率：`system_ch32x035.c` 中 `SYSCLK_FREQ_48MHz_HSI` 等宏，改 BSP 源码或应用侧覆盖
- `ch32x035_conf.h` / `ch32x035_it.h` 覆盖（include 路径顺序：应用 `src/` 优先于 BSP `inc/`）
- PIOC 协处理器：`PIOC_SFR.h` 已含于 `inc/`，应用直接 `#include "PIOC_SFR.h"` 操作寄存器，无需额外 CMake 配置
- 库优化等级：configure 时 `-DWCH_PERIPH_OPT=-Os` 可覆盖 `wch_periph` 库编译优化等级（默认 `-Os`，对齐官方示例构建）

## License

本仓库为**双许可**结构：

- 本仓库原创内容（CMake 构建系统、封装接口、示例代码、文档）：**GPLv3**，见 `LICENSE`
- WCH 官方标准库源码（`inc/`、`src/`）与参考示例（`references/`）：遵循**沁恒原始许可**
  （Copyright (c) 2021 Nanjing Qinheng Microelectronics Co., Ltd.，
  仅限用于沁恒微控制器），见 `LICENSE-WCH.txt`
