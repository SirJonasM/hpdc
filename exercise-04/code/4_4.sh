#!/bin/bash

########################################################################
# This is a template for running an MPI program on the CSG cluster.
# To use this template, call it with the following command:
# sbatch 4_4.sh
########################################################################


# SLURM job script parameters, for more parameters and information see: https://slurm.schedmd.com/sbatch.html
#SBATCH --partition exercise-hpdc   # partition name, for HPDC, use exercise-hpdc
##SBATCH --exclusive                # FOR BENCHMARKING: remove the trailing # to request exclusive access nodes
#SBATCH --nodes 1                   # number of nodes
#SBATCH --ntasks 8                  # total number of tasks (processes)
# SBATCH --ntasks-per-node 1         # OPTIONAL for more control: number of tasks per node, ensure that nodes*ntasks-per-node == ntasks
# SBATCH --cpus-per-task 1           # OPTIONAL for more control: number of processors per task
#SBATCH --ntasks-per-core 1         # maximum number of tasks per core, this is the default
#SBATCH --time 00:30:00             # time limit (hh:mm:ss)
#SBATCH --job-name hpdc-4-4    # job name
#SBATCH --output job_4-4.txt      # output file name, %j is replaced by job ID by slurm

echo "nnodes:" $SLURM_NNODES
echo "ntasks:" $SLURM_NTASKS
echo "nodes:" $SLURM_JOB_NODELIST

mpirun bin/4_4 128 1000 10 1
