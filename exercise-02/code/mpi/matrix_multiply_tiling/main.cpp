#include <iostream>
#include <mpi.h>
#include <random>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#define N 2048
#define BLOCK_SIZE 4

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
void tiled_matmul(double *A, double *B, double *C, int n, int block_size) {
  for (int i = 0; i < n; i++)
    for (int j = 0; j < n; j++)
      C[i * n + j] = 0;

  for (int ii = 0; ii < n; ii += block_size) {
    for (int kk = 0; kk < n; kk += block_size) {
      for (int jj = 0; jj < n; jj += block_size) {

        for (int i = ii; i < std::min(ii + block_size, n); i++) {
          for (int k = kk; k < std::min(kk + block_size, n); k++) {
            double temp = A[i * n + k];
            for (int j = jj; j < std::min(jj + block_size, n); j++) {
              C[i * n + j] += temp * B[k * n + j];
            }
          }
        }
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
  tiled_matmul(mat_a, mat_b, mat_c, N, BLOCK_SIZE);
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
    std::cout << "Algorithm: Tiling (" << BLOCK_SIZE << ")" << std::endl;
    std::cout << "Time to multiply: " << time << " seconds" << std::endl;
    std::cout << "Performance:      " << gflops << " GFLOP/s" << std::endl;
  }
  MPI_Barrier(MPI_COMM_WORLD);
  MPI_Finalize();
  return 0;
}
