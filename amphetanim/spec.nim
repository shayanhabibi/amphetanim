## Simple one way passage for continuations with N sides.

import amphetanim/primitives/atomics


const
  SLOT_ALIGN*:  int = 16 # Must be 8/16/32/64
  IDX_MASK*:    uint = 1 shl SLOT_ALIGN - 1
  PTR_MASK*:    uint = high(uint) xor IDX_MASK

template alignType(): untyped =
  when SLOT_ALIGN == 8: int8
  elif SLOT_ALIGN == 16: int16
  elif SLOT_ALIGN == 32: int32
  elif SLOT_ALIGN == 64: int64 #TODO raise exception (impossibru)

template getIdx*(x: SomeInteger): untyped =
  cast[alignType()](x and IDX_MASK)

type
  SlotFlag* {.size: sizeof(int).} = enum
    sfNonBlocking
    sfBlocking
  SlotFlags* = distinct uint

    

  AmphFlag* {.size: sizeof(int).} = enum
    afNonBlocking
    afBlocking

    afPadding
    afNoPadding

    afSC
    afMC
    afSP
    afMP

  AmphFlags* = distinct uint
    
  AmphetanimKind* {.size: sizeof(int).} = enum
    akCubby

  AmphetanimKinds* = distinct uint
# fold borrows
when true:
  func `or`*(x: SlotFlags, y: uint): SlotFlags {.borrow.}
  func `and`*(x: SlotFlags, y: uint): SlotFlags {.borrow.}
  func `xor`*(x: SlotFlags, y: uint): SlotFlags {.borrow.}
  func `==`*(x: SlotFlags, y: uint): bool {.borrow.}
  func `or`*(x: AmphFlags, y: uint): AmphFlags {.borrow.}
  func `and`*(x: AmphFlags, y: uint): AmphFlags {.borrow.}
  func `xor`*(x: AmphFlags, y: uint): AmphFlags {.borrow.}
  func `==`*(x: AmphFlags, y: uint): bool {.borrow.}
  func `or`*(x: AmphetanimKinds, y: uint): AmphetanimKinds {.borrow.}
  func `and`*(x: AmphetanimKinds, y: uint): AmphetanimKinds {.borrow.}
  func `xor`*(x: AmphetanimKinds, y: uint): AmphetanimKinds {.borrow.}
  func `==`*(x: AmphetanimKinds, y: uint): bool {.borrow.}

# fold converters
when true:
  converter toSlotFlags*(flags: set[SlotFlag]): SlotFlags =
    when nimvm:
      for flag in items(flags):
        result = result or (1'u shl flag.ord)
    else:
      result = cast[SlotFlags](flags)  
  converter toSetSlotFlags*(value: SlotFlags): set[SlotFlag] =
    when nimvm:
      for flag in items(SlotFlag):
        if `and`(value, 1'u shl flag.ord) != 0:
          result.incl flag
    else:
      result = cast[set[SlotFlag]](value)
  converter toAmphFlags*(flags: set[AmphFlag]): AmphFlags =
    when nimvm:
      for flag in items(flags):
        result = result or (1'u shl flag.ord)
    else:
      result = cast[AmphFlags](flags)  
  converter toSetAmphFlags*(value: AmphFlags): set[AmphFlag] =
    when nimvm:
      for flag in items(AmphFlag):
        if `and`(value, 1'u shl flag.ord) != 0:
          result.incl flag
    else:
      result = cast[set[AmphFlag]](value)
  converter toAmphetanimKinds*(flags: set[AmphetanimKind]): AmphetanimKinds =
    when nimvm:
      for flag in items(flags):
        result = result or (1'u shl flag.ord)
    else:
      result = cast[AmphetanimKinds](flags)  
  converter toSetAmphetanimKind*(value: AmphetanimKinds): set[AmphetanimKind] =
    when nimvm:
      for flag in items(AmphetanimKind):
        if `and`(value, 1'u shl flag.ord) != 0:
          result.incl flag
    else:
      result = cast[set[AmphetanimKind]](value)

template aligned(): untyped {.dirty.} =
  cast[Atomic[alignType()]](location)

proc alignedFetchSub*[T: SomeInteger](location: var Atomic[T]; value: T;
                                    order: MemoryOrder): T =
  discard aligned.fetchSub(cast[alignType()](value), order)
  location.rawLoad()

proc alignedFetchAdd*[T: SomeInteger](location: var Atomic[T]; value: T;
                                    order: MemoryOrder): T =
  discard aligned.fetchAdd(cast[alignType()](value), order)
  location.rawLoad()

proc alignedLoad*[T](location: var Atomic[T]; order: MemoryOrder): T =
  discard aligned.load(order)
  location.rawLoad()

proc alignedStore*[T](location: var Atomic[T]; value: T; order: MemoryOrder) =
  discard aligned.store(value, order)
  location.rawLoad()