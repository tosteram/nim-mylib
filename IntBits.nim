#[
File  : IntBits.nim
        Set of bits (int size)
Date  : 2017-09-05
Author: T Teramoto
Licence: MIT Licence
]#

type IntBits* = distinct int

proc `and`* (bits:IntBits, bs:int): IntBits {.borrow.}
proc `or`* (bits:IntBits, bs:int): IntBits {.borrow.}
proc `==`* (bits:IntBits, bs:int): bool {.borrow.}

proc contains* (bits:IntBits, bs:int): bool {.inline.}=
  return (bits and bs) == bs

proc any* (bits:IntBits, bs:int): bool {.inline.}=
  (bits and bs)!=0

proc `+`* (bits:IntBits, bs:int): IntBits {.inline.}=
  result= bits or bs

proc `-`* (bits:IntBits, bs:int): IntBits {.inline.}=
  result= bits and (not bs)

proc assign* (bits:var IntBits, bs:int) {.inline.}=
  bits= bs.IntBits

# vim: ts=2 sw=2 et
