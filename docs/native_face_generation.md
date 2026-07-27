# 自有脸部基底生成

## 设计边界

项目喜欢原作的大头比例、圆润头型和大眼视觉语言。这里保留的是高层设计方向，不复制原作的具体表达。自有脸部生成器必须满足：

- 不读取 `assets/img/face`、`assets/frame/face`、`assets/test/face_bases_v1` 或旧 annotation。
- 不复制旧像素、旧 mask、旧 palette、旧坐标和旧帧 JSON。
- 不依赖 Image API、云端模型或第三方生成服务。
- 使用本地 Pillow/标准库按规则绘制，所有输出由 `seed + factors + generator_version` 决定。
- 输出保持独立组件，合成图只用于预览和验收。

## 运行时契约

第一版使用 `36x34` RGBA 帧作为工程兼容尺寸，但轮廓、插槽、色板和五官布局全部重新设计。输出层为：

```text
Base
+ SocketCover
+ Eye
+ Brow
+ Ear
= Composite
```

方向使用 `D/L/R/U`。首轮生成四方向站立帧；通过验收后再生成四方向行走帧，最终形成 28 帧角色脸部资源。

## 视觉目标

- 头部占画面主体，保持清晰的大头小身阅读关系。
- 眼睛较大、轮廓清晰，但使用新的眼白、虹膜、瞳孔、高光形状和自有色板。
- 眉毛独立于眼睛，可按厚度、弧度和倾斜变化。
- 皮肤轮廓使用新的像素阶梯和阴影布局。
- 不使用原作的无鼻/无口细节组合；自有版本至少通过微小的鼻口或面部标记建立独立识别点。

## 因子与记录

每次生成必须记录：

```json
{
  "generator_version": "native_face_v1",
  "seed": 20260727,
  "factors": {
    "head_shape": "round_soft",
    "skin_palette": "coral_01",
    "eye_style": "large_round_01",
    "brow_style": "soft_arc_01"
  },
  "source": "procedural_local"
}
```

## 验收标准

- 同一 seed 的所有组件 PNG 字节一致。
- 输出尺寸、方向和图层名称稳定。
- Composite 只来自本次生成的 Base 和组件。
- 生成器源码中不存在旧脸部资源路径。
- 新资产与已知旧资源不共享文件内容 SHA。
- 旧参考资源删除或替换后，生成器仍可独立运行。

## 后续耳朵

耳朵不写入 Base。完成脸部基底后，在同一坐标契约上增加 `size`、`angle`、`point`、`inner_color` 和 `visibility` 因子。先实现人耳，再实现尖耳和兽耳，并为每种类型增加独立的边界和重叠测试。

