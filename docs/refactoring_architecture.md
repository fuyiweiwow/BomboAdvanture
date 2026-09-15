# 模块化重构说明

本分支将运行时按职责划分为以下边界：

| 模块 | 责任 | 主要入口 |
| --- | --- | --- |
| `core` | 常量、资源和 JSON 文件访问 | `Utils`、`JsonStore`、`ResourceManager` |
| `game/level` | 地图数据校验、地图生成、关卡运行时 | `MapDataValidator`、`MapGenerator`、`WorldMapGenerator`、`Level` |
| `map` / `level` | 地图目录、关卡目录和进度 | `AdventureMapCatalog`、`AdventureLevelCatalog`、`AdventureLevelProgressRepository` |
| `city` / `item_editor` | 数据驱动的城市与道具内容 | `CityData`、`ItemData` |
| `game/sprite` | 玩家、NPC、炸弹、障碍物和掉落物 | 各 `*_instance.gd` |
| `main` | 场景生命周期、输入和流程编排 | `Game` |

## 数据流约定

1. JSON 文件先经过 `JsonStore` 读取；目录模块不再重复实现文件枚举和解析。
2. 地图进入 `Level` 前由 `MapDataValidator` 规范化，缺失数组使用空数组，坐标会被限制在地图范围内。
3. 生成器只负责产生纯 `Dictionary`，不直接创建节点；`Level` 负责把数据实例化为运行时对象。
4. UI 通过目录/数据模块读取内容，不应直接访问 `FileAccess` 或拼接资源路径。

## 已修正的逻辑风险

- 随机地图的出生点可能被有机地形生成成墙；生成阶段现在会清理出生点周围的安全区域。
- 世界地图相邻区域很窄时，原通道坐标随机范围可能反转并触发运行时错误；现在会回退到重叠区中点。
- 关卡 JSON 缺少 `basic`、`begin`、`scroll` 或可选数组时，原逻辑会直接索引崩溃；现在统一校验并提供安全默认值。
- 城市、道具、地图目录和进度仓储的 JSON 读写行为已统一，解析失败会返回明确的空值/失败结果。

## 回归检查

可使用 Godot 无头模式运行：

```text
godot --headless --path . res://src/tests/refactor_selftest.tscn
godot --headless --path . res://src/tests/world_selftest.tscn
godot --headless --path . res://src/tests/city_selftest.tscn
```

`refactor_selftest` 覆盖地图校验、异常出生坐标和出生点可行走保证；其余自检覆盖世界门、掉落、城市与商店流程。

## 静默测试 PowerShell 包装

项目提供 `tools/run-silent-tests.ps1`，默认使用本项目约定的 Godot Console 路径，并以 JSON 最后一行作为测试报告：

```powershell
.\tools\run-silent-tests.ps1
```

常用参数：

```powershell
# 重新导入资源后运行
.\tools\run-silent-tests.ps1 -Import

# 指定 Godot 或项目目录
.\tools\run-silent-tests.ps1 -Godot "D:\\Tools\\Godot\\Godot_v4.6.2-stable_mono_win64\\Godot_v4.6.2-stable_mono_win64_console.exe" -Project "D:\\Learn\\BomboAdvanture"

# 输出完整 Godot 日志（调试解析错误时使用）
.\tools\run-silent-tests.ps1 -VerboseOutput

# 临时允许已知引擎错误（仅用于诊断，不建议 CI 使用）
.\tools\run-silent-tests.ps1 -AllowEngineErrors
```

退出码为 `0` 表示测试通过且 Godot 未报告脚本/引擎错误；`1` 表示测试断言失败；`2` 表示 Godot 虽返回成功，但日志包含脚本、编译、autoload 或资源错误。新增 feature 时，将测试函数注册到 `silent_test_runner.gd` 的 `_initialize()` 中即可接入统一报告。
