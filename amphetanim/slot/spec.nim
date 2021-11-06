const
  unInitialised* = 0 # 0b0000
  resume* = 1 # 0b0001
  writer* = 1 shl 1 # 0b0010
  reader* = 1 shl 2 # 0b0100
  consumed* = writer or reader # 0b0110

template isWritten*(val: uint): bool =
  (val and writer) == writer

template isRead*(val: uint): bool =
  (val and reader) == reader

template isConsumed*(val: uint): bool =
  (val and consumed) == consumed

template isResumed*(val: uint): bool =
  (val and resume) == resume