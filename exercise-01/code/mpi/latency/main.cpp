#include <mpi.h>

#include <chrono>
#include <filesystem>
#include <iostream>
#include <string>

constexpr int kb_to_ints(int kb) { return (kb * 1024) / sizeof(int); }

struct record {
  int kb;
  int reps;
  double rtt_time;
};

int main(int argc, char *argv[]) {

  std::cout.setf(std::ios::fixed, std::ios::floatfield);

  // Initialize MPI
  MPI_Init(&argc, &argv);

  // Get the rank and size of the MPI communicator
  int rank, size;
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  MPI_Comm_size(MPI_COMM_WORLD, &size);

  // Get the hostname of the processor
  char hostname[MPI_MAX_PROCESSOR_NAME];
  int hostname_len;
  MPI_Get_processor_name(hostname, &hostname_len);

  const int MAX_REPS = 200;

  // Output the rank, size, hostname, and all CLI parameters
  std::cout << "Hello from rank " << rank << " out of " << size
            << " processes on host " << hostname << " with cli parameters: '";
  for (int i = 1; i < argc; ++i) {
    std::cout << argv[i];
    if (i < argc - 1) {
      std::cout << ", ";
    }
  }
  std::cout << "'" << std::endl;

  // Allocate 1MB buffer
  std::vector<int> buffer(kb_to_ints(1024), 2);
  if (rank == 0) {
    // std::vector<std::vector<float>> average_rtt(11,
    // std::vector<float>(MAX_REPS, 0.0f)); (packet_size (kb), repetition_id,
    // rtt (s))
    std::vector<record> results;
    results.reserve(11 * MAX_REPS);

    auto buffer_data = buffer.data();

    for (auto reps = 0; reps < MAX_REPS; reps++) {
      int kb = 1;
      // std::cout << "rep: " << reps+1 << std::endl;
      for (int i = 0; i < 11; i++) {
        int msg_size = kb_to_ints(kb);

        // std::cout << "Message size: " << msg_size * sizeof(int) << " " << kb
        // << "KiB" << std::endl;

        // send size
        MPI_Send(&msg_size, 1, MPI_INT, 1, 0, MPI_COMM_WORLD);

        double start = MPI_Wtime();
        // send `size` ints
        MPI_Send(buffer_data, msg_size, MPI_INT, 1, 0, MPI_COMM_WORLD);

        // receive pong
        MPI_Recv(buffer_data, msg_size, MPI_INT, 1, 0, MPI_COMM_WORLD,
                 MPI_STATUS_IGNORE);

        auto rtt_time = MPI_Wtime() - start;
        // std::cout << "rtt " << msg_size * sizeof(int) / 1024 << " KiB: " <<
        // rtt_time << " s" << std::endl;
        //  average_rtt[i][reps] = rtt_time;
        record result = record{kb, reps, rtt_time};
        results.emplace_back(result);
        kb *= 2;
      }
    }
    int msg_size = -1; // signal to stop
    MPI_Send(&msg_size, 1, MPI_INT, 1, 0, MPI_COMM_WORLD);
    std::cout << "packet_size,repetition_id,rtt" << std::endl;
    for (const record result: results) {
      std::cout << result.kb << "," << result.reps << "," << std::fixed
                << std::setprecision(15) << result.rtt_time << std::endl;
    }
  } else if (rank == 1) {
    while (true) {
      // recv size
      int msg_size = 1;
      MPI_Recv(&msg_size, 1, MPI_INT, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);

      if (msg_size == -1) {
        break;
      }

      // recv buffer
      MPI_Recv(buffer.data(), msg_size, MPI_INT, 0, 0, MPI_COMM_WORLD,
               MPI_STATUS_IGNORE);

      // send back
      MPI_Send(buffer.data(), msg_size, MPI_INT, 0, 0, MPI_COMM_WORLD);
    }
  }

  // Finalize MPI
  MPI_Finalize();
  return 0;
}
