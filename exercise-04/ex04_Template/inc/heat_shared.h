#ifndef HEAT_SHARED_H
#define HEAT_SHARED_H

#include <vector>
#include <string>

// Stencil core math function (6 FLOPs)
double calculate(double self, double left, double top, double right, double bottom);

// Image saving function for 1D flat layout vectors
void save_heatmap_image(const std::vector<double> &grid, const std::string &filename, int N);

// Pure sequential iteration loop
void iteration(const std::vector<double> &grid, std::vector<double> &grid_new, int N);

#endif // HEAT_SHARED_H
