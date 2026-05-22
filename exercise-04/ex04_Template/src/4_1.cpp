#include <algorithm>
#include <chCommandLine.h>
#include <chTimer.h>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <time.h>
#include <vector>

void save_heatmap_image(const std::vector<std::vector<double>> &grid,
                        const std::string &filename) {
  int N = grid.size();
  std::ofstream outFile(filename);

  if (!outFile.is_open()) {
    std::cerr << "Error opening file for writing image!\n";
    return;
  }

  outFile << "P3\n" << N << " " << N << "\n255\n";

  for (int x = 0; x < N; ++x) {
    for (int y = 0; y < N; ++y) {
      double temp = grid[x][y];
      double normalized = std::clamp(temp / 127.0, 0.0, 1.0);

      int r = static_cast<int>(normalized * 255);
      int g = 0;
      int b = static_cast<int>((1.0 - normalized) * 255);

      outFile << r << " " << g << " " << b << "  ";
    }
    outFile << "\n";
  }

  outFile.close();
}

void heat_map(const std::vector<std::vector<double>> grid) {
  int N = grid.size();

  for (int x = 0; x < N; ++x) {
    int N1 = grid[x].size();
    for (int y = 0; y < N1; ++y) {
      std::cout << grid[x][y] << " ";
    }
    std::cout << "\n";
  }
}

const double FACTOR = (24.0 / 100.0);
const double SELF_FACTOR = 1.0 - 4.0 * FACTOR;

double heat_calc(double self, double left, double top, double right,
                 double bottom) {
  double val = self + FACTOR * (-4.0 * self + left + top + right + bottom);
  return std::clamp(val, 0.0, 127.0);
}

inline double step(const std::vector<std::vector<double>> &grid, int x, int y) {
  // Rewritten to use multiply add instruction
  double self = grid[x][y];
  double neighbors =
      grid[x][y - 1] + grid[x - 1][y] + grid[x][y + 1] + grid[x + 1][y];
  return (FACTOR * neighbors) + (SELF_FACTOR * self);
}
void iteration(const std::vector<std::vector<double>> &grid,
               std::vector<std::vector<double>> &grid_new) {
  for (int x = 1; x < grid.size() - 1; ++x) {
    for (int y = 1; y < grid.size() - 1; ++y) {
      grid_new[x][y] = step(grid, x, y);
    }
  }
}

int main(int argc, char *argv[]) {
  if (argc < 4) {
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
  }
  int N = std::stoi(argv[1]);
  int iterations = std::stoi(argv[2]);
  int vis = std::stoi(argv[3]);

  std::vector<std::vector<double>> grid(N, std::vector<double>(N, 0.0));
  std::vector<std::vector<double>> grid_new(N, std::vector<double>(N, 0.0));

  for (int i = N / 4; i < (3 * N) / 4; ++i) {
    grid[0][i] = 127.0;
    grid_new[0][i] = 127.0;
  }

  chTimerTimestamp time1 = {};
  chTimerTimestamp timeEnd = {};
  double time = 0.0;
  for (int t = 0; t < iterations; t++) {
    chTimerGetTime(&time1);
    iteration(grid, grid_new);
    chTimerGetTime(&timeEnd);
    time += chTimerElapsedTime(&time1, &timeEnd);
    if (vis != 0 && t % vis == 0) {
      std::ostringstream ss;
      ss << "image/" << "heatmap_" << std::setfill('0') << std::setw(4) << t
         << ".ppm";
      std::string filename = ss.str();
      save_heatmap_image(grid_new, filename);
    }
    std::swap(grid, grid_new);
  }
  double time_per_iteration = time / static_cast<double>(iterations);
  double total_flops = ((N - 2) * (N - 2) * 7.0 * iterations);
  double flops = total_flops / time;
  std::ofstream outFile("4_2.csv", std::ios::app);

  if (!outFile.is_open()) {
    std::cerr << "Error opening file for writing image!";
    MPI_Finalize();
    return 0;
  }
  outFile << N << "," << time_per_iteration << "," << total_flops << ","
          << flops << std::endl;
  outFile.close();
  MPI_Finalize();
}
