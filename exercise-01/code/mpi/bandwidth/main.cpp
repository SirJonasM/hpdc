#include <mpi.h>

#include <chrono>
#include <filesystem>
#include <iostream>
#include <string>

constexpr int kb_to_ints(int kb) { return (kb * 1024) / sizeof(int); }

const int ITERATIONS = 1000;
int main(int argc, char *argv[]) {
  std::cout.setf(std::ios::fixed, std::ios::floatfield);

  // Initialize MPI
  MPI_Init(&argc, &argv);

  // Get the rank and size of the MPI communicator
  int rank, size;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);

  // Allocate 2MB buffer
  std::vector<int> buffer(kb_to_ints(2048), 2);

  if (rank == 0) {
    std::cout << "KB_Size,Iterations,Is_Blocking,Total_Time,Bandwidth_MBs"
              << std::endl;

    // --- BLOCKING TEST ---
    for (int kb = 1; kb <= 1024; kb *= 2) {
      int msg_size = kb_to_ints(kb);
      double start = MPI_Wtime();
      for (int i = 0; i < ITERATIONS; ++i) {
        MPI_Send(buffer.data(), msg_size, MPI_INT, 1, 0, MPI_COMM_WORLD);
        int ack;
        MPI_Recv(&ack, 1, MPI_INT, 1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
      }
      double duration = MPI_Wtime() - start;
      double bandwidth = ((double(kb) / 1024.0) * ITERATIONS) / duration;
      std::cout << kb << "," << ITERATIONS << ",1," << duration << ","
                << bandwidth << std::endl;
    }

    // Signal Rank 1 that Blocking section is done
    int stop = -1;
    MPI_Send(&stop, 1, MPI_INT, 1, 99, MPI_COMM_WORLD);

    // --- NON-BLOCKING TEST ---
    for (int kb = 1; kb <= 2048; kb *= 2) {
      int msg_size = kb_to_ints(kb);
      double start = MPI_Wtime();
      for (int i = 0; i < ITERATIONS; ++i) {
        MPI_Request send_req, recv_req;
        int ack;

        MPI_Isend(buffer.data(), msg_size, MPI_INT, 1, 0, MPI_COMM_WORLD,
                  &send_req);
        MPI_Irecv(&ack, 1, MPI_INT, 1, 0, MPI_COMM_WORLD, &recv_req);

        // Wait for both to complete
        MPI_Wait(&send_req, MPI_STATUS_IGNORE);
        MPI_Wait(&recv_req, MPI_STATUS_IGNORE);
      }
      double duration = MPI_Wtime() - start;
      double bandwidth = ((double(kb) / 1024.0) * ITERATIONS) / duration;
      std::cout << kb << "," << ITERATIONS << ",0," << duration << ","
                << bandwidth << std::endl;
    }

    MPI_Send(&stop, 1, MPI_INT, 1, 99, MPI_COMM_WORLD);
  } else if (rank == 1) {
    int dummy_ack = 1;
    while (true) {
      MPI_Status status;
      MPI_Probe(0, MPI_ANY_TAG, MPI_COMM_WORLD, &status);

      if (status.MPI_TAG == 99) {
        int stop_val;
        MPI_Recv(&stop_val, 1, MPI_INT, 0, 99, MPI_COMM_WORLD,
                 MPI_STATUS_IGNORE);

        static int stops_received = 0;
        stops_received++;
        if (stops_received >= 2)
          break; // Exit after 2 stop signals
        continue;
      }

      int count;
      MPI_Get_count(&status, MPI_INT, &count);
      MPI_Recv(buffer.data(), count, MPI_INT, 0, 0, MPI_COMM_WORLD,
               MPI_STATUS_IGNORE);
      MPI_Send(&dummy_ack, 1, MPI_INT, 0, 0, MPI_COMM_WORLD);
    }
  }

  // Finalize MPI
  MPI_Finalize();
  return 0;
}
