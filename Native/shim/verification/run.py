"""Build and exercise the native evaluator on a hosted Linux or Windows runner."""
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import time
import zipfile
from pathlib import Path

import psutil

here = Path(__file__).resolve().parent
repo = here.parents[2]
temporary = Path(os.environ["RUNNER_TEMP"]) / "leanlink-verification"
temporary.mkdir(exist_ok=True)
results = repo / "verification-results"
results.mkdir(exist_ok=True)
config = json.loads((here / "runtime.json").read_text())
windows = platform.system() == "Windows"
assert platform.system() in ("Windows", "Linux") and platform.machine().lower() in ("amd64", "x86_64")
system = "Windows-x86-64" if windows else "Linux-x86-64"
suffix = ".exe" if windows else ""
environment = os.environ.copy()
elan_home = temporary / "elan"
environment["ELAN_HOME"] = str(elan_home)
environment["PATH"] = str(elan_home / "bin") + os.pathsep + environment["PATH"]
toolchain = config["LeanToolchain"]


def run(arguments, **options):
    print("RUN", " ".join(str(a) for a in arguments), flush=True)
    return subprocess.run([str(a) for a in arguments], env=environment, check=True, **options)


def capped(arguments, log, cwd):
    started = time.monotonic()
    peak = 0
    stopped = None
    with log.open("w", encoding="utf-8") as output:
        process = subprocess.Popen([str(a) for a in arguments], cwd=cwd, env=environment,
                                   stdout=output, stderr=subprocess.STDOUT)
        owner = psutil.Process(process.pid)
        while process.poll() is None:
            try:
                children = owner.children(recursive=True)
                footprint = 0
                for child in [owner, *children]:
                    try:
                        footprint += child.memory_info().rss
                    except psutil.NoSuchProcess:
                        pass
                peak = max(peak, footprint)
                if footprint > 10 * 2**30:
                    stopped = "10 GiB RSS limit"
                if time.monotonic() - started > 180:
                    stopped = "180 second limit"
                if stopped:
                    for child in reversed(children):
                        try:
                            child.kill()
                        except psutil.NoSuchProcess:
                            pass
                    owner.kill()
                    break
            except psutil.NoSuchProcess:
                break
            time.sleep(0.1)
        code = process.wait()
    resource = {"ExitCode": code, "StopReason": stopped, "PeakProcessTreeRSSBytes": peak,
                "ElapsedSeconds": time.monotonic() - started}
    log.with_suffix(".resources.json").write_text(json.dumps(resource, indent=2) + "\n")
    if code:
        print(log.read_text(encoding="utf-8", errors="replace")[-4000:])
        raise RuntimeError(resource)


asset = config["ElanArchives"][system]
archive = temporary / Path(asset["URL"]).name
run(["curl", "--fail", "--location", "--retry", "3", "--output", archive, asset["URL"]])
assert hashlib.sha256(archive.read_bytes()).hexdigest() == asset["SHA256"]
installer_dir = temporary / "installer"
installer_dir.mkdir(exist_ok=True)
if windows:
    with zipfile.ZipFile(archive) as package:
        package.extractall(installer_dir)
else:
    with tarfile.open(archive) as package:
        package.extractall(installer_dir, filter="data")
installer = installer_dir / ("elan-init" + suffix)
installer.chmod(0o755)
run([installer, "-y", "--no-modify-path", "--default-toolchain", "none"])
elan = elan_home / "bin" / ("elan" + suffix)
lake = elan_home / "bin" / ("lake" + suffix)
lean = elan_home / "bin" / ("lean" + suffix)
run([elan, "toolchain", "install", toolchain])
prefix = Path(run([lean, "+" + toolchain, "--print-prefix"], capture_output=True, text=True).stdout.strip())
run([lean, "+" + toolchain, "--version"])
run([lake, "+" + toolchain, "build", "LeanLink"], cwd=repo / "Native")

headers = Path(os.environ["LEANLINK_WL_HEADERS"]).resolve()
assert (headers / "WolframLibrary.h").is_file()
compiler = shutil.which("gcc") if windows else shutil.which("cc")
assert compiler, "A C compiler is required"
build = temporary / "shim-build"
run(["cmake", "-S", repo / "Native/shim", "-B", build, "-G", "Ninja",
     "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_C_COMPILER=" + compiler,
     "-DLEAN_HOME=" + str(prefix), "-DWL_INCLUDE=" + str(headers), "-DWL_SYSID=" + system])
run(["cmake", "--build", build, "--target", "LeanLinkShim", "--parallel", "2"])
library_directory = repo / "LeanLink/LibraryResources" / system
if windows:
    for dll in (prefix / "bin").glob("*.dll"):
        shutil.copy2(dll, library_directory / dll.name)
    shim = library_directory / "libLeanLinkShim.dll"
else:
    environment["LD_LIBRARY_PATH"] = str(prefix / "lib/lean")
    shim = library_directory / "libLeanLinkShim.so"
assert shim.is_file(), shim
binary = temporary / ("native_evaluation" + suffix)
command = [compiler, "-O2", "-I" + str(headers), here / "native_evaluation.c", "-o", binary]
command += ["-static"] if windows else ["-ldl"]
run(command)

mathlib = temporary / "mathlib"
run(["git", "clone", "-c", "core.autocrlf=false", "--depth", "1", "--branch",
     toolchain.split(":")[-1], config["MathlibRepository"], mathlib])
revision = run(["git", "rev-parse", "HEAD"], cwd=mathlib, capture_output=True, text=True).stdout.strip()
assert revision == config["MathlibRevision"]
run([lake, "+" + toolchain, "exe", "cache", "get",
     "Mathlib/Data/Nat/Choose/Basic.lean", "Mathlib/Data/Nat/Sqrt.lean"], cwd=mathlib)
search_path = run([lake, "+" + toolchain, "env", sys.executable, "-c",
                   "import os; print(os.environ.get('LEAN_PATH', ''))"],
                  cwd=mathlib, capture_output=True, text=True).stdout.strip()
search_path += os.pathsep + str(prefix / "lib/lean")
metadata = {"LeanLinkCommit": run(["git", "rev-parse", "HEAD"], cwd=repo, capture_output=True, text=True).stdout.strip(),
            "System": platform.platform(), "Architecture": platform.machine(),
            "LeanToolchain": toolchain, "MathlibRevision": revision,
            "WolframInterfaceTested": False, "NativeShimTested": True,
            "Compiler": run([compiler, "--version"], capture_output=True, text=True).stdout.splitlines()[0]}
(results / "metadata.json").write_text(json.dumps(metadata, indent=2) + "\n")
for name, imports, paths in [
    ("init", "Init", str(prefix / "lib/lean")),
    ("mathlib", "Mathlib.Data.Nat.Choose.Basic,Mathlib.Data.Nat.Sqrt", search_path),
]:
    log = results / (name + ".log")
    capped([binary, shim, imports, paths], log, mathlib)
    run([sys.executable, here / "verify_native.py", log])
