type
  TagPtr* = uint

template getPtr*[T](x: TagPtr, ret: typedesc[T], alignment: SomeInteger): ptr T =
  cast[ptr T](x and (high(uint) xor ((1'u shl alignment) - 1)))

template getTag*(x: TagPtr, alignment: SomeInteger): uint =
  cast[uint](x and ((1'u shl alignment) - 1))