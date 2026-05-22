#import "@preview/cetz:0.4.2"
#import "@preview/cetz-plot:0.1.3": chart, plot

#let exnr = "4"
#let authors = (
  "Jonas Möwes",
  "Daubner, Andy",
  "Rockenzahn Gallegos, David",
)
#set math.equation(numbering: "(1)", supplement: [])

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
  font: "New Computer Modern",
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
= Heat Relaxation - Sequential Implementation
Relaxation is a mathematical technique used for modeling or the simulation of dynamic processes (heat distribution, material yielding, etc.).\
In this technique, the solution of a multi-dimensional function is mapped to a discrete grid.
The value of a given grid point is dependent on the values of the previous time step, usually of the point itself and its surrounding neighbors.\
Implement a program, which calculates the new value of grid points as average of the point itself and its four direct neighbors, according Equations (@heat_dist) and (@factor):
- The size of the grid $N$ shall be configurable using a command line parameter
- Dynamically allocate a grid of $N times N$ double precision floating point values.
  The allowed value range is $[0,127]$
- Inject heat in the topmost grid points ($j = 0$), with i in between $[N/4, 3N/4]$.
  These grid points are set statically to 127. The value of all other grid points at the borders is statically set to 0.
- Visualize the output and use it to extensively check for correctness.
$
  x^(t+1)_(i,j) = x^(t)_(i,j) + Phi dot ((-4) dot x^(t)_(i,j) + x^(t)_(i+1,j) + x^(t)_(i-1,j) + x^(t)_(i,j+1) + x^(t)_(i,j-1))
$ <heat_dist>

$
  Phi = 24/100
$ <factor>

#figure(grid(
  columns: 5,
  column-gutter: 20pt,
  row-gutter: 5pt,
  [Iteration 10], [Iteration 20], [Iteration 100], [Iteration 200], [Iteration 290],
  image("plots/heatmap0.png"),
  image("plots/heatmap1.png"),
  image("plots/heatmap2.png"),
  image("plots/heatmap3.png"),
  image("plots/heatmap4.png"),
))
= Heat Relaxation - Experiments 1
- Measure the average time for grid sizes listed in @table.
  Report the average time of one iteration by performing 100 iterations, measuring the time with a suitable function and dividing by the number of iterations.
  Do not include time for initialization or output.
- Use compiler specific optimizations to minimize the runtime.
- Determine the number of FLOPs achieved for each of the grid sizes.
- Is this program computational bound or memory-bound?
  Provide a well reasoned explanation!
- Report your raw results by filling out @table.
- Visualize and interpret your results!

#figure(
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 1pt),
    row-gutter: 0pt,
    [Grid Size], [Time/iteration], [FLOPS total], [GFLOP/s],
    table.hline(stroke: 0.4pt),
    [$128 times 128$], [2.18524e-05], [1.11132e+07], [5.08558],
    [$256 times 256$], [7.78527e-05], [4.51612e+07], [5.80085],
    [$512 times 512$], [0.000347226], [1.8207e+08], [5.24356],
    [$1024 times 1024$], [0.00165184], [7.31139e+08], [4.42621],
    [$2048 times 2048$], [0.00794807], [2.93028e+09], [3.68678],
    [$4096 times 4096$], [0.0299907], [1.17326e+10], [3.91208],
    [$8192 times 8192$], [0.134637], [4.69533e+10], [3.4874],
    table.hline(stroke: 0.5pt),
  ),
  caption: [Heat Relaxation Experiment 1 grid sizes],
) <table>

#let raw-data = csv("ex04_Template/4_2.csv")

#let parsed-rows = (
  raw-data
    .slice(1)
    .map(row => {
      (
        float(row.at(0)), // N
        float(row.at(1)), // Time
        float(row.at(2)), // Total FLOPS
        float(row.at(3)) / 1e9, // FLOP/s converted to GFLOP/s for readability
      )
    })
)

#let time-data = parsed-rows.map(row => (row.at(0), row.at(1)))
#let flops-data = parsed-rows.map(row => (row.at(0), row.at(3)))
*Simple Optimizations*\
By restructuring the execution loops to run strictly from index $1$ to $N - 1$, the code completely skips the static outer boundaries.
Furthermore, algebraically rearranging the equation into a single linear combination allows the compiler to leverage hardware Fused Multiply-Add (FMA) instructions when built with `-O3 -march=native`.
This drops the mathematical operation count from 7 individual instructions down to 5.

#figure(
  cetz.canvas({
    plot.plot(
      size: (7, 6),
      x-tick-step: none,
      x-ticks: (128, 256, 512, 1024, 2048, 4096, 8192),
      y-ticks: (0.00001, 0.0001, 0.001, 0.01, 0.1),
      y-tick-step: none,
      y-format: "sci",
      x-label: [Grid Size ($N$)],
      x-mode: "log",
      x-base: 2.0,
      y-mode: "log",
      x-grid: true,
      y-label: [Time (seconds)],
      y2-label: [Performance (GFLOP/s)],
      y2-ticks-step: none,
      grid: true,
      {
        plot.add(time-data, label: "Time", style: (stroke: blue + 1.5pt), line: "raw", axes: ("x", "y"))
        plot.add(flops-data, label: "GFLOP/s", style: (stroke: red + 1.5pt), line: "raw", axes: ("x", "y2"))
      },
    )
  }),
  caption: [ Heat Relaxation Experiment 1 - grid sizes],
)<fig1>


*Interpretation of Results*\
The execution time scales linearly with the overall problem size. 
However, the computational throughput (GFLOP/s) steadily degrades as $N$ increases past 256.
This drop perfectly confirms a memory-bound bottleneck:
smaller grids fit entirely within high-speed CPU cache layers, but larger matrices exceed cache limits and force the processor to stall while waiting for data transfers from the slower main memory.

= Willingness to present
#grid(
  columns: 2,
  column-gutter: 1fr,
  grid(
    columns: 2,
    row-gutter: 1em,
    column-gutter: 20pt,
    [Ex 1], text(green)[#sym.checkmark],
    [Ex 2], text(green)[#sym.checkmark],
    [Ex 3], text(green)[#sym.checkmark],
  ),
  grid(
    columns: 2,
    row-gutter: 1em,
    column-gutter: 20pt,
    [Ex 4], text(green)[#sym.checkmark],
  ),

  [Ex 5], text(green)[#sym.checkmark],
),
)




