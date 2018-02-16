#[
File	inifile.nim
Date	2016-05-21 (Go)
		2017-01-29 for Nim
]#

import strutils, tables

#import utils
#export utils.getOr, utils.isTrue, utils.toInt

type
  Ini* = TableRef[string, string]

proc read* (file: string) : Ini =
  result = newTable[string, string]()

  var lastname: string
  for ln in file.lines:
    if ln.len==0 or ln[0]=='#' or ln[0]==';':
      # empty line or comment line
      continue
    elif ln[0]==' ' and lastname!=nil:
      let cont= if result[lastname].len==0: ln.strip
                else: "\l" & ln.strip
      result[lastname] &= cont
    else:
      let pair = ln.split('=', 1)
      let name = pair[0].strip()
      let val = if len(pair)==2:
                  pair[1].strip()
                else:
                  ""
      result[name]= val
      lastname= name

proc save* (ini:Ini, file:string) =
  let f= open(file, fmWrite)
  for name,value in ini:
    f.write(name, "=")
    if value.contains('\l'):
      f.writeLine("\n ", value.replace("\l","\n "))
    else:
      f.writeLine(value)
  #
  f.close

#[
NG. import mylib/utils

proc toInt* (ini: Ini, key:string) : int =
  try:
    return parseInt(ini[key])
  except ValueError:
    return 0

proc isTrue* (ini: Ini, key: string) : bool =
  return ini[key]=="true"
]#

# test
when isMainModule:
  from os import commandLineParams
  let args= commandLineParams()
  if len(args)==0:
    echo "Usage: inifile file"
    quit(QuitFailure)

  let ini= read(args[0])

  for key, val in ini.pairs:
    echo key, "=", val

# vim: ts=2 sw=2 et
