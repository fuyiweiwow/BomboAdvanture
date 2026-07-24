# 角色部件生成需求

> 使用 Sprite AI（MCP）生成，参考 `docs/art_design.md` 中的人物生成准则

## 待生成清单

### 1. Face Atlas（男女面部集）

两种风格：
- `face_m` — 男性面部
- `face_f` — 女性面部

每个 atlas 含 5 种表情：happy / angry / shy / closed_eyes / blank
参考 Ragnarok Online 面部风格。

### 2. Foot Atlas

脚部精灵图集。
参考 Ragnarok Online 人物脚步风格。

### 3. Eyes Atlas（多种眼睛）

参考仙境传说（Ragnarok Online）画风，生成多种眼睛样式。
每种作为独立装饰层叠加到 Face 之上。

### 4. Hair Atlas（多种发型）

参考各种 2D/3D RPG 画风。
多种发型作为独立 Cap/Hair 装饰层。

### 5. Clothes Atlas（基础服装）

男/女两种造型的基础衣着。
独立 Cloth 装饰层，覆盖 Body 素体的默认衣着。

### 6. Shoes Atlas（鞋子/腿部）

代码中对应 leg 组件。
基础鞋子装饰层。

## 生成顺序

1. Face Atlas（男女各 5 表情）— 优先
2. Foot Atlas
3. Eyes Atlas
4. Hair Atlas
5. Clothes Atlas
6. Shoes (Leg) Atlas

## 风格参考

- 整体风格：Ragnarok Online 软萌像素风 + QQTang 大头小身比例
- 角色高度 ~22px，单帧 18×26px
- 所有部件输出透明 PNG，后续通过管线脚本转 frame JSON + atlas
