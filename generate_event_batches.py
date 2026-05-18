#!/usr/bin/env python3
"""Generate multiple iEBE-MUSIC job folders over disjoint event ranges.

This helper is meant for Bayesian studies or any large production run where a
single design point needs to be split into many jobs. Each generated job folder
calls `generate_jobs.py` with an explicit inclusive event range so event IDs are
never reused across batches.
"""

import argparse
import json
import shlex
import subprocess
from os import path, mkdir
from datetime import datetime


def build_event_ranges(event_start_id, event_end_id, events_per_job):
    """Return inclusive event ranges split into chunks."""
    ranges = []
    current_start = event_start_id
    while current_start <= event_end_id:
        current_end = min(current_start + events_per_job - 1, event_end_id)
        ranges.append((current_start, current_end))
        current_start = current_end + 1
    return ranges


def main():
    parser = argparse.ArgumentParser(
        description="Split a large event set into multiple generate_jobs.py runs",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--working_folder_prefix",
        type=str,
        default="bayes_run",
        help="prefix for generated working folders",
    )
    parser.add_argument(
        "--event_start_id",
        type=int,
        default=0,
        help="first global event index to generate",
    )
    parser.add_argument(
        "--event_end_id",
        type=int,
        required=True,
        help="last global event index to generate (inclusive)",
    )
    parser.add_argument(
        "--events_per_job",
        type=int,
        default=100,
        help="number of events to place in each generated job folder",
    )
    parser.add_argument(
        "--generate_jobs_script",
        type=str,
        default=path.abspath(path.join(path.dirname(__file__), "generate_jobs.py")),
        help="path to generate_jobs.py",
    )
    parser.add_argument(
        "--generate_jobs_args",
        type=str,
        default="",
        help=(
            "additional arguments passed through to generate_jobs.py, "
            "for example: '--cluster_name local --par_dict config/parameters_dict_user_TRENTo.py'"
        ),
    )
    parser.add_argument(
        "--manifest_file",
        type=str,
        default="",
        help="if provided, save job manifest to this JSON file",
    )
    args = parser.parse_args()

    if args.event_end_id < args.event_start_id:
        raise SystemExit("event_end_id must be >= event_start_id")
    if args.events_per_job <= 0:
        raise SystemExit("events_per_job must be positive")

    event_ranges = build_event_ranges(
        args.event_start_id, args.event_end_id, args.events_per_job
    )
    n_jobs = len(event_ranges)

    print(
        "Splitting events {}..{} into {} job(s) of at most {} event(s) each".format(
            args.event_start_id, args.event_end_id, n_jobs, args.events_per_job
        )
    )

    script_args = shlex.split(args.generate_jobs_args)
    manifest_data = {
        "timestamp": datetime.now().isoformat(),
        "total_events": args.event_end_id - args.event_start_id + 1,
        "events_per_job": args.events_per_job,
        "n_jobs": n_jobs,
        "working_folder_prefix": args.working_folder_prefix,
        "jobs": []
    }

    for job_id, (range_start, range_end) in enumerate(event_ranges):
        working_folder = "{}_{:04d}_{}_{:04d}".format(
            args.working_folder_prefix, range_start, range_end, job_id
        )
        command = [
            "python3",
            args.generate_jobs_script,
            "--working_folder_name",
            working_folder,
            "--n_jobs",
            str(range_end - range_start + 1),
            "--event_start_id",
            str(range_start),
            "--event_end_id",
            str(range_end),
        ]
        command.extend(script_args)

        print(
            "Running job {}: events {}..{} -> {}".format(
                job_id, range_start, range_end, working_folder
            )
        )
        subprocess.run(command, check=True)

        manifest_data["jobs"].append({
            "job_id": job_id,
            "working_folder": working_folder,
            "event_start_id": range_start,
            "event_end_id": range_end,
            "n_events": range_end - range_start + 1,
        })

    # Save manifest if requested
    if args.manifest_file:
        with open(args.manifest_file, "w") as f:
            json.dump(manifest_data, f, indent=2)
        print("\nManifest saved to: {}".format(args.manifest_file))

    # Print summary
    print("\n" + "="*60)
    print("Job batch generation complete!")
    print("="*60)
    print("Total events: {}".format(manifest_data["total_events"]))
    print("Number of jobs: {}".format(n_jobs))
    print("Working folder prefix: {}".format(args.working_folder_prefix))
    if args.manifest_file:
        print("Manifest file: {}".format(args.manifest_file))
    print("="*60)


if __name__ == "__main__":
    main()