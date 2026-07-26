# 正脸 Pipeline — 设计决策记录

## 方向参考
- `stand_0_0` = 面向右 (3/4 侧面)
- `stand_1_0` = 背对屏幕
- `stand_2_0` = 面向左 (3/4 侧面)  
- `stand_3_0` = 正脸

## 正脸 (stand_3_0) 结构分析

- 原始尺寸: 36×34 px。裁切后模板: 33×33 (crop_offset=[1,0], 去掉左侧透明spike列)
- **Q版风格**: 无鼻子, 无嘴巴
- **脸本身无头发** — 头发是独立装饰层, 不在基底模板中

### 关键修正记录

| 版本 | 问题 | 修正 |
|------|------|------|
| v1 | 误将面部边缘阴影识别为侧发 | 删除侧发, 头发仅限头顶 crown |
| v2 | 头顶 crown 被误识别为头发 | 确认脸是秃的, 删除所有头发区域 |
| v3 | 嘴位置误识别 | Q版无嘴, 删除 mouth/accessory |
| v4 | 眼睛位置实际是眉毛内角 | 扩展装饰区覆盖完整眉毛+眼睛形状 |
| v5 | 耳朵位置在眉毛上方 | 耳朵移到眼睛同一水平线 |
| v6 | 眼睛完全没提取到 (y=24 缺失) | 眼睛在 y=23-25 (lum 0-1 纯黑瞳孔), 耳朵延伸到 y=24 |

### 最终区域定义 (v6)

| 区域 | 像素 | 说明 |
|------|------|------|
| `skin` | 792 | 整个头部轮廓 (含头顶), 基底肤色 |
| `eyes_brows_ears` | 100 | 眉毛+眼睛+耳朵 联合装饰区 |

### 亮度分析 (关键发现)
- **皮肤**: lum 18-22 (亮)
- **眉毛**: lum 5-14 (中度暗) — y=20-22
- **眼睛 (瞳孔)**: lum 0-1 (纯黑) — y=23-25
- 眼睛在眉毛下方 1-2 行

### 眉毛范围
**左侧:** y=20 x=8-12, y=21 x=7-13, y=22 x=9-14
**右侧:** y=20 x=21-26, y=21 x=21-27, y=22 x=20-26

### 眼睛范围 (纯黑瞳孔 lum < 5)
**左侧:** y=23 x=10-14, y=24 x=11-15, y=25 x=12-14
**右侧:** y=23 x=20-24, y=24 x=19-23, y=25 x=20-22

### 耳朵范围
与眼睛同一水平线 (y=19-24), 面部轮廓最宽处的凸起:
**左侧耳:** y=19-24, x=0-2
**右侧耳:** y=19-24, x=30-32

注意: 耳朵最外凸部分 (orig col 0 和 35) 在 33×33 裁切范围之外。

## 管线架构 (ro_pipeline_v5.py)

1. **AI参考图生成**: Counterfeit-V3.0, 512×528 → resize 到模板尺寸 (33×33)
2. **逐区域调色板提取**:
   - 从 33×33 AI 图中采样每个区域所有像素的颜色
   - 量化到 16 级 → 频率最高 N 个 → 按亮度去重
   - 调色板大小: skin=12, eyes_brows_ears=6, accessory=4
3. **调色板应用到模板**:
   - 从 atlas 裁出模板对应方向的参考帧 (crop_offset)
   - 按参考帧像素亮度匹配最近调色板颜色
4. **输出**: 33×33 PNG (component + eye mask + mouth mask + atlas)

## 待办
- 侧脸模板 (stand_0_0) 需补充眉毛区域
- 头发装饰层作为独立系统
- 嘴部位置预留供未来饰品系统

## 环境配置
- Python: `C:\Users\Admin\AppData\Local\Programs\Python\Python311\python.exe` (CUDA torch)
- Venv: `E:\env\venv` (Pillow/numpy only)
- 模型: Counterfeit-V3.0 @ `E:\env\ComfyUI\models\checkpoints\`
- 镜像: pip → Tsinghua, HF → hf-mirror.com
- HF缓存: `E:\env\cache\huggingface`

## 关键文件
| 文件 | 路径 |
|------|------|
| 正脸模板 | `assets/train/face_annotations/front_region_template.json` |
| 侧脸模板 | `assets/train/face_annotations/face10101_region_template.json` |
| 管线脚本 | `src/tools/test/ro_pipeline_v5.py` |
| 模板构建 | `src/tools/test/build_front_template.py` |
| 输出目录 | `assets/test/ro_component_v5_front/` |
| 本文件 | `docs/front_face_pipeline_design.md` |
