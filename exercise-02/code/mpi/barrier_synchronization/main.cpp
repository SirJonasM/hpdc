#include <cmath>
#include <iostream>
#include <cstdlib>
#include <chCommandLine.h>
#include <chTimer.hpp>
#include <mpi.h>
#include <string>



// customBarrier implement a barrier
void customBarrier(int rank, int iterations, int size) {
	
	double starttime = MPI_Wtime();
	int dummy_buffer = 0;
	
	for(int i = 0; i < iterations; ++i){
		if(rank == 0) {
			for(int other_rank = 1; other_rank < size; ++other_rank) {
				MPI_Recv(&dummy_buffer, 1, MPI_INT, other_rank, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
			}
			// All messages recieved, at this point threads are synced
		}
		else {
			MPI_Send(&dummy_buffer, 1, MPI_INT, 0, 0, MPI_COMM_WORLD);
		}
		
		MPI_Bcast(&dummy_buffer, 1, MPI_INT, 0, MPI_COMM_WORLD);
	}
	
	
	double endtime = MPI_Wtime();
	// Output result on last rank: This rank is expected to receive the release last and should therefore be the correct time when the barrier was fully released
	//This cout will then be used in the .sh to collect the measurements in the .csv
	if (rank == size-1) std::cout << "Custom Barrier Time: " << ((endtime-starttime) / ((double) iterations / 1000)) << " ms" << std::endl;
}

// use for build in Barrier
void builtInBarrier(int rank, int iterations, int size) {
	double starttime = MPI_Wtime();
	
	for(int i = 0; i < iterations; ++i) {
		MPI_Barrier(MPI_COMM_WORLD);
	}
	
	
	double endtime = MPI_Wtime();
	//This cout will then be used in the .sh to collect the measurements in the .csv
	if (rank == size-1) std::cout << "Built-In Barrier Time: " << ((endtime-starttime) / ((double) iterations / 1000)) << " ms" << std::endl;
}

//
// Main
//
int main(int argc, char * argv[]) {
	MPI_Init(&argc , &argv); // Initialize MPI
	
	int num_iterations = 500;
	
	// Get global rank and size
	int rank, size;
	MPI_Comm_rank(MPI_COMM_WORLD, &rank);
	MPI_Comm_size(MPI_COMM_WORLD, &size);

	// Implement your test
	MPI_Barrier(MPI_COMM_WORLD); // Just to make sure all ranks start together
	
	std::string barrier_method = argv[1];
	if(barrier_method == "--built-in") {
		builtInBarrier(rank, num_iterations, size);
	}
	else if(barrier_method == "--custom") {
		customBarrier(rank, num_iterations, size);
	}
	
	MPI_Finalize(); // Finalize MPI
	
	return 0;
}
