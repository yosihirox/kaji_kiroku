#!/usr/bin/env python3
"""アプリに同梱する丸ゴシック（Zen Maru Gothic）を、よく使う文字だけに絞る。

元のフォントは1ウェイト約3.8MBあるので、ブラウザ版の読み込みを軽くするために
「かな・英数字・記号・JIS第1水準の漢字＋家事でよく使う第2水準の漢字」に絞っている。
ここに入っていない文字は、スマホでは端末のフォント、ブラウザ版では自動で読み込まれる
フォントで表示される。

使い方（fonttools が必要: pip install fonttools）:

    python3 tool/subset_font.py <元のフォントのフォルダ> assets/fonts

元のフォントは https://github.com/google/fonts/tree/main/ofl/zenmarugothic にある。
"""
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

WEIGHTS = ["Medium", "Bold"]

# JIS第1水準に入っていないが、家事・暮らしの言葉や名前で使いそうな漢字。
EXTRA_KANJI = (
    "炒茹埃黴箒嗽絆笥毯絨躾檻餃麩饅焙捌搾濾噛喋咳痒揉拶挨曖彙嗅惧憬傲恣摯羞緻"
    "塡剝頰瘍訃嘩贅饂飩醬嚙絣繕縫罠蠅蟻蜘蛛蚤虱黍粥糀麹涎瞼睫眩痣疹癒腱"
    "髙﨑濵德彅凜凛琥珀瑛翔颯陽葵莉蓮湊蒼結愛菜"
)


def jis_x_0208(rows):
    chars = set()
    for row in rows:
        for cell in range(1, 95):
            try:
                chars.add(bytes([0xA0 + row, 0xA0 + cell]).decode("euc_jp"))
            except UnicodeDecodeError:
                pass
    return chars


def wanted_codepoints():
    chars = set()
    chars |= {chr(c) for c in range(0x20, 0x7F)}  # 英数字
    chars |= {chr(c) for c in range(0xA0, 0x100)}  # ラテン文字の記号
    chars |= jis_x_0208(range(1, 9))  # 記号・かな・全角英数字
    chars |= jis_x_0208(range(16, 48))  # 第1水準の漢字
    chars |= {chr(c) for c in range(0x3040, 0x3100)}  # ひらがな・カタカナ
    chars |= {chr(c) for c in range(0xFF00, 0xFFF0)}  # 全角・半角形
    chars |= set("‐‑–—―‘’“”•…‥※′″〜～♪♡♥★☆✓✔①②③④⑤⑥⑦⑧⑨⑩㎝㎏㎡℃")
    chars |= set(EXTRA_KANJI)
    return sorted(ord(c) for c in chars)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    dst.mkdir(parents=True, exist_ok=True)
    codepoints = wanted_codepoints()
    for weight in WEIGHTS:
        font = TTFont(src / f"ZenMaruGothic-{weight}.ttf")
        options = subset.Options()
        options.layout_features = ["*"]
        options.name_IDs = ["*"]
        options.notdef_outline = True
        options.glyph_names = False
        options.hinting = False
        subsetter = subset.Subsetter(options)
        subsetter.populate(unicodes=codepoints)
        subsetter.subset(font)
        out = dst / f"ZenMaruGothic-{weight}.ttf"
        font.save(out)
        print(f"{out}: {out.stat().st_size / 1e6:.2f} MB, "
              f"{len(font.getBestCmap())} 文字")


if __name__ == "__main__":
    main()
