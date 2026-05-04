#include <iostream>
#include <mpi.h>
#include <random>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define N 2048

// initialise Matrix with random numbers
void fill_matrix(double *mat, int rows, int cols) {
  std::random_device rd;
  std::mt19937 gen(rd());
  double lower = 0.0;
  double upper = 1.0;
  std::uniform_real_distribution<double> dist(lower, upper);
  for (int i = 0; i < rows; i++) {
    for (int j = 0; j < cols; j++) {
      double random_val = dist(gen);
      mat[i * cols + j] = random_val;
    }
  }
}

// Matrixmultiplication
void local_matmul(double *A, double *B, double *C, int rows) {
    for (int i = 0; i < rows * rows; i++) C[i] = 0.0;

    for (int i = 0; i < rows; i++) {
        for (int k = 0; k < rows; k++) {
            double temp = A[i * rows + k];
            for (int j = 0; j < rows; j++) {
                C[i * rows + j] += temp * B[k * rows + j];
            }
        }
    }
}

double run() {
  double *mat_a = static_cast<double *>(
      malloc(static_cast<size_t>(sizeof(double) * N * N)));
  double *mat_b = static_cast<double *>(
      malloc(static_cast<size_t>(sizeof(double) * N * N)));
  double *mat_c = static_cast<double *>(
      malloc(static_cast<size_t>(sizeof(double) * N * N)));

  fill_matrix(mat_a, N, N);
  fill_matrix(mat_b, N, N);

  double time = MPI_Wtime();
  local_matmul(mat_a, mat_b, mat_c, N);
  time = MPI_Wtime() - time;

  free(mat_a);
  free(mat_b);
  free(mat_c);
  return time;
}

int main(int argc, char **argv) {
  int rank, size;
  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  if (rank == 0) {
    double time = run();
	
    // Calculate GFLOPs
    double ops = 2.0 * N * N * N;
    double gflops = (ops / time) / 1e9;

    std::cout << "Matrix Size: " << N << "x" << N << std::endl;
    std::cout << "Algorithm: Cache Optimized" << std::endl;
    std::cout << "Time to multiply: " << time << " seconds" << std::endl;
    std::cout << "Performance:      " << gflops << " GFLOP/s" << std::endl;
  }
  MPI_Barrier(MPI_COMM_WORLD);
  MPI_Finalize();
  return 0;
}
