"""Pair rendered previews with the exact built-in library descriptions.

Usage: python3 -B tools/stick-figure/preview/gallery.py <preview-output-directory>
"""
from html import escape
from pathlib import Path
import re
import sys

output = Path(sys.argv[1])
seed = Path(__file__).resolve().parents[3] / 'PTHelper/Services/SeedData.swift'
exercises = re.findall(r'Exercise\(name: "([^"]+)",\s*description: "([^"]+)"', seed.read_text())
cards = []
for name, description in exercises:
    slug = '-'.join(re.findall(r'[a-z0-9]+', name.lower()))
    if not (output / f'{slug}.png').exists():
        raise SystemExit(f'Missing preview for {name}')
    motion = (f'<details><summary>Play animation</summary><img class="motion" loading="lazy" '
              f'src="{slug}.gif" alt="Animated demonstration of {escape(name)}"></details>') if (output / f'{slug}.gif').exists() else ''
    cards.append(f'<article><h2>{escape(name)}</h2><p>{escape(description)}</p>{motion}'
                 f'<a href="{slug}.png"><img loading="lazy" src="{slug}.png" alt="Key poses for {escape(name)}"></a></article>')
html = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>PTHelper animation review</title>
<style>
body { background:#101605; color:#f5f7ec; font:16px/1.5 system-ui; max-width:1250px; margin:40px auto; padding:0 20px }
h1 { font-size:32px } h2 { font-size:22px; margin:0 } p { max-width:85ch; color:#cbd1bf }
article { padding:24px; margin:24px 0; border:1px solid #34411e; border-radius:20px }
img { max-width:100%; display:block; margin:16px auto } .motion { max-height:440px; border-radius:16px }
summary { color:#b5ff00; cursor:pointer } a { color:#b5ff00 }
</style><h1>41 exercise animations</h1>
<p>Production-renderer previews alongside the original library instructions. Open “Play animation” for each loop.
These are movement demonstrations; use the app’s timer for prescribed holds.</p>'''
(output / 'index.html').write_text(html + ''.join(cards) + '</html>')
print(output / 'index.html')
