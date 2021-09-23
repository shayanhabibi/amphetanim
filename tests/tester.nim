type
  RefHeader = object
    rc: int # the object header is now a single RC field.
  Cell = ptr RefHeader
  TNimTypeV2 {.compilerproc.} = object
    destructor: pointer
    size: int
    align: int
    name: cstring
    traceImpl: pointer
    typeInfoV1: pointer
    flags: int
  PNimTypeV2 = ptr TNimTypeV2
  CellTuple[T] = (T, PNimTypeV2)
  CellArray[T] = ptr UncheckedArray[CellTuple[T]]
  CellSeq[T] = object
    len, cap: int
    d: CellArray[T]
  TraceProc = proc (p, env: pointer) {.nimcall.}
  DisposeProc = proc (p: pointer) {.nimcall.}
  GcEnv = object
    traceStack: CellSeq[ptr pointer]

proc dynType[T](x: T): PNimTypeV2 {.magic: "GetTypeInfoV2", noSideEffect, locks: 0.}

proc `$`(x: PNimTypeV2): string = repr(x)
proc init[T](s: var CellSeq[T], cap: int = 1024) =
  s.len = 0
  s.cap = cap
  when compileOption("threads"):
    s.d = cast[CellArray[T]](allocShared(uint(s.cap * sizeof(CellTuple[T]))))
  else:
    s.d = cast[CellArray[T]](alloc(s.cap * sizeof(CellTuple[T])))

proc deinit[T](s: var CellSeq[T]) =
  if s.d != nil:
    when compileOption("threads"):
      deallocShared(s.d)
    else:
      dealloc(s.d)
    s.d = nil
  s.len = 0
  s.cap = 0

proc pop[T](s: var CellSeq[T]): (T, PNimTypeV2) =
  result = s.d[s.len-1]
  dec s.len

template head(p: pointer): Cell =
  cast[Cell](cast[int](p) -% sizeof(RefHeader))


import cps

const
  colGreen = 0b000
  colYellow = 0b001
  colRed = 0b010
  colorMask = 0b011
template color(c): untyped = c.rc and colorMask
template setColor(c, col) =
  c.rc = c.rc and not colorMask or col

type
  Obj = ref object
  MyObj = ref object
    omg: Obj
  C = ref object of Continuation
var x {.global.} = 5

var work: seq[C]

proc passme(c: C): C {.cpsMagic.} =
  work.add(c)
  return nil

proc doCont() {.cps:C.} =
  x = 3
  echo x
  x += 2
  passme()
  echo x

var c = whelp doCont()

c = trampoline c

# let q = head(cast[pointer](c))
# let p = cast[ptr pointer](q)
# if p != nil:
#   echo cast[ptr PNimTypeV2](p)[]
proc getTypeInfo*[T](x: T): pointer {.magic: "GetTypeInfo".}
type
  # This should be the same as ast.TTypeKind
  # many enum fields are not used at runtime
  TNimKind = enum
    tyNone,
    tyBool,
    tyChar,
    tyEmpty,
    tyArrayConstr,
    tyNil,
    tyUntyped,
    tyTyped,
    tyTypeDesc,
    tyGenericInvocation, # ``T[a, b]`` for types to invoke
    tyGenericBody,       # ``T[a, b, body]`` last parameter is the body
    tyGenericInst,       # ``T[a, b, realInstance]`` instantiated generic type
    tyGenericParam,      # ``a`` in the example
    tyDistinct,          # distinct type
    tyEnum,
    tyOrdinal,
    tyArray,
    tyObject,
    tyTuple,             # WARNING: The compiler uses tyTuple for pure objects!
    tySet,
    tyRange,
    tyPtr,
    tyRef,
    tyVar,
    tySequence,
    tyProc,
    tyPointer,
    tyOpenArray,
    tyString,
    tyCstring,
    tyForward,
    tyInt,
    tyInt8,
    tyInt16,
    tyInt32,
    tyInt64,
    tyFloat,
    tyFloat32,
    tyFloat64,
    tyFloat128,
    tyUInt,
    tyUInt8,
    tyUInt16,
    tyUInt32,
    tyUInt64,
    tyOwned, tyUnused1, tyUnused2,
    tyVarargsHidden,
    tyUncheckedArray,
    tyProxyHidden,
    tyBuiltInTypeClassHidden,
    tyUserTypeClassHidden,
    tyUserTypeClassInstHidden,
    tyCompositeTypeClassHidden,
    tyInferredHidden,
    tyAndHidden, tyOrHidden, tyNotHidden,
    tyAnythingHidden,
    tyStaticHidden,
    tyFromExprHidden,
    tyOptDeprecated,
    tyVoidHidden

  TNimNodeKind = enum nkNone, nkSlot, nkList, nkCase
  TNimNode {.compilerproc.} = object
    kind: TNimNodeKind
    offset: int
    typ: ptr TNimType
    name: cstring
    len: int
    sons: ptr array[0x7fff, ptr TNimNode]
# LINK
  TNimTypeFlag = enum
    ntfNoRefs = 0,     # type contains no tyRef, tySequence, tyString
    ntfAcyclic = 1,    # type cannot form a cycle
    ntfEnumHole = 2    # enum has holes and thus `$` for them needs the slow
                       # version
  TNimType {.compilerproc.} = object
    size*: int
    align*: int
    kind: TNimKind
    flags: set[TNimTypeFlag]
    base*: ptr TNimType
    node: ptr TNimNode # valid for tyRecord, tyObject, tyTuple, tyEnum
    finalizer*: pointer # the finalizer for the type
    marker*: proc (p: pointer, op: int) {.nimcall, tags: [], raises: [].} # marker proc for GC
    deepcopy: proc (p: pointer): pointer {.nimcall, tags: [], raises: [].}
    when defined(nimSeqsV2):
      typeInfoV2*: pointer
    when defined(nimTypeNames):
      name: cstring
      nextType: ptr TNimType
      instances: int # count the number of instances
      sizes: int # sizes of all instances in bytes
type
  PNimType* = ptr TNimType

# let f = cast[PNimType](getTypeInfo(c[]))
# echo f[].node[].len


echo dynType(c[])
echo dynType(work[0][])

var job = work.pop()
job = trampoline job

var obj = Obj()
var myobj = MyObj()
myobj.omg = obj

echo ""

let asd = 5

let f = cast[PNimType](getTypeInfo(myobj[]))
echo f[].node[].name
echo f[].flags
let asdf = cast[PNimType](getTypeInfo(asd))
# echo asdf[].node[].name
echo asdf[].flags

echo asd

echo ""
for i in myobj[].fields:
  echo repr(i)
echo dynType(myobj[])

echo obj.repr
# var markerGeneration: int
# proc cycler(s: Cell; desc: PNimTypeV2) =
#   let markerColor = if (markerGeneration and 1) == 0: colRed
#                     else: colYellow
#   atomicInc markerGeneration

#   var j: GcEnv
#   init j.traceStack

#   proc trace(p: pointer) =
#     if desc.

#   s.setColor(markerColor)
#   trace(s +! sizeof(RefHeader))


# cycler(head(cast[pointer](c)), dynType(c[]))