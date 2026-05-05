#import "@preview/zebraw:0.6.3": *
#show: zebraw
#let exnr = "2"
#let authors = (
  "Jonas Möwes",
  "Daubner, Andy",
  "Rockenzahn Gallegos, David",
)

#set list(marker: ([--], [--], [--]))

#let course = "High Performance and Distributed Computing"
#let group = "Group 6"
#let date = datetime.today()
#show regex("Task \d+:"): strong
#show "Task:": strong
#show "Answer:": strong
#show regex("Result.*:"): strong
#let line2() = line(length: 7%, stroke: 1pt + gray.darken(50%))

#let round4(body) = calc.round(body, digits: 4)
#let round2(body) = calc.round(body, digits: 2)

#set text(
  font: "Libertinus Serif",
  size: 11pt,
)
#show raw: set text(font: "Iosevka NF")

#set page(numbering: "(i)", header: [
  #set text(8pt)
  #grid(
    columns: 2,
    column-gutter: 1fr,
    row-gutter: 0.5em,
    align: (left, right),
    course, [University Heidelberg],
    group, date.display("[day].[month].[year]"),
  )
])

#set heading(numbering: "1.1")
#show heading: it => block(
  below: 1em,
  {
    if it.numbering != none {
      // Adds "Section " before the number
      exnr + "." + counter(heading).display(it.numbering) + " - "
    }
    it.body
  },
)

#align(right, text(10pt)[
  #authors.join(linebreak())
])

#align(center, title([Exercise #exnr]))
= Barrier Synchronization
Task:\
Now we want to measure the performance of an MPI barrier. First implement your own barrier, either a centralized barrier or a tree-based barrier.
It's your choice, however a centralized barrier might be easier to implement. Your choice won't have an impact on achievable points. \
Write a suitable test program to measure the performance of your own barrier implementations. For this purpose call the barrier within a for-loop and measure the overall time of the loop. The number of iterations should be passed to the program as a command line parameter. 
Use a sufficient number of iterations to get stable results. Report average barrier latency (loop execution time divided by the number of iterations) for 2,4,6,...,24 processes.
Do the same measurments with the MPI built-in barrier. Compare the performance and plot both results in one graph.

Results:\
The custom barrier is centralized, meaning rank 0 is responsible for coordination. Rank $0$ first waits for a message containing a single integer to be received from every other rank. The moment this happens, the ranks are synchronized. A broadcast is used to notify all other ranks.

The fan-in is $cal(O)(n)$ (this could be optimized further). However, the fan-out uses the built in broadcast. Which likely implements a tree to get $cal(O)(log n)$.

#figure(image("plots/2_1_latency.png", width: 60%))

Both implementations have a linear relationship between the process count and latency. Surprisingly, the custom barrier has lower latency compared to the built in version at large numbers of processes. One theory for why this might be is that the test conditions of running the barrier in a loop are not representative of the real world. Usually barriers are used sparingly to minimise the amount of time processes wait. `MPI_Barrier()` was probably developed with this in mind. Whereas in our custom implementation MPI might be smart enough to cache or prioritize sends or broadcasts that happen often. Future work could include testing these barriers embedded in some more complex programs.

= Matrix Multiply
Task: \
Implement a naïve - i.e. non-optimized - sequential version of the matrix multiply operation.
Multiply two double-precision floating point matrices.
Initialize the matrices using random values.
Use appropriate time measurement functions to measure the execution of the multiply operation itself (i.e., without initialization or output).

Execute the program on one idle node.
Report the execution time and the achieved GFLOP/s for a matrix multiply of the size 2048x2048 elements.

Explain the huge gap between achieved GFLOP/s and theoretical peak GFLOP/s, in particular which subsystem of this computer is the bottleneck for the execution of this program.
Optimize your program and overcome the locality problem of this program, explain and implement your idea.
Execute the improved version, measure again execution time and achieved GFLOP/s. 

* Benchmark Results: *
#figure(
  table(
    stroke: 0.5pt,
    columns: 3,
    [Metric], [*Naive*], [*Optimized*],
    [Time (s)], [$45.6315$], [$5.14832$],
    [GFLOP/s], [$0.376492$], [$3.33698$],
  ),
  caption: [Matrix Multiply $2048 times 2048$],
)

*Why the huge gap?* \
The primary issue is Spatial Locality. In the naïve `i,j,k` loop order, the innermost loop iterates over `k`. While this accesses Matrix A row-wise (contiguously), it accesses Matrix B column-wise. Because matrices are stored in row-major order, each increment of `k` jumps an entire row in B. \
This results in:
- *Cache Misses:* The CPU cannot effectively use its L1/L2 caches because the required data is not adjacent in memory.
- *Memory Latency:* The system is forced to constantly fetch new cache lines from the slower RAM, leaving the Floating Point Units (FPUs) idle.

#figure(caption: [Naive implementation], zebraw(
  highlight-lines: (
    (6, [Here we acces `B` column-wise]),
  ),
  ```c
  void local_matmul(double *A, double *B, double *C, int rows) {
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < rows; j++) {
        double sum = 0.0;
        for (int k = 0; k < rows; k++) {
          sum += A[i * rows + k] * B[k * rows + j];
        }
        C[i * rows + j] = sum;
      }
    }
  }
  ```,
))


*Optimization*\
We can optimize the access pattern by moving the `j` loop to the innermost position:
+ *Fixed Pointer:* The value `A[i][k]` becomes constant for the duration of the innermost loop.
+ *Linear Access:* Both `B[k][j]` and `C[i][j]` are now accessed by their row index `j`.
+ *Contiguous Loading:* The CPU can now read B and write to C in a perfect linear stream which is more cache friendly and also allows for vector optimizations.

#figure(
  caption: [Optimized implementation],
  zebraw(
    highlight-lines: (
      (2, [Initialize C to zero to allow for accumulation in the new loop order]),
      (5, [Reordered: 'k' loop moved up to make the innermost 'j' loop access memory contiguously]),
      (6, [Hoist A[i][k] to a temporary variable to reduce redundant memory lookups]),
      (8, [Linear access: B and C are now accessed via 'j', maximizing cache hits]),
    ),
    ```c
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
    ```,
  ),
)

Results:
As shown in the table, reordering the loops reduced the execution time from $45.63"s"$ to $5.15"s"$, improving performance by approximately 8.8x.
= Willingness to present
#grid(
  columns: 2,
  column-gutter: 1fr,
  grid(
    columns: 2,
    row-gutter: 1em,
    column-gutter: 20pt,
    [Ex 1 - Barrier Synchronization], text(green)[#sym.checkmark],
    [Ex 2 - Matrix Multiply], text(green)[#sym.checkmark],
  ),
)
