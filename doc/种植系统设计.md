# 种植系统设计

## 概述

种植系统为炼药系统提供原料产出，形成 **种植 → 收获 → 炼药 → 药剂** 的玩法循环。采用回合制时间推进，预留天气系统扩展接口。

---

## 时间系统

### 回合机制
- 每次玩家操作（播种、浇水、除草、收获）推进 **1 回合**
- 进入/离开种植场景也推进 1 回合（防止利用出入场景跳过时间）
- 每回合所有植物执行一次 `tick()`，推进生长阶段、更新水分、检查压力

### 扩展接口（预留）
```
## 天气系统接入点（未来实现）
enum Weather { SUNNY, RAIN, DROUGHT, STORM }

# 每回合开始时由全局时间系统注入
var current_weather: int = Weather.SUNNY  
var current_season: int = 0   # 0=春 1=夏 2=秋 3=冬

# 天气对种植的影响（未来实现时在这里扩展）
func _weather_modifier() -> Dictionary:
    match current_weather:
        Weather.RAIN:    return {"water_bonus": 2}   # 下雨 = 自动浇水
        Weather.DROUGHT: return {"water_bonus": -1}  # 干旱 = 额外耗水
        Weather.STORM:   return {"stress_bonus": 1}  # 暴风雨 = 压力增加
        _:               return {}
```

### 数据结构
```gdscript
class GameTime:
    var turn: int = 0          # 总回合数
    var weather: int = 0       # 当前天气（预留）
    var season: int = 0        # 当前季节（预留）
```

---

## 植物数据模型（PlantData）

独立于 Item 的数据结构，种子和产出通过 `seed_item_id` / `harvest_item_id` 引用 Item。

```json
{
  "id": "flame_herb",
  "name": "烈焰草",
  "description": "喜热怕湿的炼药材料",

  "seed_item_id": "seed_flame_herb",
  "harvest_item_id": "flame_herb",

  "growth_stages": [
    {"name": "种子", "duration": 2},
    {"name": "幼苗", "duration": 3},
    {"name": "成熟", "duration": 0}
  ],
  "total_growth": 5,

  "water_per_turn": 1,
  "max_water": 5,
  "stress_value": 3,
  "stress_threshold": 10,

  "season_pref": ["spring", "summer"],
  "yield_min": 1,
  "yield_max": 3
}
```

### 字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | String | 唯一标识 |
| `seed_item_id` | String | 种植时消耗的种子 Item ID |
| `harvest_item_id` | String | 收获时获得的材料 Item ID |
| `growth_stages` | Array | 生长阶段数组，每个阶段有名称和持续回合数；最后阶段 duration=0 表示无限持续（成熟后可收获） |
| `total_growth` | int | 从种到熟的总回合数（各阶段 duration 之和） |
| `water_per_turn` | int | 每回合消耗水量 |
| `max_water` | int | 最大蓄水量，浇水补满到此值 |
| `stress_value` | int | 该植物的压力值（1~5） |
| `stress_threshold` | int | 相邻地块压力总和超过此值时触发枯萎 |
| `season_pref` | Array | 偏好季节（预留） |
| `yield_min/max` | int | 收获产量范围 |

---

## 压力值机制

### 规则
- 每块地相邻 4 格（上/下/左/右）为"相邻地块"
- 每回合计算每个地块的 **相邻压力总和** = 相邻地块所有植物 `stress_value` 之和
- 如果相邻压力总和 >= 该植物的 `stress_threshold` → 该植物进入 **枯萎** 状态
- 枯萎的植物停止生长，3 回合后死亡消失

### 设计意图
- 高压植物（高级炼药材料）需要单独种植或与低压植物搭配
- 鼓励玩家规划布局，而不是无脑密植
- 低压植物（stress_value=1）可以密集种植，作为基础材料来源

### 例子
```
  地块布局（数字为 stress_value）：
   
   [1] - [3] - [1]
    |     |     |
   [2] - [4] - [2]
    |     |     |
   [1] - [3] - [1]

   中间 [4] 的相邻压力 = 3+2+3+2 = 10
   如果 threshold=10 → 临界，再多种一棵高压植物就枯萎
```

---

## 种植场景 UI

### 布局
- 独立场景（类似 Alchemy Lab），测试期间从标题进入
- 6×6 种植地块网格
- 每个地块显示：植物图标、水分条（蓝色）、生长进度条、枯萎警告标记

### 玩家操作

| 操作 | 方式 | 效果 |
|------|------|------|
| 除草 | 点击杂草地块 | 消耗 1 回合，清除杂草 |
| 种植 | 选择种子 → 点击空地 | 消耗 1 回合 + 1 种子 |
| 浇水 | 选择水壶 → 点击地块 | 消耗 1 回合，补满该地块水量到 max_water |
| 收获 | 点击成熟植物 | 消耗 1 回合，获得产出（harvest_item_id × yield）|

### 杂草机制
- 空地每 5 回合有概率长草
- 杂草占据地块，必须先除草才能种植
- 杂草无压力值，不影响相邻格

---

## Plant Editor

### 定位
独立的编辑器，与 Item Editor 并列，从标题屏幕进入。

### 功能清单
- 植物列表（浏览/搜索/排序）
- 新建/编辑/删除/复制植物
- 编辑字段：所有 PlantData 字段
- 种子/产出 Item 选择器（调用 Item Editor 的列表）
- 生长阶段可视化（添加/删除/排序阶段卡）
- 压力值预热计算器（输入相邻植物预览压力结果）
- JSON 保存到 `assets/plant/` 目录

### 文件结构
```
assets/plant/
├── flame_herb.json
├── frost_leaf.json
└── ...

src/plant_editor/
├── plant_data.gd        # PlantData CRUD + 常量
├── plant_list.gd        # 列表 UI
├── plant_editor_ui.gd   # 编辑 UI（各字段控件）
└── plant_editor.gd      # 入口 / 容器
```

---

## 与炼药系统的连接

- 收获物（`harvest_item_id`）是炼药原料
- 原料 Item 通过 `material` 类型在 Alchemy Lab 中使用
- 玩家流程：**Plant Editor 配置植物 → 游戏内种植 → 收获材料 → Alchemy Lab 炼药**
- 未来：高级植物可产出稀有材料，解锁高级配方

---

## 实现路线

1. **Phase 1** — Plant Data Schema + Plant Editor（增删改查 JSON）
2. **Phase 2** — 种植场景（地块网格、回合 tick、生长/水分/压力计算）
3. **Phase 3** — 玩家操作（除草/种植/浇水/收获 UI + 交互）
4. **Phase 4** — 炼药集成 + 测试入口（从标题屏幕进入种植场景）
5. **Future** — 天气系统、季节系统、跨场景时间同步
