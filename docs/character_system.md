# 角色系统使用说明

## 目录

1. [角色编辑器 UI](#1-角色编辑器-ui)
2. [新建角色流程](#2-新建角色流程)
3. [精灵图表集系统](#3-精灵图表集系统)
4. [自定义纹理](#4-自定义纹理)

---

## 1. 角色编辑器 UI

编辑器采用左右分栏布局：

- **左侧** — 角色预览区，WASD / 方向键旋转预览
- **右侧** — `TabContainer`，包含四个标签页：

### 基本信息 (Basic)
- 角色名称、基础血量/速度/炸弹数/恢复/力量/伤害/防御
- 炸弹皮肤选择、隐藏脚/腿效果
- 技能列表（添加/删除）

### 装饰 (Decorations)
每个装饰分类点击后弹出选择面板：
- **Cap** — 头饰
- **Hair** — 发型
- **Eye** — 眼睛
- **Ear** — 耳朵
- **Mouth** — 嘴巴
- **Cladorn** — 服装装饰（选择后会替换 Cloth）
- **Fpack / Npack / Thadorn** — 背包/装饰品
- **Footprint** — 脚印特效

点击已选装饰可取消选择（恢复默认）。

### 技能 (Skills)
当前支持的技能通过代码实现（如 BloodElixir、RevivalCard），在 dev 模式下有无限冷却。

### 自定义纹理 (Custom Textures)
上传外部图片替换角色部件，脱离 QQT 素材体系。

---

## 2. 新建角色流程

1. 在角色列表页点击 **"+ New"**
2. 自动创建素体角色（`CharacterBlank`），无面部/发型等特征
3. 在编辑器右侧 **Decorations** 标签页为角色添加特征
4. 修改 Basic 标签页中的数值属性
5. 返回角色列表，新角色自动保存

素体默认只包含：Body、Leg、Cloth 及其 _m 遮罩层。Face、Hair、Eye、Ear、Mouth、Cap 等装饰部件需要手动添加。

---

## 3. 精灵图表集系统

### 解决的问题
游戏中每个角色部件对应大量零散 PNG 文件（如 `body1_stand_0_0.png`），导致：
- Godot 导入时产生海量 `.png.import` 文件
- GPU 纹理切换频繁
- 文件数量庞大，管理困难

### 架构

```
assets/img/body/body1_stand_0_0.png  (原始零散 PNG)
assets/img/body/body.atlas.png       (图集纹理)
assets/img/body/body.atlas.json      (图集元数据)
```

### 打包工具

**位置**：`src/tools/sprite_sheet_packer.gd`

将每个组件目录（`body/`、`hair/` 等）下的所有 PNG 打包成一个图集：

```bash
# 命令行运行（需要 Godot 4.6+）：
godot --path <项目路径> --script res://src/tools/sprite_sheet_packer.gd
```

- 使用货架式（shelf）装箱算法
- 输出 2 的幂次方纹理（兼容 GPU）
- 输出 `{dir}.atlas.png` + `{dir}.atlas.json`

**重新打包**：如果角色资源尺寸或内容变更，重新运行上述命令即可，无需改代码。

### 运行时加载

**位置**：`src/frame/atlas_loader.gd`

流程：
1. `CharacterLoader.load_component_frames()` 调用 `AtlasLoader.get_texture()`
2. 普通帧 → 返回 `AtlasTexture`（轻量级，仅引用图集区域）
3. 遮罩帧（`_m` 后缀） → 从图集中提取区域，叠加玩家颜色，返回 `ImageTexture`
4. 幽灵帧 → 从图集中提取区域，半透明处理，返回 `ImageTexture`
5. 如果图集不存在或帧不存在 → 自动回退到加载单个 PNG（`_load_fallback`）

### 缓存机制

- 图集纹理（GPU 内存）按组件类型缓存
- 图集 Image（CPU 内存，用于遮罩/幽灵像素操作）按需缓存
- 完整角色字典按 `(角色名, 颜色, 是否幽灵)` 缓存

### 扩展：添加新组件

1. 在 `assets/img/` 下创建新目录（如 `wing/`）
2. 放入 PNG 文件，命名遵循 `{部件}{id}_{state}_{orientation}_{frame}.png`
3. 运行打包工具
4. 在 `CharacterLoader.CHARACTER_COMPONENTS` 中添加组件到绘制顺序列表
5. （可选）在 `CHARACTER_COMPONENTS_MASKED` 中添加遮罩支持
6. （可选）在 `DECORATION_CATEGORIES` 中添加装饰支持

---

## 4. 自定义纹理

切换到 Custom Textures 模式后，编辑器允许上传外部图片：

- 每个部件单帧静态显示（无动画）
- 支持所有标准部件：body、foot、leg、cloth、face、hair、eye、ear、mouth、cap 等
- 支持幽灵模式（半透明）
- 支持遮罩着色（对有 `_m` 后缀的部件应用玩家颜色）

---

## 文件索引

| 文件 | 功能 |
|------|------|
| `src/frame/character_loader.gd` | 角色帧加载 + 组合 |
| `src/frame/atlas_loader.gd` | 图集纹理运行时加载 |
| `src/frame/character_preview.gd` | 角色预览渲染 |
| `src/tools/sprite_sheet_packer.gd` | 图集打包工具 |
| `src/player_editor/character_editor.gd` | 编辑器主逻辑（~300行） |
| `src/player_editor/character_editor_ui.gd` | 编辑器 UI 构建 + 事件处理（~476行） |
| `src/player_editor/character_list.gd` | 角色列表管理 |
| `src/player_editor/character_select.gd` | 英雄选择界面 |
| `assets/frame/character/CharacterBlank.json` | 素体角色定义 |

---

## 5. 开发原则

### 单文件行数限制
- 单个 `.gd` 文件不得超过 **500 行**
- 超限的文件应当进行合理的抽象和业务拆分
- 拆分方式：将不同职责的代码提取到独立的 `class_name` 文件中，通过静方法或组合调用
