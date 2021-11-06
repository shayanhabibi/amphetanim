const
  unInitialised* = uint(0) # 0b0000
  resume* = uint(1) # 0b0001
  writer* = uint(1 shl 1) # 0b0010
  reader* = uint(1 shl 2) # 0b0100
  consumed* = writer or reader # 0b0110

template isWritten*(val: uint): bool =
  ## Checks if value has writer flag
  (val and writer) == writer

template isRead*(val: uint): bool =
  ## Checks if value has reader flag
  (val and reader) == reader

template isConsumed*(val: uint): bool =
  ## Checks if value has been consumed (has both reader and writer flags)
  (val and consumed) == consumed

template isResumed*(val: uint): bool =
  ## Check if the value has a resume flag (usually indicates simultaneous
  ## actions on the slot/value)
  (val and resume) == resume