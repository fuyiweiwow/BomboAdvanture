"""Full SpriteCook -> godot asset pipeline for hybrid body+face system.

Usage:
  # 1. Generate a blank base body (4 directions, idle+walk) via SpriteCook API
  python spritecook_pipeline.py generate-body --prompt "..." --out assets/test/body/blank01

  # 2. Generate face decorations (eyes + mouth overlays)
  python spritecook_pipeline.py generate-face --prompt "..." --out assets/test/face/happy

  # 3. Create a hero JSON combining body + face
  python spritecook_pipeline.py create-hero --name MyHero --body blank01 --face happy --out assets/test/hero

  # 4. Rebuild all atlases
  python spritecook_pipeline.py build-atlases

See subcommands for details.
"""

import json
import os
import sys
import subprocess
from PIL import Image


API_KEY = "sc_live_871d5ff4cbf1643db019e315ee89945dd20f51b9a8ee8220"
API_BASE = "https://api.spritecook.ai/v1"
ASSET_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../assets"))


def api_call(method, endpoint, data=None):
    """Call SpriteCook REST API."""
    import urllib.request
    import urllib.error
    
    url = f"{API_BASE}{endpoint}"
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    if data:
        body = json.dumps(data).encode("utf-8")
    else:
        body = None
    
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8") if e.fp else str(e)
        print(f"  API Error {e.code}: {err_body}", file=sys.stderr)
        return None


def download_asset(asset_url, out_path):
    """Download a SpriteCook asset to local file."""
    import urllib.request
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    try:
        urllib.request.urlretrieve(asset_url, out_path)
        print(f"  Downloaded: {out_path}")
        return True
    except Exception as e:
        print(f"  Download failed: {e}", file=sys.stderr)
        return False


def cmd_generate_body(args):
    """Generate a blank body character (4 directions)."""
    print(f"Generating body: {args.name}")
    
    # First create the base character (front view)
    body_data = {
        "prompt": args.prompt or f"a cute chibi character for a topdown bomberman game, "
                                   f"Ragnarok Online inspired pixel art style, QQTang proportions "
                                   f"with big round head and small body, blank face without eyes or mouth, "
                                   f"just skin-colored face area, simple default undershirt, neutral pose, "
                                   f"no accessories, pixel art",
        "perspective": "topdown",
        "name": args.name,
        "model": "gemini-3.1-flash-image"
    }
    
    result = api_call("POST", "/characters", body_data)
    if not result or not result.get("character_id"):
        print("  Failed to create character")
        return
    
    char_id = result["character_id"]
    print(f"  Character ID: {char_id}")
    
    # Download front idle
    out_dir = os.path.join(ASSET_ROOT, "test", "body", args.name)
    for asset in result.get("assets", []):
        url = asset.get("url") or asset.get("sprite_url")
        if url:
            download_asset(url, os.path.join(out_dir, "img", f"{args.name}_front_idle.png"))
    
    return char_id


def cmd_generate_face(args):
    """Generate face decorations (eyes + mouth overlay)."""
    print(f"Generating face: {args.name}")
    
    # Use generate-sync for a simple face overlay sprite
    gen_data = {
        "prompt": args.prompt or f"a pair of cute anime eyes and a small happy mouth, "
                                 f"pixel art, transparent background, Ragnarok Online style, "
                                 f"designed to overlay on a character's blank face area",
        "pixel": True,
        "bg_mode": "transparent",
        "model": "gemini-3.1-flash-image",
        "width": 64,
        "height": 64
    }
    
    result = api_call("POST", "/generate-sync", gen_data)
    if not result:
        return
    
    out_dir = os.path.join(ASSET_ROOT, "test", "face", args.name)
    os.makedirs(out_dir, exist_ok=True)
    
    for asset in result.get("assets", []):
        url = asset.get("url") or asset.get("sprite_url")
        if url:
            download_asset(url, os.path.join(out_dir, "img", f"face_{args.name}.png"))
    
    # Generate face frame JSON
    _make_face_json(args.name, out_dir)
    _build_atlas(out_dir)


def _make_face_json(face_name, out_dir):
    """Create a simple face decoration frame JSON.
    
    Face overlays use a single front-facing frame that gets applied
    to all orientations (for Q-style characters, the face is similar
    from all angles).
    """
    img_dir = os.path.join(out_dir, "img")
    pngs = [f for f in os.listdir(img_dir) if f.endswith(".png") and not f.endswith(".atlas.png")]
    if not pngs:
        return
    
    frame_fn = pngs[0]
    img = Image.open(os.path.join(img_dir, frame_fn))
    cx = img.width // 2
    cy = img.height // 2
    
    face_json = {
        "NAME": face_name,
        "STAND_R": {"IMG": [frame_fn], "CX": [cx], "CY": [cy]},
        "STAND_U": {"IMG": [frame_fn], "CX": [cx], "CY": [cy]},
        "STAND_L": {"IMG": [frame_fn], "CX": [cx], "CY": [cy]},
        "STAND_D": {"IMG": [frame_fn], "CX": [cx], "CY": [cy]},
        "R": {"IMG": [frame_fn, frame_fn, frame_fn], "CX": [cx, cx, cx], "CY": [cy, cy, cy]},
        "U": {"IMG": [frame_fn, frame_fn, frame_fn], "CX": [cx, cx, cx], "CY": [cy, cy, cy]},
        "L": {"IMG": [frame_fn, frame_fn, frame_fn], "CX": [cx, cx, cx], "CY": [cy, cy, cy]},
        "D": {"IMG": [frame_fn, frame_fn, frame_fn], "CX": [cx, cx, cx], "CY": [cy, cy, cy]},
    }
    
    json_path = os.path.join(out_dir, f"{face_name}.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(face_json, f, indent=4, ensure_ascii=False)
    print(f"  Face JSON: {json_path}")


def cmd_create_hero(args):
    """Create a hero JSON that references a body + face."""
    hero = {
        "name": args.name,
        "character": args.body,
        "icon_img": args.body,
        "decorations": {
            "disable_foot_and_leg": True,
            "bomb_skin": "bomb1",
            "cap": None,
            "hair": None,
            "eye": args.face,  # Face decoration replaces eye
            "eye_eyeball": None,
            "eye_iris": None,
            "eye_pupil": None,
            "eye_highlight": None,
            "ear": None,
            "mouth": None,
            "cladorn": None,
            "fpack": None,
            "npack": None,
            "thadorn": None,
            "footprint": None,
            "head_effect": None,
            "body_effect": None
        },
        "blood": args.blood or 4500,
        "speed": args.speed or 5.83333,
        "bomb": args.bomb or 7,
        "restore": args.restore or 700,
        "power": args.power or 3,
        "damage": args.damage or 3500,
        "defense": args.defense or 0,
        "skills": []
    }
    
    out_dir = os.path.join(ASSET_ROOT, "test", "hero")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"{args.name}.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(hero, f, indent=2, ensure_ascii=False)
    print(f"  Hero: {out_path}")


def cmd_build_atlases(args):
    """Rebuild all atlases for test assets."""
    for root, dirs, files in os.walk(os.path.join(ASSET_ROOT, "test")):
        if "img" in dirs:
            img_dir = os.path.join(root, "img")
            pngs = [f for f in os.listdir(img_dir) if f.endswith(".png")]
            if pngs:
                _build_atlas(root)
        # Only check direct test subdirs (body/*, face/*)
        _check_atlas_jsons(root)


def _check_atlas_jsons(dir_path):
    """Check for frame JSONs and ensure atlases exist."""
    for f in os.listdir(dir_path):
        if f.endswith(".json") and not f.endswith(".atlas.json"):
            json_path = os.path.join(dir_path, f)
            try:
                with open(json_path) as fp:
                    data = json.load(fp)
                # Don't rebuild if atlas already exists (and is newer)
                comp_name = os.path.splitext(f)[0]
                atlas_png = os.path.join(dir_path, f"{comp_name}.atlas.png")
                if not os.path.exists(atlas_png) or os.path.getmtime(atlas_png) < os.path.getmtime(json_path):
                    _build_atlas(dir_path)
                    return
            except (json.JSONDecodeError, IOError):
                pass


def _build_atlas(component_dir):
    """Build atlas PNG + atlas JSON (same packing as sprite_sheet_packer.gd)."""
    img_dir = os.path.join(component_dir, "img")
    if not os.path.isdir(img_dir):
        return
    
    pngs = [f for f in os.listdir(img_dir) if f.endswith(".png") and not f.endswith(".atlas.png")]
    if not pngs:
        return
    
    images = []
    for fn in pngs:
        img = Image.open(os.path.join(img_dir, fn)).convert("RGBA")
        images.append({"filename": fn, "image": img, "w": img.width, "h": img.height})
    
    images.sort(key=lambda x: (-x["h"], -x["w"]))
    
    atlas_w = 64
    shelves = []
    frames = {}
    
    for img_data in images:
        fw, fh = img_data["w"], img_data["h"]
        placed = False
        
        for shelf in shelves:
            if fw <= atlas_w - shelf["cursor_x"] and fh <= shelf["h"]:
                frames[img_data["filename"]] = {"x": shelf["cursor_x"], "y": shelf["y"], "w": fw, "h": fh}
                shelf["cursor_x"] += fw
                placed = True
                break
        
        if not placed:
            new_y = shelves[-1]["y"] + shelves[-1]["h"] if shelves else 0
            if fw > atlas_w:
                while atlas_w < fw:
                    atlas_w <<= 1
            shelves.append({"y": new_y, "h": fh, "cursor_x": fw})
            frames[img_data["filename"]] = {"x": 0, "y": new_y, "w": fw, "h": fh}
    
    if not shelves:
        return
    
    total_h = shelves[-1]["y"] + shelves[-1]["h"]
    atlas_h = 1
    while atlas_h < total_h:
        atlas_h <<= 1
    
    atlas_img = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    for img_data in images:
        fn = img_data["filename"]
        f = frames[fn]
        atlas_img.paste(img_data["image"], (f["x"], f["y"]), img_data["image"])
    
    comp_name = os.path.basename(component_dir)
    atlas_png = os.path.join(component_dir, f"{comp_name}.atlas.png")
    atlas_img.save(atlas_png)
    
    atlas_json_data = {"frames": {}}
    for fn in frames:
        f = frames[fn]
        atlas_json_data["frames"][fn] = {"frame": {"x": f["x"], "y": f["y"], "w": f["w"], "h": f["h"]}}
    
    atlas_json_path = os.path.join(component_dir, f"{comp_name}.atlas.json")
    with open(atlas_json_path, "w", encoding="utf-8") as f:
        json.dump(atlas_json_data, f, indent=4, ensure_ascii=False)
    
    print(f"  Atlas: {atlas_png} ({atlas_w}x{atlas_h}, {len(images)} frames)")


def cmd_check_credits(args):
    """Check remaining API credits."""
    result = api_call("GET", "/credits")
    if result:
        print(f"  Credits: {result.get('total', 0)} remaining")
        print(f"  Tier: {result.get('tier', 'unknown')}")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="SpriteCook Game Asset Pipeline")
    sub = parser.add_subparsers(dest="command", help="Sub-command")
    
    p_body = sub.add_parser("generate-body", help="Generate a blank body character")
    p_body.add_argument("--name", required=True, help="Body name (e.g. blank01)")
    p_body.add_argument("--prompt", help="Custom prompt (optional)")
    
    p_face = sub.add_parser("generate-face", help="Generate a face decoration")
    p_face.add_argument("--name", required=True, help="Face name (e.g. happy)")
    p_face.add_argument("--prompt", help="Custom prompt (optional)")
    
    p_hero = sub.add_parser("create-hero", help="Create a hero JSON")
    p_hero.add_argument("--name", required=True, help="Hero name")
    p_hero.add_argument("--body", required=True, help="Body component name")
    p_hero.add_argument("--face", help="Face decoration name")
    for attr in ["blood", "speed", "bomb", "restore", "power", "damage", "defense"]:
        p_hero.add_argument(f"--{attr}", type=float)
    
    p_atlas = sub.add_parser("build-atlases", help="Rebuild all test atlases")
    
    p_credits = sub.add_parser("check-credits", help="Check API credits")
    
    args = parser.parse_args()
    
    if args.command == "generate-body":
        cmd_generate_body(args)
    elif args.command == "generate-face":
        cmd_generate_face(args)
    elif args.command == "create-hero":
        cmd_create_hero(args)
    elif args.command == "build-atlases":
        cmd_build_atlases(args)
    elif args.command == "check-credits":
        cmd_check_credits(args)
    else:
        parser.print_help()
