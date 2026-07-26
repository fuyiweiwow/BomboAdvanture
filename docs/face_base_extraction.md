# 基础脸提取结果

本轮使用原始 `assets/img/face` 的像素和 `assets/test/male_face_v2/annotations.json`，没有调用图像 API、没有 AI 补图、没有邻近像素填洞。

## 选定基础脸

- 男：`face10101`
- 女：`Face10701`
- 女脸默认基础层保留腮红。`Face10701` 的正面帧检测到 21 个腮红像素，全部保持原色；28 帧合计 181 个腮红像素。

## 输出

```text
assets/test/face_bases_v1/
  male/
    original/       原始帧
    base/           去眉毛、眼睛、耳朵；其余像素原样保留
    base_no_blush/  额外去除腮红的可选版本
    eye_sclera/     原始眼白
    eye_iris/       原始虹膜
    eye_pupil/      原始瞳孔
    eye_highlight/  原始高光
    lash/           原始睫毛/眼线
    brow/           原始眉毛
    ear/            原始耳朵
    blush/          腮红参考层
    composite/      原始组件重组校验图
    mask/           区域颜色调试图
    preview/        四向站立放大预览
  female/           同上
  manifest.json
```

基础层的透明孔位是有意保留的：运行时由新的眼睛、眉毛和耳朵组件覆盖，避免任何人工补色改变脸部原始轮廓。`composite` 不是正式运行资源，只用于验收；当前男女各 28 帧的重建误差均为 0 像素。

## 重新运行

```powershell
E:\env\venv\Scripts\python.exe "E:\WorkProject\Bomb adventure\BomboAdvanture\src\tools\test\extract_face_bases.py"
```

只提取一种角色时：

```powershell
E:\env\venv\Scripts\python.exe "E:\WorkProject\Bomb adventure\BomboAdvanture\src\tools\test\extract_face_bases.py" --face female
```

## 组合建议

底层继续保持独立组件：`Base + Eye + Brow + Ear + Hair + Blush + Beard + Mouth`。编辑器或随机生成器再提供预组 `preset`，例如“蓝眼厚眉”“棕眼细眉”“女脸保留腮红”。这样可以换色、替换单个组件，也能避免把某一套眼睛和眉毛永久绑定。
 
## Parameterized local factor experiment

The extracted bases are immutable inputs. Generate prompt-driven component layers with:

```powershell
E:\env\venv\Scripts\python.exe "E:\WorkProject\Bomb adventure\BomboAdvanture\src\tools\test\generate_factor_faces.py" --prompt "细眉、小眼、精灵耳" --seed 20260726
```

The current parser accepts the Chinese prompt tokens used by the design document. The output is written to `assets/test/face_factor_v1/` and contains separate `socket_cover`, `eye`, `brow`, `ear`, and `composite` layers for both roles. Runtime composition order is `base -> socket_cover -> eye -> brow -> ear`; the female `base` keeps the extracted blush pixels.

`seed` is deterministic. It selects bounded shape variations and is recorded in `prompts/factors.json` together with both normalized and resolved factors. A different seed can produce a different component set without changing the prompt categories.
