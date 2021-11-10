import amphetanim/primitives/atomics
import amphetanim/slot/spec
export isResumed, isRead, isConsumed, isWritten, readPtr, readFlags

type
  Slot* = object
    when compileOption"threads":
      val: Atomic[uint]
    else:
      rval: uint

proc rawLoad*(slot: var Slot): uint {.inline.} =
  ## directly returns the value of the slot without performing atomic operations.
  ## This should only be performed if an atomic operation has already been
  ## performed elsewhere on the cache line (in which case the whole line would
  ## be correct at that operations time)
  when compileOption"threads":
    slot.val.rawLoad()
  else:
    slot.rval

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

proc swap*(slot: var Slot, expected: uint, val: uint,
          success, failure: MemoryOrder): bool {.inline.} =
  ## Swaps the value in the slot or returns false
  when compileOption"threads":
    slot.val.compareExchange(cast[var uint](unsafeAddr(expected)), val, success, failure)
  else:
    case slot.rval
    of expected: slot.rval = val; true
    else: false

proc swap*(slot: var Slot, expected: uint, val: uint,
          order: MemoryOrder = moSeqCon): bool {.inline.} =
  ## Swaps the value in the slot or returns false
  slot.swap(expected, val, order, order)

proc weakSwap*(slot: var Slot, expected: uint, val: uint,
              success, failure: MemoryOrder): bool {.inline.} =
  when compileOption"threads":
    slot.val.compareExchangeWeak(cast[var uint](unsafeAddr(expected)), val, success, failure)
  else:
    case slot.rval
    of expected: slot.rval = val; true
    else: false

proc weakSwap*(slot: var Slot, expected: uint, val: uint,
              order: MemoryOrder = moSeqCon): bool {.inline.} =
  slot.swap(expected, val, order, order)

proc clear*(slot: var Slot, order: MemoryOrder = moSeqCon) {.inline.} =
  ## Clears the slot
  when compileOption"threads":
    slot.val.store(0'u, order)
  else:
    slot.rval = 0'u

proc clearFlags*(slot: var Slot, order: MemoryOrder = moSeqCon): uint {.inline.} =
  ## Clears the flags of the slot (the first 3 bits)
  when compileOption"threads":
    slot.val.fetchAnd(ptrMask, order)
  else:
    result = slot.rval
    slot.rval = slot.rval and ptrMask

proc reclaim*(slot: var Slot, clear: static bool = false): bool {.inline.} =
  ## Use this in cases where the slot should reasonably have already been
  ## consumed according to sequential atomic actions. If it hasn't, then
  ## a resume flag is set giving the lagging thread more time to catch up.
  ## 
  ## If the clear flag is set, then the slot will be cleared on success
  if not slot.rawRead(moAcq).isConsumed:
    var prev = slot.rawWrite(resume, moRlx) # extra steps to lag the process further
    if not prev.isConsumed:
      result = false
  else:
    when clear:
      slot.clear()
    result = true

proc store*(slot: var Slot, val: uint, order: MemoryOrder = moSeqCon) {.inline,
                                                  deprecated: "Use overWrite".} =
  overWrite(slot, val, order)
proc load*(slot: var Slot, order: MemoryOrder = moSeqCon): uint {.inline,
                                                  deprecated: "use rawRead".} =
  rawRead(slot, order)