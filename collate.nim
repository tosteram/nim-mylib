#[
File  collate.nim
      Collation for Sqlite3
Date  2018.2.12
Ref.
  https://www.sqlite.org/c3ref/create_collation.html
  https://www.sqlite.org/c3ref/collation_needed.html
]#

#import strutils

when hostOS=="windows":
  const lib_file= "sqlite3_32.dll"
else:
  const lib_file= "sqlite3.so"

{.push, cdecl, dynlib:lib_file.}

# defined in sqlite3.h
const SQLITE_UTF8* = 1
const SQLITE_UTF16* = 4 # use native byte order

proc sqlite3_create_collation*(db:pointer, name:cstring, txtrep:int,
  arg:pointer, callback:pointer): cint {. importc.}

proc sqlite3_collation_needed*(db:pointer, arg:pointer, f_collation:pointer): cint
  {. importc .}

{.pop.}

#- helpers -
# Callback from 'create collation', UTF-8 Esperanto
# return -,0,+
proc esp_compare*(arg:pointer, n1:cint, s1:cstring, n2:cint, s2:cstring): int
  {. exportc .} =
  type
    CArray= array[2, char]
    Conv= tuple [fst:char, snd:CArray]

  const espC4= [
          ('\x88', ['c','\x7f']),
          ('\x9c', ['g','\x7f']),
          ('\xa4', ['h','\x7f']),
          ('\xb4', ['j','\x7f']),
          ('\x89', ['c','\x7f']),
          ('\x9d', ['g','\x7f']),
          ('\xa5', ['h','\x7f']),
          ('\xb5', ['j','\x7f'])]
  const espC5= [
          ('\x9c', ['s','\x7f']),
          ('\xac', ['u','\x7f']),
          ('\x9d', ['s','\x7f']),
          ('\xad', ['u','\x7f'])]

  proc find(arr:openArray[Conv] , c:char): int =
    for i,e in arr:
      if e[0]==c:
        return i
    return -1

  # cstring to string(to lower ascii, esp.chars to ?-notation)
  proc toString(cs:cstring, n:int): string =
    result= newString(n)  # uninitialized string
    var i= 0
    while i<n:
      var c= cs[i]
      if c>='A' and c<='Z':  # Ascii A..Z
        result[i]= chr(c.ord-'A'.ord+'a'.ord)
      elif c.ord==0xc4 and (let f= find(espC4, cs[i+1]); f>=0):
        let arr= espC4[f][1]
        result[i]= arr[0]
        inc i
        result[i]= arr[1]
      elif c.ord==0xc5 and (let f= find(espC5, cs[i+1]); f>=0):
        let arr= espC5[f][1]
        result[i]= arr[0]
        inc i
        result[i]= arr[1]
      else:
        result[i]= c
      inc i
    # end while

  # BEGIN
  let t1= toString(s1, n1)
  let t2= toString(s2, n2)
  return cmp(t1, t2)

proc collation_utf8_esperanto_ci*(db:pointer): int =
  sqlite3_create_collation(db, "utf8_esperanto_ci", SQLITE_UTF8, nil, esp_compare)

# Callback from 'collation needed', use the collation for default
proc def_collation*(arg:pointer, db:pointer, txtrep:int, name:string): int
  {. exportc .} =
  # TODO
  return 0

when isMainModule:
  import strutils, os
  import sqlite3

  if paramCount()<2:
    echo "./collate vortaroj.db word (ex. %abc%)"
    quit()

  let dicts= paramStr(1)
  let word= paramStr(2)
  let db= sqlite3.openDb(dicts)
  let ret= collation_utf8_esperanto_ci(db)
  echo "create collation ret=", $ret

  let sqlstr= "select id,word from word where word like ? collate utf8_esperanto_ci order by word collate utf8_esperanto_ci"
  for row in db.fetch_rows(sqlstr, word.dbText):
    echo "$#, $#" % [$row[0].intVal, row[1].textVal]

  db.closeDb

# vim: ts=2 sw=2 et
