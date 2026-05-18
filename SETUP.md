# iEBE-MUSIC NewChain Setup Guide

This branch contains the complete iEBE-MUSIC NewChain implementation with HTCondor/OSG cluster support.

## Quick Start

### 1. Clone the Repository
```bash
git clone -b joao/clean-final https://github.com/jppicchetti/iEBE-MUSIC.git
cd iEBE-MUSIC
```

### 2. Download and Compile Code Packages
The simulation codes (MUSIC, SMASH, TRENTo, etc.) are downloaded and compiled automatically:

```bash
cd codes
bash get_code_packages.sh
bash compile_code_packages.sh
cd ..
```

This will:
- Download initial condition generators (IPGlasma, 3DMCGlauber, TRENTo)
- Download hydrodynamic code (MUSIC)
- Download microscopic transport code (SMASH)
- Download analysis tools (iSS sampler, hadronic toolkit)
- Compile all packages

**Time estimate:** 30-60 minutes depending on your machine

### 3. Test the Installation
```bash
# Run a test event
python3 generate_jobs.py -w test_dp0 -n 1 -par config/design_points/parameters_dict_user_TRENTo_dp0.py
```

This will create a test job folder and run a single event simulation.

## Directory Structure

- **config/**: Configuration files and design points
  - `design_points/`: Parameter sets for different design points (dp0, dp1)
  - `parameters_dict_master.py`: Master configuration
  
- **codes/**: Simulation code packages
  - Source code and build directories for all simulation tools
  - Run `get_code_packages.sh` to populate this directory
  
- **Cluster_supports/**: Cluster job submission templates
  - `HTCondor/`: HTCondor submission scripts
  - `OSG/`: Open Science Grid submission templates
  
- **config/design_points/**: Physics parameter sets
  - `parameters_dict_user_TRENTo_dp0.py`: Design point 0 (1.0 fm/c free-streaming)
  - `parameters_dict_user_TRENTo_dp1.py`: Design point 1 (0.8 fm/c free-streaming)

## Key Features

- **Free-streaming initialization** with customizable tau (proper time)
- **Design point configurations** for systematic studies
- **HTCondor/OSG support** for cluster job submission
- **Automated isobar sampling** for deformed nuclei
- **Event batch generation** with `generate_event_batches.py`
- **Job submission** with `submit_job_batches.py`

## Customization

### Modify Free-Streaming Parameters
Edit the `free_streaming_dict` in your parameter file:
```python
free_streaming_dict = {
    'tau': 1.0,  # Free-streaming time in fm/c
    'grid_max': 15,
    'grid_step': 0.1,
}
```

### Create New Design Points
1. Copy an existing design point file (e.g., `parameters_dict_user_TRENTo_dp0.py`)
2. Modify the parameter values
3. Run: `python3 generate_jobs.py -par config/design_points/your_new_file.py ...`

## Cluster Submission

### HTCondor
```bash
cd test_dp0/job_folder_001
condor_submit condor_submit.submit
```

### OSG
```bash
cd test_dp0/job_folder_001
osg-job-submit osgsub_condor.submit
```

## Troubleshooting

**Error:** "File ... is too large"
- If seed files exceed limits, regenerate them with smaller configurations

**Error:** "MUSIC not found"
- Run `bash codes/get_code_packages.sh && bash codes/compile_code_packages.sh`

**Jobs not running on cluster**
- Check cluster requirements in `Cluster_supports/{HTCondor,OSG}/generate_submission_script.py`

## For Cluster Deployment

When moving to an HPC cluster:

1. Clone this branch on the cluster
2. Run setup scripts in the `codes/` directory
3. Adjust paths and cluster parameters as needed
4. Submit jobs using the cluster-specific submission tools

## Notes

- Large simulation outputs should be stored on cluster scratch space, not GitHub
- The `shared_seeds/` directory contains sample seed files; generate new ones as needed
- Free-streaming initialization files are automatically managed during job generation

For detailed configuration options, see the comments in `config/design_points/parameters_dict_user_TRENTo_dp0.py`

