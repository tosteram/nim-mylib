#[
File	rc4.nim
Date	2016-04-27 Go
		2017-02-03 for Nim
]#

import md5  #import toMD5, getMD5
from strutils import toHex, parseHexInt, toLowerAscii

const S_SIZE = 256
type Rc4 = array[S_SIZE, uint8]

proc initRC4* (pwd: string) : Rc4 =
  let key= pwd.toMD5      #array[16, uint8]
  let key_size = len(key) # = 16
  for i in 0..<S_SIZE:
    result[i] = i.uint8

  var j=0
  for i in 0..<S_SIZE:
    let k = key[i mod key_size]
    j = (j+int(result[i])+int(k)) and 0xff
    swap(result[i], result[j])

proc crypto* (data, key: string): string=
  var s= initRC4(key)

  result= newString(data.len)
  var j=0
  for i in 0..<data.len:
    let i2 = (i+1) and 0xff
    j = (j+int(s[i2])) and 0xff
    swap s[i2], s[j]
    result[i] = chr( s[int(s[i2]+s[j]) and 0xff] xor data[i].ord )

proc encrypt_to_hex* (data, key: string): string=
  result= ""
  for c in crypto(data, key):
    result &= c.ord.toHex(2).toLowerAscii

proc decrypt_from_hex* (hex, key: string): string =
  let size= hex.len div 2
  var cdata = newString(size)
  for i in 0..<size:
    let i2= 2*i
    cdata[i]= chr(hex.substr(i2, i2+1).parseHexInt)
  return crypto(cdata, key)

when isMainModule:
  let
    pwd= "pasvorto123"
    s= "Text: I have an apple, which is very sweet."
    ct= encrypt_to_hex(s, pwd)
    pt= decrypt_from_hex(ct, pwd)
  echo ct
  echo pt

# vim: ts=2 sw=2 et
