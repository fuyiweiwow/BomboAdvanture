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

# 只运行名称包含 map 的模块；可传入多个名称片段
.\tools\run-silent-tests.ps1 -Module map
.\tools\run-silent-tests.ps1 -Module adventure,guild

# 将每个测试套件的等待上限改为 30 秒（默认 10 秒）
.\tools\run-silent-tests.ps1 -SuiteTimeoutSeconds 30

# 临时允许已知引擎错误（仅用于诊断，不建议 CI 使用）
.\tools\run-silent-tests.ps1 -AllowEngineErrors
```

退出码为 `0` 表示测试通过且 Godot 未报告脚本/引擎错误；`1` 表示测试断言失败；`2` 表示 Godot 虽返回成功，但日志包含脚本、编译、autoload、资源或导入错误。

### 新增静默测试

在 `src/tests/silent/` 新建以 `_test.gd` 结尾的脚本。Runner 会自动发现，无需修改中央文件：

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	if 1 + 1 != 2:
		failures.append("calculation failed")
	return failures
```

`run()` 返回空数组表示通过；每个字符串是一条失败原因。测试应避免创建窗口和读取玩家输入。

需要模拟游戏帧时，可把 `run()` 声明为异步测试，并复用 `SilentTestTools`：

```gdscript
const SilentTestTools = preload("res://src/tests/silent_test_tools.gd")

func run() -> Array[String]:
	var failures: Array[String] = []
	await SilentTestTools.advance_frames(5, func(_frame: int) -> void:
		Game.frame_step()
	)
	return failures
```

套件超时后 Runner 会停止调度后续套件并退出进程，避免无法取消的 GDScript 协程污染其他测试；它仍无法抢占阻塞 Godot 主线程的死循环，因此测试代码不得执行不让出主线程的无限循环。未知 `-Module` 会明确失败，避免筛选拼写错误造成“零测试通过”。

### Rogue 强化掉落配置与静默验证

默认掉落配置在 `assets/adventure/rogue_drop_pool.json`。`chance` 是怪物死亡时触发强化掉落的概率（`0..1`）；`entries` 中每项填写已有道具的 `item_id`、`rarity` 和正数 `weight`，权重只决定触发后选中哪个道具。修改 JSON 后运行：

```powershell
.\tools\run-silent-tests.ps1 -Module rogue_drop_integration -VerboseOutput
```

该套件使用临时 `user://` 配置与固定随机种子，构造真实 NPC、拾取物和 Hero，验证死亡、生成与拾取，不需要窗口、玩家操作或现有贴图。非法概率、权重、稀有度、不存在的 `item_id` 或路径穿越 ID 会使整份配置被拒绝，避免运行中随机抽到空道具或读取目录外文件。当前配置是最小玩法切片；重复强化的上限和平衡仍在后续任务中。
