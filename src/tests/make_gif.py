# res://src/tests/make_gif.py
# Assemble the PNG frames produced by gif_selftest into an animated GIF
# (and a static montage for quick review). Requires Pillow.
#   python src/tests/make_gif.py <frames_dir> <out_prefix>
import glob
import os
import sys

from PIL import Image


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: make_gif.py <frames_dir> <out_prefix>")
        return 1
    frames_dir = sys.argv[1]
    out_prefix = sys.argv[2]

    files = sorted(glob.glob(os.path.join(frames_dir, "frame_*.png")))
    if not files:
        print("no frames found in", frames_dir)
        return 1

    frames = [Image.open(f) for f in files]
    gif_path = out_prefix + ".gif"
    frames[0].save(
        gif_path,
        save_all=True,
        append_images=frames[1:],
        duration=50,
        loop=0,
        optimize=False,
    )
    print("gif:", gif_path, len(frames), "frames")

    # montage: grid of sampled frames for static review
    cols = 8
    step = max(1, len(frames) // (cols * 3))
    sampled = frames[::step][: cols * 3]
    if sampled:
        w, h = sampled[0].size
        pad = 4
        rows = (len(sampled) + cols - 1) // cols
        canvas = Image.new("RGB", (cols * (w + pad) + pad, rows * (h + pad) + pad), (20, 20, 20))
        for i, img in enumerate(sampled):
            x = pad + (i % cols) * (w + pad)
            y = pad + (i // cols) * (h + pad)
            canvas.paste(img, (x, y))
        montage_path = out_prefix + "_montage.png"
        canvas.save(montage_path)
        print("montage:", montage_path)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
