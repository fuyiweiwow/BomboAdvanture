# Front Face (stand_3_0) Pipeline — Design Decisions

## Face Direction Reference
- stand_0_0 = 右 (3/4 侧面)
- stand_1_0 = 后 (背对屏幕)
- stand_2_0 = 左 (3/4 侧面)
- stand_3_0 = 前 (正脸)

## 正脸 (stand_3_0) 特征
- 原始尺寸: 36×34 px
- 裁切后模板尺寸: 33×33 px (crop_offset=[1,0], 去掉左侧透明列)
- Q版风格: 无鼻子, 无嘴巴
- **脸本身没有头发** — 头发是额外装饰物, 不属于基础脸模板

## 区域定义
| 区域 | 像素数 | 说明 |
|------|--------|------|
| skin | 776 | 整个头部轮廓(含头顶), 基础肤色 |
| eyes_brows_ears | 100 | 眼睛+眉毛+耳朵, 作为一个整体装饰项替换 |
| accessory | 16 | 嘴部位置, 留空供未来饰品渲染 |

### eyes_brows_ears 范围
- **眼睛**: y=20-22, x=9-11(左) / x=21-23(右) — 暗红色瞳孔 (lum~39)
- **眉毛**: y=17-19, x=9-11(左) / x=21-23(右) — 眼睛上方3行
- **耳朵**: y=10-18 面部轮廓最宽处 (bulge), 左 x=2-5 / 右 x=27-30

### accessory 范围
- x=15-18, y=24-27 — 嘴部位置(原图只有肤色, 无嘴)

## 管线架构 (v5)
1. AI参考图生成: Counterfeit-V3.0 (512×528 → resize到33×33)
2. 逐区域调色板提取: 
   - 从33×33 AI图中采样每个区域的像素颜色
   - 量化到16级 → 取频率最高N个 → 按亮度去重
   - Palette size: skin=12, eyes_brows_ears=6, accessory=4
3. 调色板应用到模板:
   - 从 atlast 裁出模板对应方向的参考帧 (stand_0_0/stand_3_0/等)
   - 根据参考帧每个像素的亮度, 匹配最近的调色板颜色
4. 输出: 33×33 PNG (component + eye mask + mouth mask + atlas)

## 环境配置
- Python: `C:\Users\Admin\AppData\Local\Programs\Python\Python311\python.exe` (有CUDA torch)
- Venv: `E:\env\venv` (仅用于测试Pillow脚本, 无torch)
- 模型: Counterfeit-V3.0 at `E:\env\ComfyUI\models\checkpoints\`
- 镜像: pip → Tsinghua, huggingface → hf-mirror.com
- HF缓存: `E:\env\cache\huggingface`

## 模板文件格式
```json
{
  "name": "face10101_stand_3_0",
  "width": 33,
  "height": 33,
  "crop_offset": [1, 0],
  "pixels": { "region_name": [[x,y], ...] },
  "count": { "region_name": pixel_count }
}
```

## 关键文件位置
- 模板: `assets/train/face_annotations/front_region_template.json`
- 管线: `src/tools/test/ro_pipeline_v5.py`
- 模板构建: `src/tools/test/build_front_template.py`
- 输出: `assets/test/ro_component_v5_front_v4/`

## 未来的方向
- 头发作为独立装饰层 (不在base template中)
- 嘴部位置 (accessory) 用于渲染饰品
- 模板可扩展到其他 face ID (face10201, face10301 等)
