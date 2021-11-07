import amphetanim

type SomeRef = ref object

var amph = newAmphetanim[SomeRef](akCubby, flags = {afPadding})

echo sizeof amph[]