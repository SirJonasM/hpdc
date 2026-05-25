#!/bin/bash
#SBATCH --partition exercise-hpdc
#SBATCH --exclusive                 # Recommended for clean benchmarking (no interference)
#SBATCH --nodes 4                   # Request the maximum number of nodes you intend to use
#SBATCH --ntasks 24                 # Request the maximum total tasks you intend to use
#SBATCH --ntasks-per-core 1
#SBATCH --time 00:30:00
#SBATCH --job-name hpdc-4-5
#SBATCH --output job_4-5.txt

rm -f 4_4.csv

for world_size in 2 4 8 12 16 20 24; do
  for nodes in 1 2 4; do
    
    if [ $nodes -gt $world_size ]; then
      continue
    fi
    
    ppn=$(( world_size / nodes ))
    
    if [ $(( world_size % nodes )) -ne 0 ]; then
      continue
    fi

    echo "========================================="
    echo "Running Configuration: Nodes=$nodes | Total Tasks=$world_size | TasksPerNode=$ppn"
    echo "========================================="

    for grid_size in 128 256 512 1024 2048 4096 8192; do 
      echo "Executing grid size: $grid_size"
      mpirun -np "$world_size" --map-by ppr:$ppn:node bin/4_4 "$grid_size" 100 0 "$nodes"
    done
  done
done
