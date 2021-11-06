import amphetanim

type SomeRef = ref object

var amph = newAmphetanim[SomeRef](flags = {afNoPadding})

echo sizeof(amph[])