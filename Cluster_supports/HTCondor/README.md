# Running iEBE-MUSIC on a generic HTCondor cluster

Simulations are performed inside a Singularity container. This script is
designed for HTCondor clusters where Singularity is available on the worker
nodes but **not** advertised via the `SINGULARITY_CAN_USE_SIF` ClassAd
(i.e., non-OSG clusters). Singularity is invoked explicitly inside the job
wrapper script.

---

## Set up


Download the iEBE-MUSIC framework under your home directory,

    git clone https://github.com/genilssom/iEBE-MUSIC -b NewChain

Pull directly from Docker Hub if the image is published,

    apptainer pull iebe-music_[date].sif docker://genilsoon/iebe-music:g_dev

It is good practice to add a date tag to the image file to distinguish
different versions over time.

## Running simulations

Create a dedicated folder for your run and copy a parameter file into it,

    mkdir [iEBEMUSICTestRun]
    cd [iEBEMUSICTestRun]
    cp ../iEBE-MUSIC/config/parameters_dict_user_TRENTo.py ./

There are several example parameter files in `iEBE-MUSIC/config/` for
different running modes. Then generate the job submission scripts,

    python3 ../iEBE-MUSIC/Cluster_supports/HTCondor/generate_submission_script.py \
        -param  parameters_dict_user_TRENTo.py \
        -singularity /path/to/iebe-music_[date].sif \
        -n    10 \
        -nev   1 \
        -nth   1 \
        -jobid [JobName] \
        -seed_file /path/to/nucleon-seed

You need to provide a `[JobName]` to label the job batch. The full list of
arguments can be printed by calling the script without arguments,

    python3 ../iEBE-MUSIC/Cluster_supports/HTCondor/generate_submission_script.py

    usage: generate_submission_script.py [-h] [-n] [-nev] [-nth] [-singularity]
                                         [-param] [-jobid] [-bayes] [-mem] [-seed_file]

The afterburner type (UrQMD or SMASH) is detected automatically from the
`afterburner_type` key in the parameter file. If you have a Bayesian parameter
file, pass it with `-bayes`. For TRENTo/SMASH runs with pre-generated isobar
nucleon seeds, pass the HDF5 seed file with `-seed_file`.

After running the script, two files are generated: `run_singularity.sh` and
`singularity.submit`. Submit the jobs with,

    condor_submit singularity.submit

While jobs are running, check their status with `condor_q`. To release held
jobs, use `condor_release [ClusterID]`.

---

## Collecting results

**UrQMD mode** — each finished job transfers back a single HDF5 file,

    EVENT_RESULTS_[N]/spvn_results_[N].h5

This file contains the flow observables ($v_n$, spectra, mean $p_T$),
eccentricities, and hydro evolution information computed by
`hadronic_afterburner_toolkit`.

**SMASH mode** — each finished job transfers back the full result directory,

    EVENT_RESULTS_[N]/

Inside, `smash_results_[N]/smash_analysis_[N].npz` contains Q-vectors
$Q_n = \sum_k e^{in\phi_k}$, particle counts, and mean $p_T$, binned in
$p_T$ and separated by particle species. These are the input for
flow-correlation analysis in subsequent steps.

To merge the individual HDF5 files from UrQMD runs into a single database,
copy the utility scripts and run,

    cp ../iEBE-MUSIC/Cluster_supports/OSG/collect_results.sh .
    cp ../iEBE-MUSIC/Cluster_supports/OSG/combine_multiple_hdf5.py .
    ./collect_results.sh ~/[iEBEMUSICTestRun]

You can rerun this command while jobs are still running to collect finished
events incrementally.
