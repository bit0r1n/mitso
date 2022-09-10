import strutils

proc debug*(args: varargs[string, `$`]): void =
  if defined(mDebug):
    echo args.join(" ")