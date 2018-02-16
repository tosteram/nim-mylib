#[
File	getopts.nim
Date	2013-02-04 (v1)chicken
		2013-11-23; 12-05 newlisp
		2013-12-09 (v2)chicken
		2015-05-25 for --option
		2016-03-31 bug fix. Ex. -a=C:\dir -> "a=C", "\\dir"
;Ex. (get-opts "ab:c" '("xxx" "-a" "-b=5"))
;	--> as=("xxx") opts=Rec (("a" true) ("b" "5"))
;	(alternatives of -b=5 : "-b:5" "-b5" or "-b" "5")
;	--long-name, --abc=123, --abc:123
;
;	2015-10-04 for r6rs ypsilon
;	2016-04-29 for Go
;	2016-05-17 interface Opts - Exists,True,Int,Str,Set,Map

;	2016-09-27 for Python3
;	2016-11-13 for Racket
	2017-01-29	for Nim
]#

from strutils import contains, parseInt
from re import re, match
import tables

var showUndef = false

proc setShowUndef* () =
  showUndef= true

const True="true"
let with_arg = re"^--?(.+?)[:=](.+)$"
let long_opt = re"^--(.+)"
let simple_opt= re"^-(.+)"

proc isTrue* (opts: TableRef[string,string], key:string) : bool =
  return opts.hasKey(key) and opts[key]==True

proc toInt* (opts: TableRef[string,string], key:string) : int =
  return parseInt(opts.getOrDefault(key))

# optdef str, argvec vector -> (list . Rec)
# [return] 2 values args and options : args=list of strings, options=Rec
proc getopts* (optdef: string, argvec: openArray[string]) :
        tuple[args: seq[string], opts: TableRef[string, string]] =

  const none= ""
  var args = newSeq[string]()
  var opts = newTable[string, string]()
  var prevopt= none
  var m= [none, none]

  for arg in argvec:
    if match(arg, with_arg, m):
      opts[m[0]]= m[1]
      prevopt= none
    elif match(arg, long_opt, m):
      opts[m[0]]= True
      prevopt= none
    elif match(arg, simple_opt, m):
      opts[m[0]]= True
      prevopt= if (m[0].len == 1) and optdef.contains(m[0] & ":"):
                  m[0]
               else:
                  none
    elif prevopt != none:
      opts[prevopt]= arg
      prevopt= none
    else:
      args.add(arg)

  if showUndef:
    for name in keys(opts):
      if name.len==1 and name notin optdef:
        echo "-", name, ": unknown option"

  return (args, opts)

# Test
when isMainModule:
  from os import commandLineParams
  let (args, opts) = getopts("ab:", commandLineParams())

  echo "Args:"
  for a in args:
    write(stdout, a & " ")
  write(stdout, "\n")

  echo "Opts:"
  for key, val in opts.pairs:
    echo key & "=" & val


# vim: ts=4 et

