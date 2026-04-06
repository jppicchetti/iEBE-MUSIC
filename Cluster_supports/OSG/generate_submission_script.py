#!/usr/bin/env python3
"""This script generates the job submission script on OSG"""


import sys
from os import path, makedirs
import random

FILENAME = "singularity.submit"

def print_usage():
    """This function prints out help messages"""
    print("Usage: {} ".format(sys.argv[0].split("/")[-1])
          + "Njobs Nevents_per_job N_threads SingularityImage ParameterFile "
          + "SeedFile jobId [bayesFile]")


def write_submission_script(para_dict_):
    jobName = "iEBEMUSIC_{}".format(para_dict_["job_id"])
    random_seed = random.SystemRandom().randint(0, 10000000)
    imagePathHeader = "osdf://"
    script = open(FILENAME, "w")
    if para_dict_["bayesFlag"]:
        script.write("""universe = vanilla
executable = run_singularity.sh
arguments = {0} {1} $(Process) {2} {3} {4} {5}
""".format(para_dict_["paraFile"], para_dict_["seedFile"], para_dict_["n_events_per_job"],
           para_dict_["n_threads"], random_seed, para_dict_["bayesFile"]))
    else:
        script.write("""universe = vanilla
executable = run_singularity.sh
arguments = {0} {1} $(Process) {2} {3} {4}
""".format(para_dict_["paraFile"], para_dict_["seedFile"], para_dict_["n_events_per_job"],
           para_dict_["n_threads"], random_seed))
    script.write("""
JobBatchName = {0}

should_transfer_files = YES
WhenToTransferOutput = ON_EXIT

+SingularityImage = "{1}"
Requirements = SINGULARITY_CAN_USE_SIF && StringListIMember("stash", HasFileTransferPluginMethods)
""".format(jobName, imagePathHeader + para_dict_["image_with_path"]))

    if para_dict_['bayesFlag']:
        script.write("""
transfer_input_files = {0}, {1}, {2}
""".format(para_dict_['paraFile'], para_dict_['seedFile'], para_dict_['bayesFile']))
    else:
        script.write("""
transfer_input_files = {0}, {1}
""".format(para_dict_['paraFile'], para_dict_['seedFile']))

    script.write(
            "transfer_checkpoint_files = playground/event_0/EVENT_RESULTS_$(Process).tar.gz\n")

    script.write("""
transfer_output_files = playground/event_0/EVENT_RESULTS_$(Process)

error = log/job.$(Cluster).$(Process).error
output = log/job.$(Cluster).$(Process).output
log = log/job.$(Cluster).$(Process).log

#+JobDurationCategory = "Long"
max_idle = 1000

# remove the failed jobs
periodic_remove = (ExitCode == 73)

# auto release hold jobs if they are caused by data transfer issues on OSG
periodic_release = ((HoldReasonCode == 13 || HoldReasonCode == 26) && (time() - EnteredCurrentStatus) > 1200 )

checkpoint_exit_code = 85

# Send the job to Held state on failure.
on_exit_hold = (ExitBySignal == True) || (ExitCode != 0 && ExitCode != 73)

# The below are good base requirements for first testing jobs on OSG,
# if you don't have a good idea of memory and disk usage.
request_cpus = {0:d}
request_memory = {1:d} GB
request_disk = 2 GB

# Queue one job with the above specifications.
queue {1:d}""".format(para_dict_["n_threads"], para_dict_["n_jobs"]))
    script.close()


def write_job_running_script(para_dict_):
    script = open("run_singularity.sh", "w")
    script.write("""#!/usr/bin/env bash

parafile=$1
seedfile=$2
processId=$3
nHydroEvents=$4
nthreads=$5
seed=$6


export PYTHONIOENCODING=utf-8
export PATH="${PATH}:/usr/lib64/openmpi/bin:/usr/local/gsl/2.5/x86_64/bin"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/local/lib:/usr/local/gsl/2.5/x86_64/lib64"

jobdir=$(pwd)
export JOBDIR="${jobdir}"
export TMPDIR="${jobdir}/tmp"
export HOME="${jobdir}"
export XDG_DATA_HOME="${jobdir}/.local/share"
export XDG_CACHE_HOME="${jobdir}/.cache"
export TRENTO_CACHE="${jobdir}/.trento"

export SINGULARITYENV_HOME="${HOME}"
export SINGULARITYENV_TMPDIR="${TMPDIR}"
export SINGULARITYENV_XDG_DATA_HOME="${XDG_DATA_HOME}"
export SINGULARITYENV_XDG_CACHE_HOME="${XDG_CACHE_HOME}"
export SINGULARITYENV_TRENTO_CACHE="${TRENTO_CACHE}"

mkdir -p "${TMPDIR}"
mkdir -p "${XDG_DATA_HOME}"
mkdir -p "${XDG_CACHE_HOME}"
mkdir -p "${TRENTO_CACHE}"
mkdir -p "${XDG_DATA_HOME}/trento"

touch "${TRENTO_CACHE}/write_test.txt" || { echo "Cannot write to TRENTO_CACHE"; exit 101; }
touch "${XDG_DATA_HOME}/write_test.txt" || { echo "Cannot write to XDG_DATA_HOME"; exit 102; }
touch "${TMPDIR}/write_test.txt" || { echo "Cannot write to TMPDIR"; exit 103; }

printf "Start time: `/bin/date`\\n"
printf "Job is running on node: `/bin/hostname`\\n"
printf "system kernel: `uname -r`\\n"
printf "Job running as user: `/usr/bin/id`\\n"

echo "==== Environment debug ===="
echo "PWD=${PWD}"
echo "HOME=${HOME}"
echo "TMPDIR=${TMPDIR}"
echo "XDG_DATA_HOME=${XDG_DATA_HOME}"
echo "XDG_CACHE_HOME=${XDG_CACHE_HOME}"
echo "TRENTO_CACHE=${TRENTO_CACHE}"
echo "SINGULARITYENV_HOME=${SINGULARITYENV_HOME}"
echo "SINGULARITYENV_XDG_DATA_HOME=${SINGULARITYENV_XDG_DATA_HOME}"
echo "SINGULARITYENV_TRENTO_CACHE=${SINGULARITYENV_TRENTO_CACHE}"
echo "==========================="
""")
    if para_dict_["bayesFlag"]:
        script.write("""bayesFile=$6

/opt/iEBE-MUSIC/generate_jobs.py -w playground -c OSG -par ${parafile} --isobar_seed_file ${seedfile} -id ${processId} -n_th ${nthreads} -n_urqmd ${nthreads} -n_hydro ${nHydroEvents} -seed ${seed} -b ${bayesFile} --nocopy --continueFlag
""")
    else:
        script.write("""
/opt/iEBE-MUSIC/generate_jobs.py -w playground -c OSG -par ${parafile} --isobar_seed_file ${seedfile} -id ${processId} -n_th ${nthreads} -n_urqmd ${nthreads} -n_hydro ${nHydroEvents} -seed ${seed} --nocopy --continueFlag
""")

    script.write("""
cd playground/event_0
mv EVENT_RESULTS_${processId}.tar.gz playground/event_0
bash submit_job.script
status=$?
if [ $status -ne 0 ]; then
    exit $status
fi
""")
    script.close()


def main(para_dict_):
    write_submission_script(para_dict_)
    write_job_running_script(para_dict_)
    logFolderName = "log"
    if not path.exists(logFolderName):
        makedirs(logFolderName)


if __name__ == "__main__":
    bayesFlag = False
    bayesFile = ""
    try:
        N_JOBS = int(sys.argv[1])
        N_EVENTS_PER_JOBS = int(sys.argv[2])
        N_THREADS = int(sys.argv[3])
        SINGULARITY_IMAGE_PATH = sys.argv[4]
        SINGULARITY_IMAGE = SINGULARITY_IMAGE_PATH.split("/")[-1]
        PARAMFILE = sys.argv[5]
        SEEDFILE = sys.argv[6]
        JOBID = sys.argv[7]
        if len(sys.argv) == 9:
            bayesFile = sys.argv[8]
            bayesFlag = True
    except (IndexError, ValueError) as e:
        print_usage()
        exit(0)

    para_dict = {
        'n_jobs': N_JOBS,
        'n_events_per_job': N_EVENTS_PER_JOBS,
        'n_threads': N_THREADS,
        'image_name': SINGULARITY_IMAGE,
        'image_with_path': SINGULARITY_IMAGE_PATH,
        'paraFile': PARAMFILE,
        'seedFile': SEEDFILE,
        'job_id': JOBID,
        'bayesFlag': bayesFlag,
        'bayesFile': bayesFile,
    }

    main(para_dict)

