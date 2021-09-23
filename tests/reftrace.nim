#
#
#            Nim's Runtime Library
#        (c) Copyright 2019 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

# Cell seqs for cyclebreaker and cyclicrefs_v2.
when defined(gcOrc):
  const
    rcIncrement = 0b10000 # so that lowest 4 bits are not touched
    rcMask = 0b1111
    rcShift = 4      # shift by rcShift to get the reference counter

else:
  const
    rcIncrement = 0b1000 # so that lowest 3 bits are not touched
    rcMask = 0b111
    rcShift = 3      # shift by rcShift to get the reference counter

type
  RefHeader = object
    rc: int # the object header is now a single RC field.
            # we could remove it in non-debug builds for the 'owned ref'
            # design but this seems unwise.
    when defined(gcOrc):
      rootIdx: int # thanks to this we can delete potential cycle roots
                   # in O(1) without doubly linked lists
    when defined(nimArcDebug) or defined(nimArcIds):
      refId: int

  Cell = ptr RefHeader

template head(p: pointer): Cell =
  cast[Cell](cast[int](p) -% sizeof(RefHeader))
type
  # DestructorProc = proc (p: pointer) {.nimcall, benign, raises: [].}
  TNimTypeV2 {.compilerproc.} = object
    destructor: pointer
    size: int
    align: int
    name: cstring
    traceImpl: pointer
    typeInfoV1: pointer # for backwards compat, usually nil
    flags: int
  PNimTypeV2 = ptr TNimTypeV2
type
  CellTuple[T] = (T, PNimTypeV2)
  CellArray[T] = ptr UncheckedArray[CellTuple[T]]
  CellSeq[T] = object
    len, cap: int
    d: CellArray[T]

proc add[T](s: var CellSeq[T], c: T; t: PNimTypeV2) {.inline.} =
  if s.len >= s.cap:
    s.cap = s.cap * 3 div 2
    when compileOption("threads"):
      var d = cast[CellArray[T]](allocShared(uint(s.cap * sizeof(CellTuple[T]))))
    else:
      var d = cast[CellArray[T]](alloc(s.cap * sizeof(CellTuple[T])))
    copyMem(d, s.d, s.len * sizeof(CellTuple[T]))
    when compileOption("threads"):
      deallocShared(s.d)
    else:
      dealloc(s.d)
    s.d = d
    # XXX: realloc?
  s.d[s.len] = (c, t)
  inc(s.len)

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

const
  colGreen = 0b000
  colYellow = 0b001
  colRed = 0b010
  colorMask = 0b011

type
  TraceProc = proc (p, env: pointer) {.nimcall.}
  DisposeProc = proc (p: pointer) {.nimcall.}

type
  GcEnv = object
    traceStack: CellSeq[ptr pointer]

proc trace(p: pointer; desc: PNimTypeV2; j: var GcEnv) {.inline.} =
  when false:
    cprintf("[Trace] desc: %p %p\n", desc, p)
    cprintf("[Trace] trace: %p\n", desc.traceImpl)
  if desc.traceImpl != nil:
    cast[TraceProc](desc.traceImpl)(p, addr(j))

proc nimTraceRef(q: pointer; desc: PNimTypeV2; env: pointer) =
  let p = cast[ptr pointer](q)
  # when traceCollector:
    # cprintf("[Trace] raw: %p\n", p)
    # cprintf("[Trace] deref: %p\n", p[])
  if p[] != nil:
    var j = cast[ptr GcEnv](env)
    j.traceStack.add(p, desc)

proc nimTraceRefDyn(q: pointer; env: pointer) =
  let p = cast[ptr pointer](q)
  # when traceCollector:
  #   cprintf("[TraceDyn] raw: %p\n", p)
  #   cprintf("[TraceDyn] deref: %p\n", p[])
  if p[] != nil:
    var j = cast[ptr GcEnv](env)
    j.traceStack.add(p, cast[ptr PNimTypeV2](p[])[])

var markerGeneration: int

proc breakCycles(s: Cell; desc: PNimTypeV2) =
  let markerColor = if (markerGeneration and 1) == 0: colRed
                    else: colYellow
  atomicInc markerGeneration
  # when traceCollector:
  #   cprintf("[BreakCycles] starting: %p %s RC %ld trace proc %p\n",
  #     s, desc.name, s.rc shr rcShift, desc.traceImpl)

  var j: GcEnv
  init j.traceStack
  s.setColor markerColor
  trace(s +! sizeof(RefHeader), desc, j)

  while j.traceStack.len > 0:
    let (u, desc) = j.traceStack.pop()
    let p = u[]
    let t = head(p)
    if t.color != markerColor:
      t.setColor markerColor
      trace(p, desc, j)
      when traceCollector:
        cprintf("[BreakCycles] followed: %p RC %ld\n", t, t.rc shr rcShift)
    else:
      if (t.rc shr rcShift) > 0:
        dec t.rc, rcIncrement
        # mark as a link that the produced destructor does not have to follow:
        u[] = nil
        when traceCollector:
          cprintf("[BreakCycles] niled out: %p RC %ld\n", t, t.rc shr rcShift)
      else:
        # anyhow as a link that the produced destructor does not have to follow:
        u[] = nil
        cprintf("[Bug] %p %s RC %ld\n", t, desc.name, t.rc shr rcShift)
  deinit j.traceStack

proc thinout*[T](x: ref T) {.inline.} =
  ## turn the subgraph starting with `x` into its spanning tree by
  ## `nil`'ing out any pointers that would harm the spanning tree
  ## structure. Any back pointers that introduced cycles
  ## and thus would keep the graph from being freed are `nil`'ed.
  ## This is a form of cycle collection that works well with Nim's ARC
  ## and its associated cost model.
  proc getDynamicTypeInfo[T](x: T): PNimTypeV2 {.magic: "GetTypeInfoV2", noSideEffect, locks: 0.}

  breakCycles(head(cast[pointer](x)), getDynamicTypeInfo(x[]))

proc thinout*[T: proc](x: T) {.inline.} =
  proc rawEnv[T: proc](x: T): pointer {.noSideEffect, inline.} =
    {.emit: """
    `result` = `x`.ClE_0;
    """.}

  let p = rawEnv(x)
  breakCycles(head(p), cast[ptr PNimTypeV2](p)[])

proc nimDecRefIsLastCyclicDyn(p: pointer): bool {.compilerRtl, inl.} =
  if p != nil:
    var cell = head(p)
    if (cell.rc and not rcMask) == 0:
      result = true
      #cprintf("[DESTROY] %p\n", p)
    else:
      dec cell.rc, rcIncrement
      # According to Lins it's correct to do nothing else here.
      #cprintf("[DeCREF] %p\n", p)

proc nimDecRefIsLastCyclicStatic(p: pointer; desc: PNimTypeV2): bool {.compilerRtl, inl.} =
  if p != nil:
    var cell = head(p)
    if (cell.rc and not rcMask) == 0:
      result = true
      #cprintf("[DESTROY] %p %s\n", p, desc.name)
    else:
      dec cell.rc, rcIncrement
      #cprintf("[DeCREF] %p %s %ld\n", p, desc.name, cell.rc)
