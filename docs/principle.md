# 项目规范 principle

## 1. 代码架构

### 1.1 合理抽象，单一职责
- 每个文件聚焦一个职责，功能内聚
- 单文件 **不超过 500 行**（含注释空行）
- 超过 500 行必须拆分为多个文件，按模块放入对应目录
- 目录结构应反映职责边界

### 1.2 命名规范
- 全部使用 `snake_case`
- 文件名：`my_module.gd`
- 类名：`MyClass`（Godot 惯例，与内置类型一致）
- 变量/函数：`my_variable`, `do_something()`
- 常量：`MY_CONSTANT`
- 信号：`my_signal`
- 目录名：`my_directory`

### 1.3 测试资源隔离
- 所有开发中的临时/测试美术资源放在 `assets/test/` 下
- 生产资源放在 `assets/` 下各自目录
- 测试资源不参与主游戏加载

## 2. 美术资源

### 2.1 角色渲染
- 采用 **混合式 body + decoration** 系统
- `Body` 组件 = 完整角色素体（含默认衣着，面部留白）
- `Face` 装饰 = 独立覆盖层（眼睛+嘴巴，多种风格）
- 装饰层只做简单叠加（帽子、背包、面部表情）

### 2.2 资源来源
- `original/` 为参考项目，**禁止修改**，成熟后废弃
- AI 生成资源放入 `assets/test/` 验收后迁移
- 生成的图片不做额外编辑，保留原始输出
- 详细工具对比见 `docs/art_design.md`

### 2.3 资源格式
- 帧数据：JSON（同一套 IMG/CX/CY 结构）
- 图集：PNG + atlas JSON（与 `sprite_sheet_packer.gd` 兼容）
- 角色定义：JSON（引用 body + decorations）

## 3. 工具链

### 3.1 AI 生成管线
- 首选 **Sprite AI**（MCP 方案），备选 **SEELE AI**（网页工具）
- 详见 `docs/art_design.md`
- Pipeline 脚本在 `src/tools/test/` 下
- 生成 → 转换 → 打包 三步分开，可独立执行

### 3.2 测试预览
- 测试场景放在 `assets/test/`
- 使用 `TestCharacterLoader` 独立加载，不影响主系统
- 预览窗口支持热切换面部装饰

## 4. 开发流程

### 4.1 新增资源步骤
1. 用 pipeline 生成素体 → `assets/test/`
2. 手动检查效果
3. 调整 prompt 重新生成直到满意
4. 迁移到 `assets/` 正式目录

### 4.2 新增代码步骤
1. 确认已有文件是否可复用
2. 新文件控制在 500 行以内
3. 写测试预览验证
4. 确认不破坏现有功能
