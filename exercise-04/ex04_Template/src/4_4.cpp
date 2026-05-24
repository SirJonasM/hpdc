#include "heat_shared.h"
#include <algorithm>
#include <chTimer.h> // Provided timing library
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <mpi.h>
#include <sstream>
#include <string>
#include <vector>

int main(int argc, char *argv[]) {
  MPI_Init(&argc, &argv);

  int world_rank, world_size;
  MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);
  MPI_Comm_size(MPI_COMM_WORLD, &world_size);

  if (argc < 5) {
    if (world_rank == 0) {
      std::cout << "Usage: " << argv[0]
                << " <N> <i:iterations> <v:visualization>\n";
      for (int i = 0; i < argc; ++i) {
        std::cout << argv[i] << std::endl;
      }
    }
    MPI_Finalize();
    return 1;
  }

  int N = std::stoi(argv[1]);
  int iterations = std::stoi(argv[2]);
  int vis = std::stoi(argv[3]);
  int nnodes = std::stoi(argv[4]);

  int dims[2] = {world_size, 1};
  int periods[2] = {false, false};
  MPI_Comm cart_comm;
  MPI_Cart_create(MPI_COMM_WORLD, 2, dims, periods, true, &cart_comm);

  int rank;
  MPI_Comm_rank(cart_comm, &rank);

  int rank_top, rank_bottom;
  MPI_Cart_shift(cart_comm, 0, 1, &rank_top, &rank_bottom);

  int rows_local = N / world_size;
  int remainder = N % world_size;

  if (rank < remainder) {
    rows_local += 1;
  }
  int rows_allocated = rows_local + 2;

  std::vector<double> local_grid(rows_allocated * N, 0.0);
  std::vector<double> local_grid_new(rows_allocated * N, 0.0);

  if (rank == 0) {
    for (int j = N / 4; j < (3 * N) / 4; ++j) {
      local_grid[1 * N + j] = 127.0;
      local_grid_new[1 * N + j] = 127.0;
    }
  }

  // Rank 0 allocations for verification and image gathering
  std::vector<double> global_grid_mpi;
  std::vector<double> global_grid_seq;
  std::vector<double> seq_grid_new;

  if (rank == 0) {
    global_grid_mpi.resize(N * N, 0.0);
    // Create image destination directory if it doesn't exist
    std::filesystem::create_directories("image");

    if (vis > 0) {
      // Duplicate initial data to run a separate clean sequential pipeline
      global_grid_seq = std::vector<double>(N * N, 0.0);
      seq_grid_new = std::vector<double>(N * N, 0.0);
      for (int j = N / 4; j < (3 * N) / 4; ++j) {
        global_grid_seq[0 * N + j] = 127.0;
        seq_grid_new[0 * N + j] = 127.0;
      }
    }
  }

  chTimerTimestamp time_start = {};
  chTimerTimestamp time_end = {};
  double total_elapsed_time = 0.0;

  MPI_Barrier(cart_comm);

  for (int t = 0; t < iterations; ++t) {
    if (vis > 0) {
      MPI_Gather(&local_grid[1 * N], rows_local * N, MPI_DOUBLE,
                 global_grid_mpi.data(), rows_local * N, MPI_DOUBLE, 0,
                 cart_comm);

      if (rank == 0) {
        if (t % vis == 0) {
          std::stringstream ss;
          ss << "image/image_" << std::setw(4) << std::setfill('0') << t
             << ".ppm";

          // Export the gathered image state
          save_heatmap_image(global_grid_mpi, ss.str(), N);
        }
        iteration(global_grid_seq, seq_grid_new, N);
        for (int j = N / 4; j < (3 * N) / 4; ++j) {
          seq_grid_new[0 * N + j] = 127.0;
        }
        std::swap(global_grid_seq, seq_grid_new);
        bool match = true;
        for (size_t idx = 0; idx < global_grid_mpi.size(); ++idx) {
          if (std::abs(global_grid_mpi[idx] - global_grid_seq[idx]) > 1e-5) {
            std::cerr << "VERIFICATION FAILURE at timestep " << t << " index "
                      << idx << " (MPI: " << global_grid_mpi[idx]
                      << " vs SEQ: " << global_grid_seq[idx] << ")\n";
            match = false;
            break;
          }
        }
      }
    }

    // --- STEP 2: Core Stencil Simulation Pipeline ---
    chTimerGetTime(&time_start);

    MPI_Request requests[4];
    int req_count = 0;

    double *send_top_row = &local_grid[1 * N];
    double *recv_top_ghost = &local_grid[0 * N];
    double *send_bottom_row = &local_grid[rows_local * N];
    double *recv_bottom_ghost = &local_grid[(rows_local + 1) * N];

    if (rank_top != MPI_PROC_NULL) {
      MPI_Irecv(recv_top_ghost, N, MPI_DOUBLE, rank_top, 0, cart_comm,
                &requests[req_count++]);
      MPI_Isend(send_top_row, N, MPI_DOUBLE, rank_top, 1, cart_comm,
                &requests[req_count++]);
    }
    if (rank_bottom != MPI_PROC_NULL) {
      MPI_Irecv(recv_bottom_ghost, N, MPI_DOUBLE, rank_bottom, 1, cart_comm,
                &requests[req_count++]);
      MPI_Isend(send_bottom_row, N, MPI_DOUBLE, rank_bottom, 0, cart_comm,
                &requests[req_count++]);
    }

    // Overlap: Inner Rows
    for (int i = 2; i < rows_local; ++i) {
      for (int j = 1; j < N - 1; ++j) {
        double self = local_grid[i * N + j];
        double left = local_grid[i * N + (j - 1)];
        double right = local_grid[i * N + (j + 1)];
        double top = local_grid[(i - 1) * N + j];
        double bottom = local_grid[(i + 1) * N + j];

        local_grid_new[i * N + j] = calculate(self, left, top, right, bottom);
      }
    }

    if (req_count > 0) {
      MPI_Waitall(req_count, requests, MPI_STATUSES_IGNORE);
    }

    // Boundary Rows
    std::vector<int> boundary_rows;
    if (rank != 0)
      boundary_rows.push_back(1);
    if (rank != world_size - 1)
      boundary_rows.push_back(rows_local);

    for (int i : boundary_rows) {
      for (int j = 1; j < N - 1; ++j) {
        double self = local_grid[i * N + j];
        double left = local_grid[i * N + (j - 1)];
        double right = local_grid[i * N + (j + 1)];
        double top = local_grid[(i - 1) * N + j];
        double bottom = local_grid[(i + 1) * N + j];

        local_grid_new[i * N + j] = calculate(self, left, top, right, bottom);
      }
    }

    if (rank == 0) {
      for (int j = N / 4; j < (3 * N) / 4; ++j) {
        local_grid_new[1 * N + j] = 127.0;
      }
    }

    std::swap(local_grid, local_grid_new);

    chTimerGetTime(&time_end);
    total_elapsed_time += chTimerElapsedTime(&time_start, &time_end);
  }

  // Final confirmation gather to ensure absolute validation at completion
  if (vis > 0) {
    MPI_Gather(&local_grid[1 * N], rows_local * N, MPI_DOUBLE,
               global_grid_mpi.data(), rows_local * N, MPI_DOUBLE, 0,
               cart_comm);
    if (rank == 0) {
      std::cout << "All simulation loops completed. Output files generated "
                   "inside './image/'\n";
    }
  }

  double max_rank_time = 0.0;
  MPI_Reduce(&total_elapsed_time, &max_rank_time, 1, MPI_DOUBLE, MPI_MAX, 0,
             cart_comm);

  if (rank == 0) {
    double time_per_iteration = max_rank_time / static_cast<double>(iterations);
    double total_flops = static_cast<double>(N - 2) *
                         static_cast<double>(N - 2) * 6.0 *
                         static_cast<double>(iterations);
    double flops_per_sec = total_flops / max_rank_time;

    std::ofstream csvFile("4_5.csv", std::ios::app);
    if (csvFile.is_open()) {
      csvFile << N << "," << time_per_iteration << "," << total_flops << ","
              << flops_per_sec << "," << world_size << "," << nnodes << "\n";
      csvFile.close();
    } else {
      std::cerr
          << "CRITICAL: Error opening benchmark destination file 4_4.csv\n";
    }
  }

  MPI_Comm_free(&cart_comm);
  MPI_Finalize();
  return 0;
}
