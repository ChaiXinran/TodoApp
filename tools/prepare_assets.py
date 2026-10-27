"""Fetch pinned open-source runtime assets; artwork remains in the repository."""
from pathlib import Path
import hashlib, shutil, urllib.request
root=Path(__file__).resolve().parent.parent
assets=[
 ('assets/fonts/NotoEmoji.ttf','https://raw.githubusercontent.com/google/fonts/main/ofl/notoemoji/NotoEmoji%5Bwght%5D.ttf','de6c18832938afc99caf132b39d6a30a19bac7f2e812e28db2535b4608d27551'),
 ('web/sqlite3.wasm','https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.8.0/sqlite3.wasm','efd308be92a34f3aa15f289a37f213b0230fd80888a1364326ee29579d892d37'),
 ('assets/fonts/NotoSansSC.ttf','https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf','a3041811a78c361b1de50f953c805e0244951c21c5bd412f7232ef0d899af0da'),
]
for name,url,digest in assets:
 path=root/name;path.parent.mkdir(parents=True,exist_ok=True)
 if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest()!=digest:
  with urllib.request.urlopen(url,timeout=90) as response: data=response.read()
  if hashlib.sha256(data).hexdigest()!=digest:raise RuntimeError('Asset checksum mismatch: '+name)
  path.write_bytes(data)
 print('Verified',name)
for name in ['Icon-512.png','Icon-maskable-512.png']:
 shutil.copy2(root/'assets/branding/richang_cover.png',root/'web/icons'/name)

licenses=root/"web"/"licenses"
licenses.mkdir(parents=True,exist_ok=True)
for source,target in [("assets/fonts/OFL.txt","NotoSansSC-OFL.txt"),("assets/fonts/EMOJI_OFL.txt","NotoEmoji-OFL.txt"),("tools/vendor/SQFLITE_LICENSE","SQLite-worker-BSD.txt")]:
 shutil.copy2(root/source,licenses/target)
