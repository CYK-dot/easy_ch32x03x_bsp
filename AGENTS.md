# AGENTS.md

本文件面向 AI 开发代理,规定本仓库的编码规范与协作流程。
人类使用方式见 [README.md](README.md)。

## 编码风格

- 能不注释就不注释;只在 0 层(对外接口)注释
- 0 层接口注释:说明用途、参数、返回值,使用中文
- 实现内部一律不写注释;逻辑复杂到需要注释时,优先重构为自解释的命名与结构
- 单一职责:一个函数只做一件事

## Git 提交规范

- 提交信息格式:`[修改类型] 修改内容`
- 修改类型:`feature` / `fix` / `refactor` / `docs` / `style` / `build` / `chore`
- 示例:
  - `[feature] add openocd support`
  - `[fix] resolve gdb resume failure`
  - `[refactor] strip internal comments`

## 提交前检视

- 任何 git 提交都必须先由人类检视(检查 diff 并批准)
- AI 不得在未经人类检视的情况下 commit / push
- 涉及共享分支的推送需人类明确批准
