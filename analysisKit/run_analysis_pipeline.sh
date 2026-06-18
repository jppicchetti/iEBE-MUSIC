#!/usr/bin/env bash
# Template pipeline: extract Qn pickles from spvn_results HDF5s, merge, run analyzers.
# Edit INPUT_DIR and OUTDIR as needed or pass H5 files as arguments.

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 -d /path/to/runs_dir -o /path/to/outdir

This script will:
 - find spvn_results_*.h5 under the given directory
 - run fetch_Qnch_from_hdf5.py on each file and save unique pickles
 - merge pickles into combined.pkl using combine_pickle_files.py
 - run a small set of default analyzers on the merged pickle

EOF
}

while getopts ":d:o:" opt; do
  case ${opt} in
    d ) INPUT_DIR="$OPTARG" ;;
    o ) OUTDIR="$OPTARG" ;;
    \? ) usage; exit 1 ;;
  esac
done

if [ -z "${INPUT_DIR:-}" ] || [ -z "${OUTDIR:-}" ]; then
  usage
  exit 1
fi

mkdir -p "$OUTDIR"
pushd "$OUTDIR" >/dev/null

echo "Finding HDF5 files under $INPUT_DIR ..."
mapfile -t H5FILES < <(find "$INPUT_DIR" -type f -name 'spvn_results_*.h5' | sort)
if [ ${#H5FILES[@]} -eq 0 ]; then
  echo "No spvn_results_*.h5 files found under $INPUT_DIR" >&2
  popd >/dev/null
  exit 2
fi

echo "Found ${#H5FILES[@]} HDF5 files. Extracting Qn pickles..."
idx=0
for h5 in "${H5FILES[@]}"; do
  idx=$((idx+1))
  echo "[$idx/${#H5FILES[@]}] Processing: $h5"
  # run extractor in OUTDIR to collect output
  python3 "$(dirname "$0")/fetch_Qnch_from_hdf5.py" "$h5"
  # fetch_Qnch_from_hdf5.py writes QnVectors{_weakFD}.pickle in cwd
  if [ -f QnVectors.pickle ]; then
    mv QnVectors.pickle "QnVectors_run${idx}.pickle"
  elif [ -f QnVectors_weakFD.pickle ]; then
    mv QnVectors_weakFD.pickle "QnVectors_run${idx}.pickle"
  else
    echo "Expected QnVectors pickle not found after processing $h5" >&2
    exit 3
  fi
done

echo "Merging pickles into combined.pkl"
# combine_pickle_files.py merges into combined.pkl
python3 "$(dirname "$0")/combine_pickle_files.py" QnVectors_run1.pickle ${H5FILES[@]/#/${OUTDIR}/QnVectors_run}
# Note: combine_pickle_files.py writes combined.pkl in current dir

if [ ! -f combined.pkl ]; then
  echo "combined.pkl not created; aborting" >&2
  popd >/dev/null
  exit 4
fi

echo "Running default analyzers on combined.pkl"
python3 "$(dirname "$0")/analyze_vnpT.py" combined.pkl || true
python3 "$(dirname "$0")/analyze_vnch_inte.py" combined.pkl || true
python3 "$(dirname "$0")/analyze_rapiditydistributions.py" combined.pkl || true
python3 "$(dirname "$0")/analyze_pTfluct.py" combined.pkl || true

echo "Pipeline complete. Outputs are in: $OUTDIR"
popd >/dev/null
