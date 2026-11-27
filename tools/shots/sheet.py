"""Contact sheet from recorded frames.
python -I tools/shots/sheet.py <frames_dir> <out.png> --start 0 --count 16 --step 2 --crop cx,cy,w,h --cols 8 --scale 1
"""
import argparse, glob, os
from PIL import Image, ImageDraw

ap = argparse.ArgumentParser()
ap.add_argument("dir"); ap.add_argument("out")
ap.add_argument("--start", type=int, default=0); ap.add_argument("--count", type=int, default=16)
ap.add_argument("--step", type=int, default=2); ap.add_argument("--cols", type=int, default=8)
ap.add_argument("--crop", default="640,360,1280,720"); ap.add_argument("--scale", type=float, default=1.0)
a = ap.parse_args()
files = sorted(glob.glob(os.path.join(a.dir, "f*.png")))
cx, cy, w, h = map(int, a.crop.split(","))
tw, th = int(w * a.scale), int(h * a.scale)
picks = files[a.start::a.step][: a.count]
rows = (len(picks) + a.cols - 1) // a.cols
sheet = Image.new("RGB", (tw * a.cols + a.cols - 1, th * rows + rows - 1), (255, 0, 255))
for i, f in enumerate(picks):
    im = Image.open(f).convert("RGB").crop((cx - w // 2, cy - h // 2, cx + w // 2, cy + h // 2))
    if a.scale != 1:
        im = im.resize((tw, th), Image.NEAREST)
    ImageDraw.Draw(im).text((3, 2), os.path.basename(f)[1:-4].lstrip("0") or "0", fill=(255, 255, 255))
    sheet.paste(im, ((i % a.cols) * (tw + 1), (i // a.cols) * (th + 1)))
sheet.save(a.out)
print(a.out, sheet.size, len(picks), "frames")
