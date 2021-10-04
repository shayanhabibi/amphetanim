# The aim is to traverse a continuations tree and determine and act to invalidate
# cache lines by the action of a Atomic_Thread_Fence and subsequent atomic reads
# and writes. Doing so will ensure that the receiving thread has temporally valid
# memory.

# Plan: Initiate a heapqueue, iterate over every reference and object and add
#       every reference and object it points to to it. At the end we will have
#       an ordered list of pointers which we can then invalidate every cache line
#       for

import std/macros

import assume/spec

type
  ItOption* = enum
    itRefsOnly = "ignore any object that isnt ref boi"

type
  MyObj = ref object of RootObj
    x: string
  Obj = ref object of MyObj
    y: string
  Cell = object
    addrs: int
    size: int
    align: int
  CellHeap = seq[Cell]
  
var obj: Obj = Obj(x: "hi", y: "bye")

echo sizeof(obj.y)
echo repr cast[int](obj)

for key,field in obj[].fieldPairs:
  echo ""
  echo key
  echo cast[int](field.unsafeAddr)

echo sizeof(obj[])

import amphetanim/spec as aspec

echo cast[int](getTypeInfo(obj))
echo cast[int](getTypeInfo(obj[]))
var t = getAmpheType obj[]

echo t

template getAddrSizeAlign(node: ref): (int, int, int) = # Can use lower byte ints?
  var addrs = cast[int](node)
  var t = getAmpheType node
  
  (addrs, t.size, t.align)

template getAddrSizeAlign(node: var object): (int, int, int) =
  var addrs = cast[int](node.addr)
  var t = getAmpheType node

  (addrs, t.size, t.align)