# 自有脸部基底生成

## 设计边界

项目喜欢原作的大头比例、圆润头型和大眼视觉语言。这里保留的是高层设计方向，不复制原作的具体表达。自有脸部生成器必须满足：

- 不读取 `assets/img/face`、`assets/frame/face`、`assets/test/face_bases_v1` 或旧 annotation。
- 不复制旧像素、旧 mask、旧 palette、旧坐标和旧帧 JSON。
- 不依赖 Image API、云端模型或第三方生成服务。
- 使用本地 Pillow/标准库按规则绘制，所有输出由 `seed + factors + generator_version` 决定。
- 输出保持独立组件，合成图只用于预览和验收。

## 运行时契约

使用 `36x34` RGBA 逻辑帧作为工程兼容尺寸，但轮廓、插槽、色板和五官布局全部重新设计。`native_face_v1` 是无耳朵基线，`native_face_v2` 加入人耳，`native_face_v3` 采用无可见嘴部的大眼 Q 版脸，`native_face_v4` 增加发型预留区、无脖子契约和轻微横向拉伸的大眼，并支持 `pixel_scale=2` 的 `72x68` 高清输出。所有尺寸共享同一套逻辑像素分布。输出层为：

```text
Ear
+ Base
+ Hair
+ SocketCover
+ Eye
+ Brow
+ Mouth
= Composite
```

方向使用 `D/L/R/U`。首轮生成四方向站立帧；通过验收后再生成四方向行走帧，最终形成 28 帧角色脸部资源。

## 视觉目标

- 头部占画面主体，保持清晰的大头小身阅读关系。
- 眼睛较大、轮廓清晰，但使用新的眼白、虹膜、瞳孔、高光形状和自有色板。
- 眉毛独立于眼睛，可按厚度、弧度和倾斜变化。
- 皮肤轮廓使用新的像素阶梯和阴影布局。
- 保持 Q 版无鼻无嘴阅读方式；`mouth` 只保留透明装饰槽位，未来饰品可以单独覆盖。
- 通过深色轮廓、宝石色虹膜和克制的幻想色板保持西幻角色的可读性。
- 头顶和额头保留较大的 crown 区，发型通过独立层覆盖，不把发型写死在脸部基底。
- 不绘制脖子；角色身体和服装接入时从头部下缘直接连接。

## 因子与记录

每次生成必须记录：

```json
{
  "generator_version": "native_face_v4",
  "seed": 20260727,
  "factors": {
    "head_shape": "round_soft",
    "skin_palette": "coral_01",
    "eye_style": "large_round_01",
    "brow_style": "soft_arc_01",
    "ear_type": "human",
    "size": "medium",
    "angle": "neutral",
    "point": "round",
    "inner_color": "warm_rose",
    "visibility": "full",
    "mouth_status": "reserved_decoration_only",
    "hair_status": "reserved_decoration_only",
    "neck_status": "absent"
  },
  "source": "procedural_local"
}
```

## 验收标准

- 同一 seed 的所有组件 PNG 字节一致。
- 输出尺寸、方向和图层名称稳定。
- `pixel_scale=1` 输出 `36x34`，`pixel_scale=2` 输出 `72x68`，高清输出只是逻辑像素的稳定放大。
- Composite 只来自本次生成的 Base 和组件。
- `mouth` 层保持完全透明，合成图中不出现可见嘴部像素。
- 正面双眼保持大眼比例，不能退化为点状眼。
- `hair` 层保持独立，逻辑预留区为 `x=3..32, y=0..13`。
- 眼睛保持纵向高度，同时只做轻微横向扩展，避免变成扁平横线。
- 生成器源码中不存在旧脸部资源路径。
- 新资产与已知旧资源不共享文件内容 SHA。
- 旧参考资源删除或替换后，生成器仍可独立运行。

## 特征保留与风险边界

为了最大限度保留项目喜欢的感觉，只把下列高层、可测量目标作为设计约束：

- Q 版大头小身、圆润头型和西幻像素角色的清晰轮廓。
- 眼睛在脸部占比较大、四方向切换时保持同一视觉重点。
- 无鼻无嘴的简洁面部阅读，嘴部只作为透明装饰槽位。
- 耳朵、眼睛、眉毛分别作为可替换组件，维持既有运行时组合方式。

必须重新设计的内容包括具体轮廓像素、像素坐标、mask、调色板、阴影排列、虹膜结构、帧数据和品牌/角色命名。生成器不读取旧图片或旧标注，因此高清输出只是自有逻辑像素的清晰放大，不是旧资源的放大或临摹。该流程能降低相似性风险，但不能替代针对最终发行包的知识产权审查。

## 耳朵阶段结果

耳朵不写入 `Base`。`native_face_v4` 已在同一坐标契约上实现人耳，并记录 `size`、`angle`、`point`、`inner_color` 和 `visibility` 因子。耳朵先绘制，`Base` 再覆盖头部内侧，避免耳朵颜色侵入头部轮廓。

下一步再扩展精灵耳和兽耳，并为每种类型增加独立的边界、遮挡和方向测试。
