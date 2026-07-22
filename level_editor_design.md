# 关卡编辑器设计方案讨论

## 一、现状理解

当前项目中已经存在与"关卡"相关的概念：

- **map_set**（地图集）：一组地图的序列，如 YongDong = [YongDong1, YongDong2]
- **map**（地图）：单个地图 JSON，包含 basic、floors、floor、obstacles、obstacle、districts
- **游戏流程**：选择角色 → 选择 map_set → 按顺序玩每个 map → 通关

所以现有体系里 **map_set ≈ 关卡**，但没有可视化的编辑工具。

## 二、重新定义概念

从你的描述，我理解的层次结构：

```
关卡 (Level)
  ├── 阶段1 / 地图1 (Map)   
  │     ├── 类型: 程序生成 | 预定义
  │     ├── 地图类型: 冒险(地牢) | 对决(炸弹人)
  │     ├── 生成参数(随机时): 地物贴图, 可交互物件, 怪物配置
  │     └── 预定义地图ID(预定义时): 引用未来地图编辑器的产出
  ├── 阶段2 / 地图2
  └── ...
```

## 三、我们需要讨论确定的问题

### 1. 关卡编辑器的 UI 模式
- **独立编辑器**（类似角色编辑器，从标题画面进入）
- 还是 **内嵌在开发者模式中**（Dev Mode 里的一个功能区）

### 2. 关卡的数据结构

```json
{
  "name": "MyLevel",
  "maps": [
    {
      "type": "procedural",           // "procedural" | "predefined"
      "play_mode": "adventure",       // "adventure" | "duel"
      "generator_params": {
        "width": 25, "height": 13,
        "floor_textures": ["elem220", "grass01", ...],
        "interactive_objects": ["elem212", "elem225", ...],
        "monster_pool": ["Slime", "Bat", ...],
        "monster_count": { "min": 3, "max": 6 },
        "seed": null
      }
    },
    {
      "type": "predefined",
      "play_mode": "adventure",
      "map_id": "YongDong1",
      "difficulty_multiplier": 1.2
    }
  ]
}
```

### 3. 随机地图生成器的初步设计（你提到的 Roguelike 部分）

生成器需要哪些输入参数？

| 参数 | 说明 | 例子 |
|------|------|------|
| 地图尺寸 | 宽×高 | 25×13 |
| 地物贴图池 | 地板/墙壁贴图列表 | elem220, elem221 |
| 可交互物件贴图池 | 可破坏障碍物 | elem212, elem225 |
| 不可破坏物件贴图池 | 边界/固定障碍 | elem227 |
| 怪物池 | 可能出现的怪物 | Slime, Bat, Boss01 |
| 怪物数量范围 | 每区域多少怪 | 2~5 |
| 道具分布 | 道具刷新规则 | bomb+, speed+ |
| 出生点规则 | 玩家起始位置规则 | 角落/边缘 |
| 终点规则 | 过关条件 | 到达某坐标/清完怪 |

### 4. 地图类型：冒险 vs 对决

- **冒险（地牢 Roguelike）**：当前已有模式，scroll 滚动地图，district 分区清怪
- **对决（经典炸弹人）**：固定屏幕，玩家间竞技（或有 AI），需要哪些差异参数？
  - 固定视野（不 scroll）
  - 玩家出生点（PvP 需要多个出生点）
  - 胜负条件（击杀对手 / 先到达终点）
  - 道具分布规则不同

### 5. 关卡选择界面

- 是否需要一个类似角色选择的"关卡选择"界面（在标题画面或角色选择之后）？
- 游戏流程目前是：标题→选角色→选难度(Normal/Dev)→自动加载 config 里的 map_set
- 改为：标题→选角色→选关卡→选难度→开始

### 6. PV 模式（开发者模式）的关卡列表

- 开发模式下是否显示所有可用关卡的列表供调试？
- 是否可以快速跳转到关卡的某个地图？

## 四、当前可复用的模式

参考角色编辑器的结构，关卡编辑器的架构可以类似：

```
src/level_editor/
  ├── level_data.gd        # 关卡 CRUD，类似 HeroData
  ├── level_editor.gd       # 主编辑器 Control，类似 character_editor.gd
  ├── level_editor_ui.gd    # UI 构建，类似 character_editor_ui.gd
  ├── level_list.gd         # 关卡列表，类似 character_list.gd
  └── level_select.gd       # 关卡选择（游戏前），类似 character_select.gd
```

地图生成器：
```
src/game/level/
  ├── level.gd               # 现有，不变
  └── map_generator.gd       # 新增：随机地图生成器
```

## 五、第一个里程碑范围建议

建议第一个里程碑聚焦在：

1. **关卡列表 + 编辑器 UI**（新建/编辑/保存关卡）
2. **关卡编辑器只操作"参数配置"**（选择预定义地图 / 配置生成参数）
3. **游戏前增加关卡选择界面**
4. **随机地图生成器只实现基础版**（固定模板 + 替换贴图，后续逐步完善算法）
5. **现有 map_set 数据迁移或兼容**

不需要在第一版做：
- 地图编辑器的可视化画布（那是未来的独立工具）
- 复杂的生成算法（先搭框架）
- 怪物编辑器（未来独立工具）

---

请看一下这个框架，我们逐条讨论确认。
