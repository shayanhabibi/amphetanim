import amphetanim/spec
import amphetanim/slot
import amphetanim/primitives/atomics
import amphetanim/primitives/futex
import amphetanim/primitives/memalloc
# import amphetanim/primitives/cacheline
export spec

const cacheLineSize = 64

type
  # AmphSlot*[T; F: static SlotFlags] = ptr Slot[T, F]
  AmphSlot*[T; F: static SlotFlags] = object
    slotPtr: Atomic[uint]

  Amphetanim*[T; F: static AmphFlags] = ref object
    node: Atomic[uint]
    padding: array[cacheLineSize - 8, char]

proc initAmphSlot[T](flags: static set[SlotFlag] = {}): auto =
  #TODO error out if someone gives me some garbage as a type
  result = AmphSlot[T, toSlotFlags(flags)](
      slotPtr: allocAligned0(sizeof(Slot), SLOT_ALIGN)
    )

proc initAmphetanim*[T](flags: static set[AmphFlag] = {}): auto =
  result = Amphetanim[T, toAmphFlags flags]()

template getSlot(x: SomeInteger): untyped {.dirty.} =
  cast[ptr Slot[T, F]](x and PTR_MASK)[]

proc push[T; F](amph: AmphSlot[T, F], element: T): bool =
  when compileOption"threads":
    let val = amph.slotPtr.alignedFetchAdd(1'u, moAcquire)
    if val.getIdx == 0:
      val.getSlot.slot.store(unsafeAddr(element))
    else:
      discard
    
proc pull[T; F](amph: AmphSlot[T, F]): T =
  discard