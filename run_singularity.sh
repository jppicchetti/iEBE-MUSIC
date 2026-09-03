#!/usr/bin/env bash
set -e

parafile=$1
processId=$2
nHydroEvents=$3
nthreads=$4
nUrqmdSamples=2
seed=$5

export PYTHONIOENCODING=utf-8
export PATH="${PATH}:/usr/lib64/openmpi/bin:/usr/local/gsl/2.5/x86_64/bin"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib:/usr/local/gsl/2.5/x86_64/lib64"

SCRATCH_DIR="${PWD}"
cd "${SCRATCH_DIR}"
export HOME="${SCRATCH_DIR}"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_CACHE_HOME="${HOME}/.cache"
export TRENTO_CACHE="${HOME}/.trento"
mkdir -p "${XDG_DATA_HOME}"
mkdir -p "${XDG_CACHE_HOME}"
mkdir -p "${TRENTO_CACHE}"
mkdir -p "${XDG_DATA_HOME}/trento"
export HOME="${SCRATCH_DIR}"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_CACHE_HOME="${HOME}/.cache"
export TRENTO_CACHE="${HOME}/.trento"
mkdir -p "${XDG_DATA_HOME}"
mkdir -p "${XDG_CACHE_HOME}"
mkdir -p "${TRENTO_CACHE}"
mkdir -p "${XDG_DATA_HOME}/trento"

if [ ! -f "$(basename "${parafile}")" ] && [ -f "${parafile}" ]; then
    cp "${parafile}" "$(basename "${parafile}")"
fi
if [ ! -f "$(basename "${parafile}")" ]; then
    echo "Missing parameter file in scratch dir: ${parafile}" >&2
    ls -la "${SCRATCH_DIR}" >&2 || true
    exit 1
fi
parafile="$(basename "${parafile}")"

printf "Start time: `/bin/date`\n"
printf "Job is running on node: `/bin/hostname`\n"
printf "system kernel: `uname -r`\n"
printf "Job running as user: `/usr/bin/id`\n"
printf "Working directory: ${SCRATCH_DIR}\n"


seedfile="${6:-}"
seed_base=$(basename "${seedfile:-${parafile}}")
mkdir -p shared_seeds
seed_source=""
if [ -n "${seedfile}" ] && [ -f "${seedfile}" ]; then
    seed_source="${seedfile}"
else
    seed_source=$(find "${SCRATCH_DIR}" -name "${seed_base}" -type f -print -quit)
fi
echo "seedfile arg: ${seedfile:-<unset>}"
echo "seed_base: ${seed_base}"
echo "seed_source: ${seed_source:-<unset>}"
if [ -z "${seed_source}" ] || [ ! -f "${seed_source}" ]; then
    echo "Seed file missing from sandbox after transfer: ${seedfile:-<unset>}" >&2
    ls -la "${SCRATCH_DIR}" >&2 || true
    ls -la shared_seeds >&2 || true
    exit 1
fi
if [ ! -f "shared_seeds/${seed_base}" ]; then
    cp "${seed_source}" "shared_seeds/${seed_base}"
fi
echo "shared_seeds contents:"
ls -la shared_seeds
echo "rewritten parameter file seed line:"
grep -n "isobar_seed_file" "${parafile}" || true
python3 - "${parafile}" "shared_seeds/${seed_base}" <<'PY'
from pathlib import Path
import sys
param_path = Path(sys.argv[1])
seed_name = sys.argv[2]
text = param_path.read_text()
updated = False
for marker in ["isobar_seed_file = ", "isobar_seed_file: ", "isobar_seed_file= "]:
    idx = text.find(marker)
    if idx < 0:
        continue
    start = idx + len(marker)
    end = text.find("\n", start)
    if end < 0:
        end = len(text)
    quote = text[start] if start < len(text) and text[start] in ('"', "'") else '"'
    prefix = text[:start]
    suffix = text[end:]
    text = prefix + quote + seed_name + quote + suffix
    updated = True
    break
if not updated:
    raise SystemExit("isobar_seed_file not found in parameter file")
if not Path(seed_name).exists():
    raise SystemExit(f"Seed file not found after copy: {seed_name}")
param_path.write_text(text)
PY

seedfile="${6:-}"
seed_name=$(basename "${seedfile:-}")
if [ -n "${seed_name}" ] && [ -f "${seed_name}" ] && [ ! -f "shared_seeds/${seed_name}" ]; then
    mkdir -p shared_seeds
    cp "${seed_name}" "shared_seeds/${seed_name}"
fi
if [ -n "${seed_name}" ] && [ ! -f "shared_seeds/${seed_name}" ]; then
    echo "Seed file missing from sandbox after transfer: ${seedfile:-<unset>}" >&2
    exit 1
fi

event_start_id=$(( processId * nHydroEvents ))
event_end_id=$(( event_start_id + nHydroEvents - 1 ))

/opt/iEBE-MUSIC/generate_jobs.py -w playground -c OSG -par ${parafile} -id ${processId} -n_th ${nthreads} -n_urqmd ${nUrqmdSamples} -n_hydro ${nHydroEvents} -seed ${seed} --event_start_id ${event_start_id} --event_end_id ${event_end_id} --nocopy --continueFlag
status=$?
if [ $status -ne 0 ]; then
    echo "generate_jobs.py failed with exit code ${status}" >&2
    exit $status
fi

event_start_id=${event_start_id:-0}
event_end_id=${event_end_id:-$(( event_start_id + nHydroEvents - 1 ))}

job_event_dirs=()
for (( ev = event_start_id; ev <= event_end_id; ev++ )); do
    candidate="${SCRATCH_DIR}/playground/event_${ev}"
    if [ -d "${candidate}" ] && [ -f "${candidate}/submit_job.script" ]; then
        job_event_dirs+=("${candidate}")
    fi
done

if [ ${#job_event_dirs[@]} -eq 0 ]; then
    echo "Missing event directories for event range ${event_start_id}..${event_end_id}" >&2
    ls -la "${SCRATCH_DIR}/playground" >&2 || true
    exit 1
fi

cleanup_job_scratch() {
    find "${SCRATCH_DIR}" -maxdepth 1 -type f \( -name 'nucleon-seeds_*.hdf' -o -name 'nucleon-seeds.hdf' \) -exec rm -f {} + || true
    rm -f "${SCRATCH_DIR}/nucleon-seeds_*.hdf" "${SCRATCH_DIR}/nucleon-seeds.hdf" || true
}

trap cleanup_job_scratch EXIT

for event_dir in "${job_event_dirs[@]}"; do
    cd "${event_dir}"
    bash submit_job.script
    status=$?
    if [ $status -ne 0 ]; then
        echo "submit_job.script failed with exit code ${status}" >&2
        exit $status
    fi
done

find "${SCRATCH_DIR}" -maxdepth 1 -type f \( -name 'nucleon-seeds_*.hdf' -o -name 'nucleon-seeds.hdf' \) -exec rm -f {} + || true
rm -f "${SCRATCH_DIR}/nucleon-seeds_*.hdf" "${SCRATCH_DIR}/nucleon-seeds.hdf" || true

job_output_tar="${SCRATCH_DIR}/job_output_${processId}.tar.gz"
job_paths=()
for (( ev = event_start_id; ev <= event_end_id; ev++ )); do
    if [ -d "${SCRATCH_DIR}/playground/event_${ev}" ]; then
        job_paths+=("playground/event_${ev}")
    fi
done
if [ ${#job_paths[@]} -gt 0 ]; then
    tar -czf "${job_output_tar}" -C "${SCRATCH_DIR}" "${job_paths[@]}"
    ls -lh "${job_output_tar}"
else
    echo "No event folders found for job ${processId} range ${event_start_id}..${event_end_id}" >&2
    exit 1
fi

status=$?
if [ $status -ne 0 ]; then
    exit $status
fi
