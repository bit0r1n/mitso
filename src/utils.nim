import strutils

proc debug*(args: varargs[string, `$`]): void =
  if defined(debug):
    echo args.join(" ")