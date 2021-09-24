# The aim is to traverse a continuations tree and determine and act to invalidate
# cache lines by the action of a Atomic_Thread_Fence and subsequent atomic reads
# and writes. Doing so will ensure that the receiving thread has temporally valid
# memory.

# Plan: Initiate a heapqueue, iterate over every reference and object and add
#       every reference and object it points to to it. At the end we will have
#       an ordered list of pointers which we can then invalidate every cache line
#       for

import assume/typeit

