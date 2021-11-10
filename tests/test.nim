import amphetanim
import os

type SomeRef = ref object

var amph = newAmphetanim[SomeRef](akCubby, flags = {afPadding})

var sr = new SomeRef

echo sizeof amph[]

proc doThings(delay: int) {.thread.} =
  sleep(delay * 1000)
  # discard amph.pop()
  echo "done"

proc pushThings(delay: int) {.thread.} =
  sleep(delay * 1000)
  var sr = new SomeRef
  # discard amph.push(sr)
  echo "done"

## 
## COMMENTING OUT EVERYTHING BELOW WILL ALLOW PROPER COMPILATION
## HOWEVER, WHEN CREATING THREADS; COMPILATION FAILS DUE TO CONVERTER
## OPERATION NOT BEING ABLE TO INSTANTIATE T?
## 

# var thread1: Thread[int]
# var thread2: Thread[int]
# var thread3: Thread[int]
# var thread4: Thread[int]
# createThread(thread1, doThings, 1)
# createThread(thread2, doThings, 2)
# createThread(thread3, pushThings, 3)
# createThread(thread4, pushThings, 4)
# joinThread thread1
# joinThread thread2
# joinThread thread3
# joinThread thread4

echo "finished"
echo typeof amph
