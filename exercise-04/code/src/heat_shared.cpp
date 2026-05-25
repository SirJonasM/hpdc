#include <algorithm>
#include <fstream>
#include <iostream>
#include <vector>

void save_heatmap_image(const std::vector<double> &grid,
                        const std::string &filename, int N) {
  std::ofstream outFile(filename);

  if (!outFile.is_open()) {
    std::cerr << "Error opening file for writing image!\n";
    return;
  }

  outFile << "P3\n" << N << " " << N << "\n255\n";

  for (int x = 0; x < N; ++x) {
    for (int y = 0; y < N; ++y) {
      double temp = grid[x * N + y];
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

const double FACTOR = (24.0 / 100.0);
const double SELF_FACTOR = 1.0 - 4.0 * FACTOR;

// 6 FLOP's
double calculate(double self, double left, double top, double right,
                        double bottom) {
  double neighbors = left + top + right + bottom;
  double val = (FACTOR * neighbors) + (SELF_FACTOR * self);
  return std::clamp(val, 0.0, 127.0);
}

void iteration(const std::vector<double> &grid, std::vector<double> &grid_new,
               int N) {
  for (int x = 1; x < N - 1; ++x) {
    for (int y = 1; y < N - 1; ++y) {
      double self = grid[x * N + y];
      double left = grid[(x - 1) * N + y];
      double top = grid[x * N + y - 1];
      double right = grid[(x + 1) * N + y];
      double bottom = grid[x * N + y + 1];
      grid_new[x * N + y] = calculate(self, left, top, right, bottom);
    }
  }
}

