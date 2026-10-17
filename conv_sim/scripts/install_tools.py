"""在当前 conda 环境中编译固定版本的 Icarus Verilog 与 GTKWave。"""

import hashlib
import json
import os
import subprocess
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "conv_sim/.build"
SOURCES = {
    "iverilog": (
        "https://codeload.github.com/steveicarus/iverilog/tar.gz/refs/tags/v12_0",
        "iverilog-12_0",
    ),
    "gtkwave": (
        "https://codeload.github.com/gtkwave/gtkwave/tar.gz/refs/tags/v3.3.116",
        "gtkwave-3.3.116/gtkwave3-gtk3",
    ),
}


def main():
    """将二进制、库和版本清单统一安装在 CONDA_PREFIX 中。"""
    prefix = Path(os.environ.get("CONDA_PREFIX", sys.prefix))
    if not (prefix / "conda-meta").is_dir():
        raise SystemExit("请先激活 environment.yml 对应的 conda 环境")
    env = os.environ.copy()
    env["PATH"] = str(prefix / "bin") + os.pathsep + env["PATH"]
    env["PKG_CONFIG_PATH"] = str(prefix / "lib/pkgconfig")
    env["CPPFLAGS"] = f"-I{prefix}/include"
    env["LDFLAGS"] = f"-L{prefix}/lib -Wl,-rpath,{prefix}/lib"
    BUILD.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for name, (url, directory) in SOURCES.items():
        archive = BUILD / f"{name}.tar.gz"
        subprocess.run(
            ["curl", "-L", "--fail", "--retry", "3", url, "-o", str(archive)],
            check=True,
        )
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        manifest[name] = {"source": url, "sha256": digest}
        with tarfile.open(archive) as source:
            source.extractall(BUILD, filter="data")
        workdir = BUILD / directory
        if name == "gtkwave" and sys.platform == "darwin":
            # Quartz 后端使用独立窗口，关闭仅适用于 X11 的嵌入窗口代码。
            main_source = workdir / "src/main.c"
            main_source.write_text(
                main_source.read_text().replace(
                    "#define WAVE_USE_XID", "/* Quartz 使用独立窗口。 */"
                )
            )
        commands = []
        if name == "iverilog":
            commands.append(["sh", "autoconf.sh"])
        command = ["./configure", f"--prefix={prefix}"]
        if name == "gtkwave":
            command += ["--enable-gtk3", "--disable-tcl", "--disable-xz"]
        commands += [
            command,
            ["make", "-j", str(min(os.cpu_count() or 2, 8))],
            ["make", "install"],
        ]
        with (BUILD / f"{name}.log").open("w") as log:
            for command in commands:
                print("执行：", " ".join(command), flush=True)
                subprocess.run(
                    command,
                    cwd=workdir,
                    env=env,
                    check=True,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                )
                if (
                    name == "gtkwave"
                    and sys.platform == "darwin"
                    and command[0] == "./configure"
                ):
                    # Quartz 安装单窗口查看器；双窗口 X11 嵌入辅助程序单独关闭。
                    makefile = workdir / "src/Makefile"
                    makefile.write_text(
                        makefile.read_text().replace(
                            "bin_PROGRAMS = gtkwave$(EXEEXT) twinwave$(EXEEXT)",
                            "bin_PROGRAMS = gtkwave$(EXEEXT)",
                        )
                    )
    (prefix / "toolchain-sources.json").write_text(
        json.dumps(manifest, indent=2) + "\n"
    )


if __name__ == "__main__":
    main()
