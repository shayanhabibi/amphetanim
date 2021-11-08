type
  TagPtr* = uint

template getPtr*[T](x: TagPtr, alignment: int): ptr T =
  cast[ptr T](x and (high(uint) xor ((1'u shl alignment) - 1)))

template getTag*(x: TagPtr, alignment: int): uint =
  cast[uint](x and ((1'u shl alignment) - 1))