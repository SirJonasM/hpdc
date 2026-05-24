#import "@preview/cetz:0.4.2"
#import "@preview/cetz-plot:0.1.3": chart, plot
#import "@preview/zero:0.6.1": num, zi

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
#let flops = zi.declare("GFLOP/s")

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

#figure(
  grid(
    columns: 5,
    column-gutter: 20pt,
    row-gutter: 5pt,
    [Iteration 10], [Iteration 20], [Iteration 100], [Iteration 200], [Iteration 290],
    image("plots/heatmap0.png"),
    image("plots/heatmap1.png"),
    image("plots/heatmap2.png"),
    image("plots/heatmap3.png"),
    image("plots/heatmap4.png"),
  ),
  caption: [Heat Relaxation: Visualization],
)
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


#let parse_data(file) = {
  let raw-data = csv(file)
  (
    raw-data
      .filter(a => float(a.at(0)) > 100.0)
      .map(row => {
        (
          N: float(row.at(0)),
          time: float(row.at(1)),
          total-flops: float(row.at(2)),
          flops: float(row.at(3)),
        )
      })
  )
}

#let table_show(data) = {
  table(
    columns: 4,
    align: (left, center, center, center),
    stroke: none,
    table.hline(stroke: 1pt),
    row-gutter: 0pt,
    [Grid Size], [Time/iteration], [FLOPS total], [GFLOP/s],
    table.hline(stroke: 0.4pt),

    ..data
      .map(row => (
        [$#row.N times #row.N$],
        [#num(row.time, digits: 3, exponent: "sci")],
        [#num(row.total-flops, digits: 3, exponent: "sci")],
        [#num(row.flops, digits: 3, exponent: "sci")],
      ))
      .flatten(),

    table.hline(stroke: 0.5pt),
  )
}

#let data-4-2 = parse_data("plots/data_4_2.csv")

#figure(
  table_show(data-4-2),
  caption: [Heat Relaxation Experiment 1 grid sizes],
) <table>

*Simple Optimizations*\
By restructuring the execution loops to run strictly from index $1$ to $N - 1$, the code completely bypasses the static outer boundaries.
Additionally, algebraically rearranging the stencil equation into a single linear combination allows the compiler to leverage hardware Fused Multiply-Add (FMA) instructions when compiled with -O3 -march=native.
While this hardware optimization drops the actual instruction footprint from 7 down to 5 operations, the theoretical performance metric is calculated using a baseline footprint of 6 FLOPs per cell ($N times N times 6$).\
Because the primary objective of this metric is to establish a standardized baseline to compare performance across different grid scales, maintaining this constant FLOP definition provides a consistent benchmarking reference regardless of the low-level instructions generated by the compiler.

#figure(
  cetz.canvas({
    plot.plot(
      size: (7, 6),
      x-tick-step: none,
      x-ticks: data-4-2.map(row => row.N).dedup(),
      x-format: value => {
        if value == 0 { return [0] }
        let exp = calc.log(value, base: 2)
        [$2^#int(exp)$]
      },
      y-ticks: (0.00001, 0.0001, 0.001, 0.01, 0.1),
      y-tick-step: none,
      y2-format: value => {
        if value == 0.0 { return [] }
        num(value, digits: 1)
      },
      y-format: value => {
        if value == 0 { return [0] }
        let exp = calc.log(value)
        [$10^#int(exp)$]
      },
      x-label: [Grid Size ($N$)],
      x-mode: "log",
      x-base: 2.0,
      y-mode: "log",
      x-grid: true,
      y-label: [Time (seconds)],
      y2-label: [Performance (GFLOP/s)],
      y2-min: 0.0,
      grid: true,
      {
        plot.add(data-4-2.map(row => (row.N, row.flops / 1e9)), label: "perf.", style: (stroke: red + 1.5pt), axes: (
          "x",
          "y2",
        ))
        plot.add(data-4-2.map(row => (row.N, row.time)), label: "time", style: (stroke: blue + 1.5pt), axes: ("x", "y"))
        plot.add(
          domain: (128, 8192),
          style: (stroke: (paint: gray, dash: "dotted", thickness: 1.5pt)),
          label: [Ideal $O(N)$],
          axes: ("x", "y"),
          x => data-4-2.at(0).time * x / float(data-4-2.at(0).N),
        )
        plot.add(
          domain: (128, 8192),
          style: (stroke: (paint: gray, dash: "dashed", thickness: 1.5pt)),
          label: [Ideal $O(N^2)$],
          axes: ("x", "y"),
          x => data-4-2.at(0).time * calc.pow(x / float(data-4-2.at(0).N), 2),
        )
      },
    )
  }),
  caption: [ Heat Relaxation Experiment 1 - grid sizes],
)<fig1>


*Interpretation of Results*\
The experimental results show that the execution time scales quadratically ($cal(O)(N^2)$) relative to the grid size $N$,
which is visually confirmed by the time curve running perfectly parallel to the ideal $cal(O)(N^2)$ reference line.
Concurrently, the computational throughput (perf.) does not drop off at larger grid sizes.
Instead, it scales upward and stabilizes at a high plateau between $3.2$ and #flops[3.5].\
This sustained, high performance across massive data scales demonstrates that the program is compute-bound, meaning the optimizations (such as FMA restructuring and boundary bypassing) successfully saturated the processor's execution units to maintain optimal operational efficiency.

= Heat Relaxation - Pre-considerations for parallelization
- We now want to parallelize the heat relaxation application using message passing.
  For preperations develop a now suitable partitioning and task model.\
  Propose a suitable model by, answering the following questions:
  - How can you decompose this problem into sub-tasks? Which dependencies between tasks do exist?
  - Is 1D or 2D partitioning more suitable?
  - What opportunities are there to leverage between computation and communication?
- Provide a detailed explanation.
  A visualization can help greatly for explaining your approach.


= Heat Relaxation - Parallel implementation based on 1D-row partitioning
Use te program developed in Section 4.1 to start with this exercise.
The configuration is the same ass before, but this time the goal is to parallelize this program for MPI.
- Perform a 1D row partitioning, so each process only has to exchange consecutive addresses (C has a row-based layout in memory) to its neightbor.
  This should simplify the communication at the cost of addictional communication per process.
- Make a new communicator with topology information attached (see `MPI_Cart_create`).
  The topology information helps to determine processes working on neighbor data domains.
- Ensure that you use two arrays for the current and previous grid. Do not exchange these two arrays by copying (after one iteration), instead just exchange the pointers to them.
- Maximize overlap by first calculation the borders and then sending them out in a non-blocking fashion.
- Use the visualization from Section 4.1 to test your program extensively. Also compare results against the sequential implementation to ensure correctness.

#let parse_data_4_5(file) = {
  let raw-data = csv(file)
  (
    raw-data.map(row => {
      let p1 = row.at(4)
      let p2 = row.at(5)
      (
        N: int(row.at(0)),
        time: float(row.at(1)),
        flops: float(row.at(3)) / 1e9,
        world-size: int(p1),
        nodes: int(p2),
      )
    })
  )
}

#let data-4-5 = parse_data_4_5("plots/4_5.csv")
#let colors = (blue, red, red, green, orange, purple)

#cetz.canvas({
  plot.plot(
    size: (7, 6),
    x-tick-step: none,
    x-ticks: data-4-5.map(row => row.N).dedup(),
    x-format: value => {
      if value == 0 { return [0] }
      let exp = calc.log(value, base: 2)
      [$2^#int(exp)$]
    },
    y-ticks: (0.00001, 0.0001, 0.001, 0.01, 0.1),
    y-tick-step: none,
    y2-format: value => {
      if value == 0.0 { return [] }
      num(value, digits: 1)
    },
    y-format: value => {
      if value == 0 { return [0] }
      let exp = calc.log(value)
      [$10^#int(exp)$]
    },
    x-label: [Grid Size ($N$)],
    x-mode: "log",
    x-base: 2.0,
    y-mode: "log",
    x-grid: true,
    y-label: [Time (seconds)],
    {
      let unique-groups = data-4-5.map(row => (world-size: row.world-size, nodes: row.nodes)).dedup()
      let index = 0
      for group in unique-groups {
        let group-data = data-4-5
          .filter(row => row.world-size == group.world-size and row.nodes == group.nodes)
          .map(row => (row.N, row.time))

        let style = if group.nodes == 1 {
          (style: (stroke: (paint: colors.at(calc.rem(index, 6)), dash: "solid", thickness: 1.5pt)))
        } else if group.nodes == 2 {
          (style: (stroke: (paint: colors.at(calc.rem(index, 6)), dash: "dotted", thickness: 1.5pt)))
        } else if group.nodes == 4 {
          (style: (stroke: (paint: colors.at(calc.rem(index, 6)), dash: "dashed", thickness: 1.5pt)))
        }
        plot.add(group-data, label: str(group.world-size) + "|" + str(group.nodes), style: style)
        index = index + 1
      }
      plot.add(
        domain: (128, 8192),
        style: (stroke: (paint: gray, dash: "dotted", thickness: 1.5pt)),
        label: [Ideal $O(N)$],
        axes: ("x", "y"),
        x => data-4-5.at(0).time * x / data-4-5.at(0).N,
      )
      plot.add(
        domain: (128, 8192),
        style: (stroke: (paint: gray, dash: "dashed", thickness: 1.5pt)),
        label: [Ideal $O(N^2)$],
        axes: ("x", "y"),
        x => data-4-5.at(0).time * calc.pow(x / float(data-4-5.at(0).N), 2),
      )
    },
  )
})

#cetz.canvas({
  plot.plot(
    size: (7, 6),
    x-tick-step: none,
    x-ticks: data-4-5.map(row => row.N).dedup(),
    x-format: value => {
      if value == 0 { return [0] }
      let exp = calc.log(value, base: 2)
      [$2^#int(exp)$]
    },
    x-label: [Grid Size ($N$)],
    x-mode: "log",
    x-base: 2.0,
    x-grid: true,

    y-label: [Performance (GFLOP/s)],
    y-min: 0.0,
    y-format: value => {
      if value == 0.0 { return [] }
      num(value, digits: 1)
    },
    {
      let index = 0
      let unique-groups = data-4-5.map(row => (world-size: row.world-size, nodes: row.nodes)).dedup()
      for group in unique-groups {
        let group-data = data-4-5
          .filter(row => row.world-size == group.world-size and row.nodes == group.nodes)
          .map(row => (row.N, row.flops))

        let style = if group.nodes == 1 {
          (style: (stroke: (paint: colors.at(calc.rem(index, 6)), dash: "solid", thickness: 1.5pt)))
        } else if group.nodes == 2 {
          (style: (stroke: (paint: colors.at(calc.rem(index, 6)), dash: "dotted", thickness: 1.5pt)))
        } else if group.nodes == 4 {
          (style: (stroke: (paint: colors.at(calc.rem(index, 6)), dash: "dashed", thickness: 1.5pt)))
        }
        plot.add(group-data, label: str(group.world-size) + "|" + str(group.nodes), style: style)
        index = index + 1
      }
    },
  )
})

#let plot_nodes_fix_N(N) = cetz.canvas({
  let data = data-4-5.filter(row => row.N == N)

  let unique-worlds = data.map(row => row.world-size).dedup().sorted()
  let unique-nodes = data.map(row => row.nodes).dedup().sorted()

  let grouped-data = unique-nodes
    .enumerate()
    .map(((idx, nodes-val)) => {
      let flops-list = unique-worlds.map(world-val => {
        let match = data.find(row => row.world-size == world-val and row.nodes == nodes-val)
        if match != none { match.flops } else { 0.0 }
      })
      (nodes-id: idx, flops: flops-list)
    })
  let custom-colors = (red.lighten(10%), blue, green, yellow, purple, black, gray)

  plot.plot(
    size: (7, 6),
    legend: "inner-north-west",
    x-label: [Nodes],
    x-tick-step: none,
    x-ticks: grouped-data.map(row => row.nodes-id).dedup(),
    x-format: value => {
      let nodes-label = unique-nodes.at(int(value), default: none)
      if nodes-label != none [ #nodes-label ]
    },
    y2-label: [Performance (GFLOP/s)],
    plot-style: idx => {
      let color = custom-colors.at(idx, default: gray)
      (stroke: color, fill: color.transparentize(85%))
    },
    {
      plot.add-bar(
        grouped-data,
        x-key: "nodes-id",
        y-key: "flops",
        mode: "clustered",
        bar-width: 0.6,
        bar-position: "center",
        labels: unique-worlds.map(row => "Worlds: " + str(row)),
        axes: ("x", "y2"),
      )
    },
  )
})

#let plot_world_size_fix_N(N) = cetz.canvas({
  let data = data-4-5.filter(row => row.N == N)

  let unique-worlds = data.map(row => row.world-size).dedup().sorted()
  let unique-nodes = data.map(row => row.nodes).dedup().sorted()

  let grouped-data = unique-worlds
    .enumerate()
    .map(((idx, world-val)) => {
      let flops-list = unique-nodes.map(n => {
        let match = data.find(row => row.world-size == world-val and row.nodes == n)
        if match != none { match.flops } else { 0.0 }
      })

      (world-id: idx, flops: flops-list)
    })

  plot.plot(
    size: (7, 6),
    legend: "inner-north-west",
    x-label: [World size],
    x-tick-step: none,
    x-ticks: grouped-data.map(row => row.world-id).dedup(),
    x-format: value => {
      let world-size-label = unique-worlds.at(int(value), default: none)
      if world-size-label != none [ #world-size-label ]
    },
    y-label: [Performance (GFLOP/s)],
    y-min: 0.0,
    {
      plot.add-bar(
        grouped-data,
        x-key: "world-id",
        y-key: "flops",
        mode: "clustered",
        bar-width: 0.6,
        bar-position: "center",
        labels: unique-nodes.map(row => "Nodes: " + str(row)),
      )
    },
  )
})
#grid(
  columns: 2,
  rows: 3,
  column-gutter: 3.5cm,
  row-gutter: 0.5cm,
  ..for size in (7, 11, 13) {
    let N = calc.pow(2, size)
    (figure(plot_world_size_fix_N(N), caption: [$N = #N$]), figure(plot_nodes_fix_N(N), caption: [$N = #N$]))
  },
)

== Speedup
From the previous analysis we see that for $N = 8192$ the best performance was achieved with 1 node and 24 worlds.
So we will plot the speedup using that.
and we will also plot 24 worlds and 4 nodes as that was the maximum.


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
    [Ex 5], text(green)[#sym.checkmark],
  ),
)




