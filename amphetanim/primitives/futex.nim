when defined(windows):
  import amphetanim/primitives/futex_windows
  export futex_windows
else:
  import amphetanim/primitives/futex_linux
  export futex_linux