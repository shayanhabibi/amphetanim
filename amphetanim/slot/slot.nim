import amphetanim/slot/spec
import amphetanim/primitives/atomics

type
  Slot*[T] = object
    when compileOption"threads":
      val: Atomic[uint]
    else:
      rval: uint

proc rawRead*(slot: Slot, order: MemoryOrder = moRlx): uint {.inline.} =
  when compileOption"threads":
    slot.val.load(order)
  else:
    slot.rval

proc read*(slot: Slot, order: MemoryOrder = moSeqCon): uint {.inline.} =
  when compileOption"threads":
    slot.val.fetchAdd(reader, order)
  else:
    result = slot.rval
    slot.rval = slot.rval + reader

proc rawWrite*(slot: Slot, val: uint, order: MemoryOrder = moSeqCon): uint {.inline.} =
  when compileOption"threads":
    slot.val.fetchAdd(val, order)
  else:
    result = slot.rval
    slot.rval += val

proc write*(slot: Slot, val: uint, order: MemoryOrder = moSeqCon): uint {.inline.} =
  when compileOption"threads":
    slot.val.fetchAdd(val or writer, order)
  else:
    result = slot.rval
    slot.rval += val or writer

proc rawOverWrite*(slot: Slot, val: uint, order: MemoryOrder = moSeqCon) {.inline.} =
  when compileOption"threads":
    slot.val.store(val, order)
  else:
    slot.rval = val

proc overWrite*(slot: Slot, val: uint, order: MemoryOrder = moSeqCon) {.inline.} =
  when compileOption"threads":
    slot.val.store(val or writer, order)
  else:
    slot.rval = val or writer