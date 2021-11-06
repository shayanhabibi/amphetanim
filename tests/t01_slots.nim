import amphetanim/slot/slot
import amphetanim/slot/spec
block read:
  var slot = Slot()
  doassert slot.rawRead() == 0
  doassert slot.read() == 0
  doassert slot.rawRead() == reader

block write:
  var slot = Slot()
  doassert slot.write(16) == 0
  doassert slot.rawRead() == 18
  # doassert slot.rawWrite(10) == 0
  # doassert slot.rawWrite(0) == (20 or writer)