#!/usr/bin/env bash
set -e

parafile=$1
processId=$2
nHydroEvents=$3
nthreads=$4
seed=$5

export PYTHONIOENCODING=utf-8
export PATH="${PATH}:/usr/lib64/openmpi/bin:/usr/local/gsl/2.5/x86_64/bin"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib:/usr/local/gsl/2.5/x86_64/lib64"

SCRATCH_DIR="${PWD}"
cd "${SCRATCH_DIR}"

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
    end = text.find("
", start)
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

# Remove any top-level copy of the seed file now that we have a
# canonical copy under shared_seeds/ to avoid leaving large files in
# the sandbox root. Leave the shared copy intact.
if [ -f "${seed_base}" ] && [ -f "shared_seeds/${seed_base}" ]; then
    rm -f "${seed_base}"
fi

if [ -n "${seed_name}" ] && [ -f "shared_seeds/${seed_name}" ] && [ -f "${seed_name}" ]; then
    rm -f "${seed_name}"
fi

/opt/iEBE-MUSIC/generate_jobs.py -w playground -c OSG -par ${parafile} -id ${processId} -n_th ${nthreads} -n_urqmd ${nthreads} -n_hydro ${nHydroEvents} -seed ${seed} --nocopy --continueFlag
status=$?
if [ $status -ne 0 ]; then
    echo "generate_jobs.py failed with exit code ${status}" >&2
    exit $status
fi

if [ ! -d "${SCRATCH_DIR}/playground/event_0" ]; then
    echo "Missing expected job directory: ${SCRATCH_DIR}/playground/event_0" >&2
    ls -la "${SCRATCH_DIR}" >&2 || true
    ls -la "${SCRATCH_DIR}/playground" >&2 || true
    exit 1
fi

cd "${SCRATCH_DIR}/playground/event_0"
if [ ! -f "submit_job.script" ]; then
    echo "Missing submit_job.script in ${SCRATCH_DIR}/playground/event_0" >&2
    ls -la >&2
    exit 1
fi
bash submit_job.script
status=$?
if [ $status -ne 0 ]; then
    exit $status
fi
if [ ! -d "EVENT_RESULTS_${processId}" ]; then
    echo "Missing final results directory: ${SCRATCH_DIR}/playground/event_0/EVENT_RESULTS_${processId}" >&2
    ls -la "${SCRATCH_DIR}/playground/event_0" >&2 || true
    find "${SCRATCH_DIR}/playground/event_0" -maxdepth 2 -type d | sort >&2 || true
    exit 1
fi
tar -czf EVENT_RESULTS_${processId}.tar.gz EVENT_RESULTS_${processId}
status=$?
if [ $status -ne 0 ]; then
    exit $status
fi
