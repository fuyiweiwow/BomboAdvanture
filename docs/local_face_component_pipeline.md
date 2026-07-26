# 本地脸部组件测试管线

## 目标

本管线只使用本地文件、手动标注和固定随机种子，不调用图像 API。它把 `face10101` 的 28 个正面/侧面/背面站立与行走帧转换成：

- `base`：删除眉毛、眼睛、耳朵并用原始邻近像素补齐的干净底图
- `eye_eyeball`、`eye_iris`、`eye_pupil`、`eye_highlight`：眼睛原子层
- `brow`：眉毛层
- `ear`：耳朵层
- `composite`：用于验收的合成图，不作为唯一运行时资产
- 每套组件对应的 `*.json` 帧数据和 `manifest.json`

默认输出：

```text
assets/test/male_face_v3_local/
  variant_01/  # soft_blue_open
  variant_02/  # amber_half_lid
```

## 运行

在 E 盘项目根目录执行：

```powershell
E:\env\venv\Scripts\python.exe src\tools\test\local_face_components.py
```

固定随机种子可复现同一批结果：

```powershell
E:\env\venv\Scripts\python.exe src\tools\test\local_face_components.py --seed 20260726
```

## 组合决策

底层采用组件化，外层提供预组 preset：

```text
FaceBase + Hair + EyeEyeball + EyeIris + EyePupil + EyeHighlight
         + Brow + Ear + Blush + Beard + Mouth
```

眼睛和眉毛在数据层保持独立，以便换色、替换单一部件和组合更多表情；编辑器层可以把它们绑定成一个 preset。耳朵保持独立，因为耳朵首先受朝向影响，不应和眼睛样式强绑定。`composite` 预览用于验收，正式运行时仍建议按组件加载。

## 当前限制

本轮只验证男性 `face10101` 的标注坐标。女性底图应复用同一套 JSON 结构，新增对应标注后使用同一生成器；发型、腮红、胡子、嘴巴可沿用相同的全帧坐标契约接入，不需要复制两套角色逻辑。

正式接入 Godot 时，需要在现有 `LayerConfig` 中增加 `Brow`、`Blush`、`Beard` 等可选层，并让它们进入对应朝向的 draw order。现有眼睛子组件可以直接复用。
