import amphetanim

type SomeRef = ref object

var amph = newAmphetanim[SomeRef](akCubby, flags = {afPadding})

var sr = new SomeRef

echo sizeof amph[]

discard amph.push sr
discard amph.pop()
discard amph.pop()
discard amph.push sr
discard amph.push sr