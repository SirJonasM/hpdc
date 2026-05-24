#include <algorithm>
#include <chCommandLine.h>
#include <chTimer.h>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <mpi.h>
#include <stdlib.h>
#include <string>
#include <vector>
#include "heat_shared.h"

void iteration_tiled(const std::vector<double> &grid,
                     std::vector<double> &grid_new, int N, int tile_size) {
  int tiles_x = (N + tile_size - 1) / tile_size;
  int tiles_y = (N + tile_size - 1) / tile_size;

  for (int t_x = 0; t_x < tiles_x; ++t_x) {
    for (int t_y = 0; t_y < tiles_y; ++t_y) {

      int x_start = std::max(1, t_x * tile_size);
      int x_end = std::min(N - 1, (t_x + 1) * tile_size);

      int y_start = std::max(1, t_y * tile_size);
      int y_end = std::min(N - 1, (t_y + 1) * tile_size);

      for (int x = x_start; x < x_end; ++x) {
        for (int y = y_start; y < y_end; ++y) {

          double self = grid[x * N + y];
          double left = grid[(x - 1) * N + y];
          double top = grid[x * N + y - 1];
          double right = grid[(x + 1) * N + y];
          double bottom = grid[x * N + y + 1];

          grid_new[x * N + y] = calculate(self, left, top, right, bottom);
        }
      }
    }
  }
}

int main(int argc, char *argv[]) {
  if (argc < 5) {
    std::cout << "Usage: " << argv[0]
              << " <N> <i:iterations> <v:visualization>\n";
    return 1;
  }

  MPI_Init(&argc, &argv);

  // Get the rank and size of the MPI communicator
  int rank, size;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);
  if (rank != 0) {
    MPI_Finalize();
    return 0;
  }
  int N = std::stoi(argv[1]);
  int iterations = std::stoi(argv[2]);
  int tiling = std::stoi(argv[3]);
  int vis = std::stoi(argv[4]);

  std::vector<double> grid(N * N, 0.0);
  std::vector<double> grid_new(N * N, 0.0);

  for (int i = N / 4; i < (3 * N) / 4; ++i) {
    grid[i] = 127.0;
    grid_new[i] = 127.0;
  }

  chTimerTimestamp time_start = {};
  chTimerTimestamp time_end = {};
  double time_sequential = 0.0;
  double time_tiling = 0.0;
  for (int t = 0; t < iterations; t++) {

    chTimerGetTime(&time_start);
    iteration(grid, grid_new, N);
    chTimerGetTime(&time_end);
    time_sequential += chTimerElapsedTime(&time_start, &time_end);

    if (tiling != 0) {
      chTimerGetTime(&time_start);
      iteration_tiled(grid, grid_new, N, tiling);
      chTimerGetTime(&time_end);
      time_tiling += chTimerElapsedTime(&time_start, &time_end);
    }

    if (vis != 0 && t % vis == 0) {
      std::ostringstream ss;
      ss << "image/" << "heatmap_" << std::setfill('0') << std::setw(4) << t
         << ".ppm";
      std::string filename = ss.str();
      save_heatmap_image(grid_new, filename, N);
    }
    std::swap(grid, grid_new);
  }

  std::ofstream outFile("4_2.csv", std::ios::app);
  if (!outFile.is_open()) {
    std::cerr << "Error opening file for writing image!";
    MPI_Finalize();
    return 0;
  }

  double time_per_iteration = time_sequential / static_cast<double>(iterations);
  double total_flops = ((N - 2) * (N - 2) * 6.0 * iterations);
  double flops_sequential = total_flops / time_sequential;
  if (tiling != 0) {
    double time_per_iteration_tiling =
        time_tiling / static_cast<double>(iterations);
    double flops_tiling = total_flops / time_tiling;
    outFile << N << "," << time_per_iteration << "," << total_flops << ","
            << flops_sequential << "," << time_per_iteration_tiling << ","
            << flops_tiling << std::endl;
  } else {
    outFile << N << "," << time_per_iteration << "," << total_flops << ","
            << flops_sequential << "," << std::endl;
  }

  outFile.close();
  MPI_Finalize();
  return 0;
}
