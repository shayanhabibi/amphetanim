import amphetanim/spec

type
  AmphToken*[T; F: static AmphFlags] = object
    tok*: int
    val*: ptr uint

proc getPushSlot*(tok: AmphToken): ptr uint {.inline.} =
  cast[ptr uint](cast[int](tok.val) +
                8 * (tok.tok mod 2))

proc getPullSlot*(tok: AmphToken): ptr uint {.inline.} =
  cast[ptr uint](cast[int](tok.val) +
                8 * ((tok.tok + 1) mod 2))

func isValid*(tok: AmphToken): bool =
  tok.tok >= 0

func isValid*(tok: (AmphToken, AmphToken)): bool =
  tok[0].tok >= 0

template isNil*(tok: AmphToken | (AmphToken, AmphToken)): bool =
  tok.isValid()