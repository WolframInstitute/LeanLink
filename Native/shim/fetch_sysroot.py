"""Fetch only what the LeanLink shim build needs from a Lean release zip: its headers and its shared
runtime libraries, about 60 MB of a 900 MB zip, read by HTTP range requests through the zip's central
directory, into the directory layout build.sh cross-compiles against.

    python3 fetch_sysroot.py VERSION PLATFORM CACHE_DIR      e.g. 4.35.0 linux .cache/lean_cross
"""
import io, sys, zipfile, urllib.request, pathlib, re

class RangeFile(io.RawIOBase):
    def __init__(self, url):
        self.url, self.pos = url, 0
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req) as r:
            self.size = int(r.headers["Content-Length"])
    def readable(self): return True
    def seekable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = {0: offset, 1: self.pos + offset, 2: self.size + offset}[whence]
        return self.pos
    def readinto(self, b):
        if self.pos >= self.size: return 0
        end = min(self.pos + len(b), self.size) - 1
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req) as r:
            data = r.read()
        b[:len(data)] = data
        self.pos += len(data)
        return len(data)

version, platform, cache = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3])
url = f"https://github.com/leanprover/lean4/releases/download/v{version}/lean-{version}-{platform}.zip"
root = f"lean-{version}-{platform}/"
wanted = re.compile(r"^" + re.escape(root) + r"(include/.*|lib/lean/lib\w*shared[\w.]*|bin/lib\w*shared\w*\.dll)$")
archive = zipfile.ZipFile(io.BufferedReader(RangeFile(url), buffer_size=8 << 20))
members = [m for m in archive.infolist() if wanted.match(m.filename) and not m.is_dir()]
print(platform, len(members), "members,", sum(m.compress_size for m in members) // 2**20, "MB compressed", flush=True)
for m in members:
    archive.extract(m, cache)
print("done", platform, flush=True)
