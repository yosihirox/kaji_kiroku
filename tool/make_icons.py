"""アプリのアイコン（Web・Android・iOS）を作る。

    python3 tool/make_icons.py

ティール色の地に、白い家とチェックマーク。Pillow が必要。
"""
import json
import os
from PIL import Image, ImageDraw

TEAL = (31, 122, 110, 255)
WHITE = (255, 255, 255, 255)
S = 4  # 縁をなめらかにするため、大きく描いてから縮める


def draw_mark(d, size, scale):
    """size×size の中央に、scale 倍の大きさで家とチェックを描く。"""
    c = size / 2

    def p(x, y):  # -0.5〜0.5 の座標を画素に
        return (c + x * size * scale, c + y * size * scale)

    w = size * scale
    # 屋根
    roof = [p(-0.40, -0.02), p(0.0, -0.38), p(0.40, -0.02)]
    d.line(roof, fill=WHITE, width=int(w * 0.105), joint='curve')
    r = w * 0.0525
    for x, y in (roof[0], roof[2]):
        d.ellipse((x - r, y - r, x + r, y + r), fill=WHITE)
    # 壁
    d.rounded_rectangle((*p(-0.285, -0.10), *p(0.285, 0.36)),
                        radius=w * 0.075, fill=WHITE)
    d.polygon([p(-0.285, -0.1235), p(0.0, -0.38), p(0.285, -0.1235),
               p(0.285, 0.05), p(-0.285, 0.05)], fill=WHITE)
    # チェック
    check = [p(-0.135, 0.105), p(-0.035, 0.205), p(0.15, 0.005)]
    d.line(check, fill=TEAL, width=int(w * 0.085), joint='curve')
    r = w * 0.0425
    for x, y in check:
        d.ellipse((x - r, y - r, x + r, y + r), fill=TEAL)


def icon(size, *, radius=0.0, scale=0.74, background=TEAL):
    big = size * S
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if background:
        d.rounded_rectangle((0, 0, big - 1, big - 1),
                            radius=big * radius, fill=background)
    draw_mark(d, big, scale)
    return img.resize((size, size), Image.LANCZOS)


def save(img, path, *, opaque=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if opaque:
        img = img.convert('RGB')
    img.save(path, optimize=True)


def main():
    # アプリの中で見せるロゴ
    save(icon(256, radius=0.24), 'assets/images/app_icon.png')

    # Web
    save(icon(32, radius=0.24), 'web/favicon.png')
    for n in (192, 512):
        save(icon(n, radius=0.24), f'web/icons/Icon-{n}.png')
        # マスク用は、切り抜かれても欠けないよう小さめに描く
        save(icon(n, scale=0.58), f'web/icons/Icon-maskable-{n}.png',
             opaque=True)

    # Android
    for name, n in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
                    ('xxhdpi', 144), ('xxxhdpi', 192)):
        save(icon(n, radius=0.24),
             f'android/app/src/main/res/mipmap-{name}/ic_launcher.png')

    # iOS（角丸は OS が付けるので四角のまま、透明なし）
    dir_ = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    with open(f'{dir_}/Contents.json') as f:
        contents = json.load(f)
    for image in contents['images']:
        px = round(float(image['size'].split('x')[0])
                   * int(image['scale'][0]))
        save(icon(px), f"{dir_}/{image['filename']}", opaque=True)


if __name__ == '__main__':
    main()
