import amphetanim/primitives/atomics
import amphetanim/slot/spec

type
  Slot* = object
    when compileOption"threads":
      val: Atomic[uint]
    else:
      rval: uint

proc rawRead*(slot: var Slot, order: MemoryOrder = moRlx): uint {.inline.} =
  ## Performs a raw read of the slot without writing a reader flag (like a peek)
  when compileOption"threads":
    slot.val.load(order)
  else:
    slot.rval

proc read*(slot: var Slot, order: MemoryOrder = moSeqCon): uint {.inline.} =
  ## Reads the slot while writing the flag to the slot
  when compileOption"threads":
    slot.val.fetchAdd(reader, order)
  else:
    result = slot.rval
    slot.rval = slot.rval + reader

proc rawWrite*(slot: var Slot, val: uint, order: MemoryOrder = moSeqCon): uint {.inline.} =
  ## Performs a raw write of the slot without the writer flag and returns the
  ## old value (performs a fetchAdd)
  when compileOption"threads":
    slot.val.fetchAdd(val, order)
  else:
    result = slot.rval
    slot.rval += val

proc write*(slot: var Slot, val: uint, order: MemoryOrder = moSeqCon): uint {.inline.} =
  ## Performs a write on the slot with the writer flag and returns
  ## the old value (performs a fetchAdd)
  when compileOption"threads":
    slot.val.fetchAdd(val or writer, order)
  else:
    result = slot.rval
    slot.rval += val or writer

proc rawOverWrite*(slot: var Slot, val: uint, order: MemoryOrder = moSeqCon) {.inline.} =
  ## Performs a raw overwrite of the slot with `val`, without the writer flag
  when compileOption"threads":
    slot.val.store(val, order)
  else:
    slot.rval = val

proc overWrite*(slot: var Slot, val: uint, order: MemoryOrder = moSeqCon) {.inline.} =
  ## Overwrites the slot with `val` and the writer flag
  when compileOption"threads":
    slot.val.store(val or writer, order)
  else:
    slot.rval = val or writer