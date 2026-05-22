#!/bin/bash

########################################################################
# This is a template for running an MPI program on the CSG cluster.
# To use this template, call it with the following command:
# sbatch 4_5.sh
########################################################################


# SLURM job script parameters, for more parameters and information see: https://slurm.schedmd.com/sbatch.html
#SBATCH --partition exercise-hpdc   # partition name, for HPDC, use exercise-hpdc
##SBATCH --exclusive                # FOR BENCHMARKING: remove the trailing # to request exclusive access nodes
#SBATCH --nodes 1                   # number of nodes
#SBATCH --ntasks 1                  # total number of tasks (processes)
# SBATCH --ntasks-per-node 1         # OPTIONAL for more control: number of tasks per node, ensure that nodes*ntasks-per-node == ntasks
# SBATCH --cpus-per-task 1           # OPTIONAL for more control: number of processors per task
#SBATCH --ntasks-per-core 1         # maximum number of tasks per core, this is the default
#SBATCH --time 00:30:00             # time limit (hh:mm:ss)
#SBATCH --job-name hpdc-template    # job name
#SBATCH --output job_%x-%j.txt      # output file name, %j is replaced by job ID by slurm

echo "nnodes:" $SLURM_NNODES
echo "ntasks:" $SLURM_NTASKS
echo "nodes:" $SLURM_JOB_NODELIST

# options for the number of nodes and tasks are set automatically by slurm, for more information on changing options yourself, see: https://docs.open-mpi.org/en/v5.0.x/man-openmpi/man1/mpirun.1.html#launch-options
#you can reuse the program of 4_4 in this exercise, but if you want you could also do a new 4_5.cpp and add it in the Make/SH file, you could also split this exercise in different SH files if that is easier for you
mpirun bin/4_4 sample_cli_parameter


# To get information about the mapping of tasks to cores and nodes, you can use the following command:
# mpirun --display-map 4_4 sample_cli_parameter
