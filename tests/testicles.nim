import std/isolation
import pkg/cps
import assume/typeit


type
  C = ref object of Continuation

proc doSomeShit() {.cps:C.} =
  echo "dosomeshit"

var c = whelp doSomeShit()

for x in fields(c[]):
  echo repr(x)
typeIt c, {}:
  echo repr(it)