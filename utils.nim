#[
File utils.nim
Date 2017-03-13
]#

import tables
from strutils import parseInt

proc getOr* [A,B](tbl:TableRef[A,B] or Table[A,B], key:A, deflt:B): B =
  try:
    tbl[key]
  except KeyError:
    deflt

proc isTrue* [A](tbl: TableRef[A,string], key:A): bool =
  tbl.getOr(key,"")=="true"

proc toInt* [A](tbl: TableRef[A,string], key:A): int =
  try:
    return tbl.getOr(key,"0").parseInt
  except ValueError:
    return 0

when isMainModule:
  let tbl= {"xyz":"OK", "numb":"345", "ok":"true"}.newTable
  echo "tbl[none]=", tbl.getOr("none", "Nothing")
  echo "ok=", tbl.isTrue("ok")
  echo "numb+1=", tbl.toInt("numb")+1

# vim: ts=2 sw=2 et
