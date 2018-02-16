#[
File printutils.nim
Date 2017-03-16
]#

proc printf(formatstr: cstring) {.importc: "printf", varargs, header: "<stdio.h>".}

proc print(ss: varargs[string, `$`]) =
  stdout.write(ss)

proc println((ss: varargs[string, `$`]) =
  stdout.write(ss, "\n")

# vim: ts=2 sw=2 et
