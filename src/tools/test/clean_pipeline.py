"""Full cleanup of pipeline output."""
import os, shutil

d = r"E:\WorkProject\Bomb adventure\BomboAdvanture\assets\test\ro_pipeline\face"
for fid in sorted(os.listdir(d)):
    fdir = os.path.join(d, fid)
    if os.path.isdir(fdir):
        # Remove ALL files (not dirs)
        for f in list(os.listdir(fdir)):
            p = os.path.join(fdir, f)
            if os.path.isfile(p):
                os.remove(p)
        print(f"Cleaned {fdir}")
