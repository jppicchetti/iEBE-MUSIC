#!/usr/bin/env python3
"""Submit each generated DesignPoint directory to OSG.

Run this from the directory that contains the DesignPointN folders, for example:

    python3 submit_design_points.py

It will loop over each DesignPoint directory, run the OSG submission generator,
and then submit the generated singularity.submit file.
"""

from __future__ import annotations

import argparse
import re
import shlex
import subprocess
from pathlib import Path

DEFAULT_OSG_SCRIPT = Path("/home/joaopaulo.picchetti/iEBE-MUSIC/Cluster_supports/OSG/generate_submission_script.py")


def find_design_points(root: Path) -> list[tuple[int, Path]]:
    pattern = re.compile(r"^DesignPoint(\d+)$")
    matches: list[tuple[int, Path]] = []
    for path in sorted(root.iterdir()):
        if not path.is_dir():
            continue
        m = pattern.match(path.name)
        if m is not None:
            matches.append((int(m.group(1)), path))
    if not matches:
        raise FileNotFoundError(f"No DesignPoint directories found in {root}")
    return matches


def run_command(command: list[str], cwd: Path, dry_run: bool) -> None:
    print(f"$ {shlex.join(command)}")
    if dry_run:
        return
    subprocess.run(command, cwd=str(cwd), check=True)


def submit_all(root: Path, dry_run: bool) -> None:
    for index, point_dir in find_design_points(root):
        param_file = point_dir / f"parameter_dictionary_design_point_{index}.py"
        if not param_file.exists():
            raise FileNotFoundError(f"Missing parameter file for DesignPoint{index}: {param_file}")

        print(f"\nSubmitting DesignPoint{index} from {point_dir}")
        generate_cmd = [
            "python3",
            str(DEFAULT_OSG_SCRIPT),
            "-n",
            "2000",
            "-nev",
            "1",
            "-nth",
            "8",
            "-nurqmd",
            "20",
            "-singularity",
            "$DATA/singularity_repos/iebe-music-joao-aug26v4.sif",
            "-param",
            param_file.name,
            "-jobid",
            f"DesignPoint{index}",
            "-output_mode",
            "quiet",
        ]
        run_command(generate_cmd, point_dir, dry_run)

        submit_cmd = ["condor_submit", "singularity.submit"]
        run_command(submit_cmd, point_dir, dry_run)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the commands without executing them.",
    )
    args = parser.parse_args()

    root = Path.cwd()
    submit_all(root, args.dry_run)


if __name__ == "__main__":
    main()
