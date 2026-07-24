# 美术资源设计

## 美术风格

- **风格**: Ragnarok Online (RO) 软萌像素风 + QQTang 大头小身 Q 版比例
- **角色高度**: ~22px（body 14px + foot 8px 正面）
- **单帧尺寸**: 18×26px
- **渲染方案**: 混合式 body + decoration 系统

## 角色渲染系统

```
Character (JSON)
├── Body (素体)      → 完整角色模板（默认衣着，面部留白）
├── Face (面部装饰)   → 眼睛+嘴巴，多种风格独立叠加
├── Hair (发型装饰)    → 发型覆盖层
├── Cloth (服装装饰)   → 衣着覆盖层
└── Cap (帽子装饰)     → 头饰覆盖层
```

装饰层只做简单叠加，不涉及变形/融合。

## AI 生成工具

### 首选：Sprite AI（MCP 方案）

| 项目 | 说明 |
|------|------|
| 地址 | https://www.sprite-ai.art |
| MCP | 支持（可以直接在 OpenCode 中调用） |
| 免费额度 | 注册送 15 tokens（1 token/精灵图） |
| 订阅 | Creator $8/月（100 张），Studio $24/月（400 张） |
| 买断 | Game Jam Pack $10（100 张） |
| 输出 | 透明 PNG，支持动画，有 JSON 帧数据 |
| 风格 | 像素艺术，支持 8-bit/16-bit/character/item/creature |
| 商业授权 | 免费套餐包含 |

**配置方式**：替换 `opencode.jsonc` 中的 MCP 配置

### 备选 1：SEELE AI（网页工具）

| 项目 | 说明 |
|------|------|
| 地址 | https://www.seeles.ai/features/tools/sprite |
| 使用方式 | 网页直接使用，无需登录 |
| 免费额度 | 基本使用无需登录，登录后无限生成 |
| 输出 | 透明 PNG + JSON 帧数据，支持动画 sprite sheet |
| 风格 | chibi / pixel art / anime 等 |
| 商业授权 | 免费套餐包含，无水印 |
| 引擎兼容 | Godot / Unity / Unreal / GameMaker |

**适用场景**：当 MCP 方案不可用时的后备，需手动下载文件。

### 备选 2：Sprinkle / Pollinations.ai（已测试不适用）

- Pollinations.ai：能生成高清 RGB 图片，但无法出透明 PNG 像素艺术精灵图
- SpriteCook：MCP 已配置，40 credits 额度已用完 36，不适合长期使用

## 管线脚本

所有管线工具在 `src/tools/test/` 下：

| 脚本 | 功能 |
|------|------|
| `spritecook_convert.py` | SpriteCook 输出 → frame JSON + atlas |
| `gen_test_faces.py` | 生成 5 种面部装饰占位图 |
| `test_character_loader.gd` | 独立测试资源加载器 |
| `test_preview_v2.gd` | 交互式预览（1-5 切换表情，WASD 朝向，空格行走） |

## 资源目录结构

```
assets/
├── img/{type}/      → 帧 PNG（body/cloth/hair/face/eye 等）
├── frame/{type}/    → 帧 JSON 元数据
├── test/            → 测试/临时美术资源
│   ├── body/        → 素体测试图
│   ├── face/        → 面部装饰测试图
│   └── hero/        → 完整角色测试 JSON
└── plant/           → 植物数据（种植系统）
```

## 人物生成准则

### 风格锁定

每次生成 prompt 中必须包含以下风格锚点：

```
chibi pixel art, Ragnarok Online style, QQTang proportions big head small body,
16-bit RPG sprite, transparent background
```

### Body 素体生成

| 字段 | 值 |
|------|-----|
| asset_type | `character` |
| width/height | `128`（素体需要稍大尺寸保留细节） |
| cost | 1 token |

Prompt 结构：
```
chibi pixel art character body mannequin, front facing,
bald, naked, blank face no eyes no mouth, simple body,
[风格锚点]
```

**关键约束：**
- 面部必须留白（no eyes, no mouth, blank face）—— 因为表情由独立 Face 装饰层提供
- 正面朝向（front facing）—— 当前只做正面，后续扩展四方向
- 素体含默认简单衣着（body 是不裸体但有留白），后续由 Cloth 装饰覆盖

### Face 面部装饰生成

| 字段 | 值 |
|------|-----|
| asset_type | `character` |
| width/height | `64`（面部特写不需要太大） |
| cost | 1 token |

Prompt 结构：
```
chibi pixel art [表情描述] face, transparent background, [风格锚点]
```

已定义的表情种类：

| 表情 | prompt 关键词 |
|------|-------------|
| happy | big cute eyes with white highlights, big smile, round face |
| angry | furrowed eyebrows, angry eyes, frown mouth, cute tantrum |
| shy | blushing cheeks, half-closed eyes, small wavy mouth, embarrassed |
| closed_eyes | closed upward curved eyes, big smile, peaceful |
| blank | simple dot eyes, straight small mouth, calm, no expression |

### Hair / Cloth / Cap 装饰生成

（待定 — 使用相同结构和尺寸规范）

### Sprite AI 调用规范

API 端点：`POST /api/sprites`

```powershell
$headers = @{ Authorization = "Bearer sai_sk_xxxx"; "Content-Type" = "application/json" }
$body = @{
    prompt = "..."
    asset_type = "character"
    width = 64  # 或 128
    height = 64 # 或 128
}
Invoke-RestMethod -Uri "https://www.sprite-ai.art/api/sprites" -Headers $headers -Body ($body | ConvertTo-Json) -Method Post
```

输出处理：
```
$base64 = $result.image.pngBase64
$bytes = [Convert]::FromBase64String($base64)
Set-Content -Path "assets/test/[type]_[name]_spriteai.png" -Value $bytes -Encoding Byte
```

### 命名规范

生成的文件统一命名格式：
```
{type}_{name}_spriteai.png
```

| type | 说明 |
|------|------|
| body_mannequin | 空白素体 |
| face | 面部表情 |
| hair | 发型 |
| cloth | 服装 |
| cap | 帽子 |

### Token 预算管理

- Sprite AI 注册送 15 tokens
- 1 character sprite = 1 token
- 1 animation = 14-28 tokens
- 用完可买 $10 Game Jam Pack（100 tokens）或订阅 $8/月 Creator（100 tokens/月）
- 生成前先用 `GET /api/balance` 检查余额

### 新增资源流程

1. 使用 AI 工具生成原始素材 → `assets/test/`
2. 手动检查效果
3. 调整 prompt 重新生成直到满意
4. 通过管线脚本转成 frame JSON + atlas
5. 迁移到 `assets/` 正式目录
