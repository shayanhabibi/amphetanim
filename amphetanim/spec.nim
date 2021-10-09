import std/bitops

## Simple one way passage for continuations with N sides.

const
  AMPH_ALIGN*: int = 16
  PAD_SHIFT*: int = 4                       # Size of prefix that contains padding
  PAD_MASK*: int = (1 shl PAD_SHIFT) - 1    # Mask to acquire padding len
  SIZE_MASK*: int = high(int) xor PAD_MASK  # Mask to acquire length

type
  AmphFlag* {.size: sizeof(int).} = enum
    ## Flags that can be passed to Amphetanim.
    ## Flags are grouped for quick identification of
    ## whether multiple flags are set for the same group
    Spsc

    UnqThrTkns
  AmphFlags* = distinct uint

func `or`*(x: AmphFlags, y: uint): AmphFlags {.borrow.}
func `and`*(x: AmphFlags, y: uint): AmphFlags {.borrow.}
func `xor`*(x: AmphFlags, y: uint): AmphFlags {.borrow.}
func `==`*(x: AmphFlags, y: uint): bool {.borrow.}

converter toAmphFlags*(flags: set[AmphFlag]): AmphFlags =
  ## Used internally to convert a set into the bit set number
  when nimvm:
    for flag in items(flags):
      result = result or (1'u shl flag.ord)
  else:
    result = cast[AmphFlags](flags)

converter toSetAmph*(value: AmphFlags): set[AmphFlag] =
  ## Used internally to convert the bitset number into a set
  when nimvm:
    for flag in items(AmphFlag):
      if `and`(value, 1'u shl flag.ord) != 0:
        result.incl flag
  else:
    result = cast[set[AmphFlag]](value)


## Used on the static S gen param of amphetanim to acquire the len
template getLen*(val: int): int =
  (val shr PAD_SHIFT)

## Used on the static S gen param of amphetanim to acquire the padding len
template getPadLen*(val: int): int =
  (val and PAD_MASK)

## Used in setting the length in the composite S gen param int for amphetanim
template setLen*(comp: int, val: int): int =
  (val shl PAD_SHIFT) or (comp and PAD_MASK)

## Used in setting the padding length in the composite S gen param int
## for amphetanim
template setPad*(comp: int, val: int): int =
  (comp and SIZE_MASK) or (val and PAD_MASK)
