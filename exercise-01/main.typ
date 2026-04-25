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
#show "Answer:": strong
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

= Moore's Law
Task 1: \
Apply Moore's Law (or one of the derived ones, see lecture) to the currently fastest supercomputer worldwide (see #link("https://www.top500.org")).\
In which year will the performance of the fastest supercomputer exeed one Zettaflop?

Answer: \
The performance of the fastest supercomputer is currently $2,821.10 dot 10^15 "FLOP/s"$
#grid(
  columns: 2,
  gutter: 1fr,
  align: left,
  [
    #let v1 = calc.log(2.821, base: 2)
    #let v2 = calc.log(1000, base: 2)
    #let result = v2 - v1
    Doubling every year:
    $ f(x) = 2^x $
    $ f(x) = 2.8211 => x = approx #round4(v1) $
    $ f(x) = 10^21 => x = approx #round4(v2) $

    So it would take approximatly $#round4(v2) - #round4(v1) = underline(underline(#str(round4(result))))$ years.
  ],
  [
    #let v1 = 2 * calc.log(2.821, base: 2)
    #let v2 = 2 * calc.log(1000, base: 2)
    #let result = v2 - v1
    Doubling every 2 years:
    $ f(x) = 2^(x/2) $
    $ f(x) = 2.8211 => x = approx #round4(v1) $
    $ f(x) = 1000 => x = approx #round4(v2) $

    So it would take approximatly $#round4(v2) - #round4(v1) = underline(underline(#str(round4(result))))$ years.
  ],
)

#line2()
Task 2: \
Determine the exponential growth rate of the TOP500 list by using the fastest system form 11/2007 and 11/2011 (Use the $R_"max"$ value)

Answer: \

#let y1 = 478.2
#let y2 = 10510.0
#let x1 = 2007
#let x2 = 2011
#let t = x2 - x1
#let growth_rate = calc.root(y2 / y1, t) - 1

November 2007: $R_"max" = #y1 dot 10^12 "Flop/s"$ \
November 2011: $R_"max" = #y2 dot 10^12 "Flop/s"$ \
Exponential Growth:
$ y = a(1+r)^t $
With: \
$a = #y1$: Initial value\
$y = #y2$: Final value\
$t = #x2 - #x1 = #t$: time interval\
Solve for  Growth rate $r$:
$ y/a = (1 + r)^t $
$ root(t, y/a) = (1 + r) $
$ r = root(t, y/a) - 1 = root(#str(t), #y2/#y1)-1 = underline(underline(#str(round4(growth_rate)))) $

The exponential growth rate was #round4(growth_rate) betwenn November 2007 and November 2011.


#let t_d = calc.ln(2) / calc.ln(1 + growth_rate)
To put that in context (Doubling time in that period):
$ T_d = ln(2)/ln(1 + r) $
$ T_d = ln(2)/ln(#str(round4(growth_rate))) approx #round4(t_d) $
This means the performance doubled every #round2(12 * t_d) months.

= Amdahl's Law
Task 1: \
The CPU of a webserver is to be improved. For web applications, the new CPU is 10 times faster than the old one.
Consider the case that the old CPU is spending $40%$ of its execution time for calculations and the remaining time for IO, which performance improvement can be expected according to Amdahl's law.

Answer: \
The newer processor can only speedup the calculation time. We can split the time into two fractions
- i: IO ($= 0.6$)
- c: calculations ($= 0.4$)
The Time can then be given as:
$ T = i dot T + c dot T $
We can replace the IO fraction $i$ with $1-c$ to give the Time in accordance to the calculation fraction:
$ T = (1-c) dot T + c dot T $
The new time is then:
$ T = (1-c) dot T + (c dot T)/10 $
#let speedup = [#round4(1 / (0.6 + 0.04))]
The speedup is then:
$
  T_"old"/T_"new" = (T ((1-c) + c)) / (T (1-c + c/10)) = (1+c-c)/(1-c + c/10) = 1/(0.6 + 0.04) = underline(underline(#speedup))
$

#line2()
#set enum(numbering: "(1)")
Task 2: \
A common floating-point (FP) operation is the square root opertation (FPSQR). In a complex calculation, $20%$ of the execution time is spent for calculating square roots. For an optimization, two possibilites do exist:
+ Improve only the implementation of FPSQR, so that it is accelerated by a factor of 10.
+ Improve all FP operations by a factor of 1.6.
Assume that half of the execution time is spent for FP operations.
Compare both alternatives and identify the optimal solution.

Answer: \
We can use Amdahl's law with different fractions ($f_1, f_2$) where only the $f_2$ fractions is accelerated by $s$:
$ a = 1/(1-f_2 + f_2/s) $
#grid(
  columns: 2,
  gutter: 1fr,
  [
    Case 1:\
    $
      f_1 & = 0.8: && "non FP operations" \
      f_2 & = 0.2: && "FP operations" \
        s & = 10:  && "Acceleration of the " f_2 " fraction"
    $
    Amdahl's Law:
    $ a = 1/(1-0.2 + 0.2/10) = 1/#round4(1-0.2 + 0.2/10) approx #round4(1/(1-0.2 + 0.2/10)) $
  ],
  [
    Case 2:\
    $
      f_1 & = 0.5: && "non FP operations" \
      f_2 & = 0.5: && "FP operations" \
        s & = 1.6: && "Acceleration of the " f_2 " fraction"
    $
    Amdahl's Law:
    $ a = 1/(1-0.5 + 0.5/1.6) approx #round4(1/(1-0.5 + 0.5/1.6)) $
  ],
)

In #underline([case 2]) the speedup is greater so that would be the optimal solution.

#set enum(numbering: "1.")
#line()

Task 3: \
An application is to be implemented as parallel program for an execution on 128 processors. In order to achieve a speedup of 100x, how big (in percent) can the serial fraction of the application be?

Answer: \
Amdahl's Law in terms of serial fraction:
$
  a = 1/(f_"serial" + (1- f_"serial")/s)
$
With ($f_"serial" = x$):
$
  a = 1/(x+(1- x)/s) = 100
$
$
  1/100 = x+(1-x)/s | dot s
$
$
  s/100 = s dot x + 1 - x
$
$
  s/100 = x (s-1) + 1
$
$
  x = (s/100 -1)/(s-1)
$
With $s = 128$:
#let serial_fraction = round2((128/100 -1)/(128-1) * 100 )
$
  x = (128/100 -1)/(128-1) approx #round4((128/100 -1)/(128-1)) = underline(underline(#serial_fraction %))
$
The maximum serial fraction is $#serial_fraction %$.

= Measure Latency

= Measure Bandwidth

= Willingness to present





