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
struct arguments {
  int rank;
  int N;
  int iterations;
  int vis;
  int nnodes;
  int world_size;
};
struct grid {
  std::vector<double> current_grid;
  std::vector<double> new_grid;
  int N;
  grid() = default;
  grid(size_t N) : current_grid(N, 0.0), new_grid(N, 0.0), N(N) {}
  void swap() { std::swap(current_grid, new_grid); }
  void fill_static(size_t row) {
    for (int j = N / 4; j < (3 * N) / 4; ++j) {
      current_grid[row * N + j] = 127.0;
      new_grid[row * N + j] = 127.0;
    }
  }
};

void calc_row(grid &grid, int N, int row) {
  for (int column = 1; column < N - 1; ++column) {
    double self = grid.current_grid[row * N + column];
    double left = grid.current_grid[row * N + (column - 1)];
    double right = grid.current_grid[row * N + (column + 1)];
    double top = grid.current_grid[(row - 1) * N + column];
    double bottom = grid.current_grid[(row + 1) * N + column];

    grid.new_grid[row * N + column] = calculate(self, left, top, right, bottom);
  }
}
void save_bitmap(std::vector<double> &grid, int iteration, int N) {
  std::stringstream ss;
  ss << "image/image_" << std::setw(4) << std::setfill('0') << iteration
     << ".ppm";
  save_heatmap_image(grid, ss.str(), N);
}
int check_with_seq(grid &seq_grid, std::vector<double> &global_grid_mpi, int t,
                   int N) {
  iteration(seq_grid.current_grid, seq_grid.new_grid, N);
  seq_grid.swap();
  bool match = true;
  for (size_t idx = 0; idx < global_grid_mpi.size(); ++idx) {
    if (std::abs(global_grid_mpi[idx] - seq_grid.current_grid[idx]) > 1e-5) {
      return idx;
    }
  }
  return -1;
}

int start_up(int argc, char *argv[], arguments &args) {
  MPI_Init(&argc, &argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &args.rank);
  MPI_Comm_size(MPI_COMM_WORLD, &args.world_size);

  if (argc < 5) {
    if (args.rank == 0) {
      std::cout << "Usage: " << argv[0]
                << " <N> <iterations> <visualization> <nnodes>\n";
      for (int i = 0; i < argc; ++i) {
        std::cout << argv[i] << std::endl;
      }
    }
    MPI_Finalize();
    return 1;
  }

  args.N = std::stoi(argv[1]);
  args.iterations = std::stoi(argv[2]);
  args.vis = std::stoi(argv[3]);
  args.nnodes = std::stoi(argv[4]);
  return 0;
}

void gather(int world_size, int N, grid &local_grid,
            std::vector<double> &global_grid, MPI_Comm cart_comm,
            int rows_local) {
  std::vector<int> recv_counts(world_size);
  std::vector<int> displacements(world_size);

  int disp = 0;
  for (int r = 0; r < world_size; ++r) {
    int r_rows = (N / world_size) + (r < (N % world_size) ? 1 : 0);
    recv_counts[r] = r_rows * N;
    displacements[r] = disp;
    disp += recv_counts[r];
  }
  MPI_Gatherv(&local_grid.current_grid[1 * N], rows_local * N, MPI_DOUBLE,
              global_grid.data(), recv_counts.data(), displacements.data(),
              MPI_DOUBLE, 0, cart_comm);
}

int main(int argc, char *argv[]) {
  arguments args = {};
  start_up(argc, argv, args);

  int dims[2] = {args.world_size, 1};
  int periods[2] = {false, false};
  MPI_Comm cart_comm;
  MPI_Cart_create(MPI_COMM_WORLD, 2, dims, periods, true, &cart_comm);

  int rank_top, rank_bottom;
  MPI_Cart_shift(cart_comm, 0, 1, &rank_top, &rank_bottom);

  int rows_local = args.N / args.world_size;
  int remainder = args.N % args.world_size;

  if (args.rank < remainder) {
    rows_local += 1;
  }
  int rows_allocated = rows_local + 2;

  grid local_grid(rows_allocated * args.N);

  std::vector<double> global_grid_mpi;
  grid seq_grid;

  if (args.rank == 0) {
    local_grid.fill_static(1);
    if (args.vis > 0) {
      global_grid_mpi = std::vector<double>(args.N * args.N);
      std::filesystem::create_directories("image");
      seq_grid = grid(args.N * args.N);
      seq_grid.fill_static(0);
    }
  }

  chTimerTimestamp time_start = {};
  chTimerTimestamp time_end = {};
  double total_elapsed_time = 0.0;

  MPI_Barrier(cart_comm);

  for (int t = 0; t < args.iterations; ++t) {
    if (args.vis > 0) {
      gather(args.world_size, args.N, local_grid, global_grid_mpi, cart_comm,
             rows_local);
      if (args.rank == 0) {
        int idx = check_with_seq(seq_grid, global_grid_mpi, t, args.N);
        if (-1 != idx) {
          std::cerr << "VERIFICATION FAILURE at timestep " << t << " index "
                    << idx << " (MPI: " << global_grid_mpi[idx]
                    << " vs SEQ: " << seq_grid.current_grid[idx] << ")\n";
        }
        if (t % args.vis == 0)
          save_bitmap(global_grid_mpi, t, args.N);
      }
    }

    chTimerGetTime(&time_start);

    MPI_Request requests[4];
    int req_count = 0;

    double *send_top_row = &local_grid.current_grid[1 * args.N];
    double *recv_top_ghost = &local_grid.current_grid[0 * args.N];
    double *send_bottom_row = &local_grid.current_grid[rows_local * args.N];
    double *recv_bottom_ghost =
        &local_grid.current_grid[(rows_local + 1) * args.N];

    if (rank_top != MPI_PROC_NULL) {
      MPI_Irecv(recv_top_ghost, args.N, MPI_DOUBLE, rank_top, 0, cart_comm,
                &requests[req_count++]);
      MPI_Isend(send_top_row, args.N, MPI_DOUBLE, rank_top, 1, cart_comm,
                &requests[req_count++]);
    }
    if (rank_bottom != MPI_PROC_NULL) {
      MPI_Irecv(recv_bottom_ghost, args.N, MPI_DOUBLE, rank_bottom, 1,
                cart_comm, &requests[req_count++]);
      MPI_Isend(send_bottom_row, args.N, MPI_DOUBLE, rank_bottom, 0, cart_comm,
                &requests[req_count++]);
    }

    for (int i = 2; i < rows_local; ++i) {
      calc_row(local_grid, args.N, i);
    }

    if (req_count > 0) {
      MPI_Waitall(req_count, requests, MPI_STATUSES_IGNORE);
    }

    std::vector<int> boundary_rows;
    if (args.rank != 0)
      boundary_rows.push_back(1);
    if (args.rank != args.world_size - 1)
      boundary_rows.push_back(rows_local);

    for (int i : boundary_rows) {
      calc_row(local_grid, args.N, i);
    }

    local_grid.swap();

    if (args.rank == 0) {
      for (int j = args.N / 4; j < (3 * args.N) / 4; ++j) {
        local_grid.current_grid[1 * args.N + j] = 127.0;
      }
    }

    chTimerGetTime(&time_end);
    total_elapsed_time += chTimerElapsedTime(&time_start, &time_end);
  }

  if (args.vis > 0) {
    gather(args.world_size, args.N, local_grid, global_grid_mpi, cart_comm,
           rows_local);
    if (args.rank == 0) {
      std::cout << "All simulation loops completed. Output files generated "
                   "inside './image/'\n";
    }
  }

  double max_rank_time = 0.0;
  MPI_Reduce(&total_elapsed_time, &max_rank_time, 1, MPI_DOUBLE, MPI_MAX, 0,
             cart_comm);

  if (args.rank == 0) {
    double time_per_iteration =
        max_rank_time / static_cast<double>(args.iterations);
    double total_flops = static_cast<double>(args.N - 2) *
                         static_cast<double>(args.N - 2) * 6.0 *
                         static_cast<double>(args.iterations);
    double flops_per_sec = total_flops / max_rank_time;

    std::ofstream csvFile("4_5.csv", std::ios::app);
    if (csvFile.is_open()) {
      csvFile << args.N << "," << time_per_iteration << "," << total_flops
              << "," << flops_per_sec << "," << args.world_size << ","
              << args.nnodes << "\n";
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
