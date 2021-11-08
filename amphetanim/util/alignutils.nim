import amphetanim/util_types/tagptr

proc median*(x: SomeInteger): uint =
  (1'u shl (x - 1))

proc medianDev*(val: uint, alignment: SomeInteger): int {.inline.} =
  val.int - median(alignment).int