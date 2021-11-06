import amphetanim/primitives/atomics

type
  LinePad = object
    ## Basic object that will cover a whole cache line
    line: array[64, char]
  