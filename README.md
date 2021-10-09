# Amphetanim

Drugs are bad

## This are how use

```nim
import amphetanim

type SomeObj = ref object

let amph = newAmphetanim[SomeObj]()
let (slot1, slot2) = amph.getSlots()
# You can now push onto slot1 and pull it from slot2; similarly
# you can push onto slot2 and pull it from slot1.
```