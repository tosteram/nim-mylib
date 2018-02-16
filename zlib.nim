#[
;File	zlib.scm
;Date	2015-10-15 (Ypsilon)
;		2016-11-23 for Racket
		2017-02-19 for Nim

Re: http://www.zlib.net/zlib_how.html
]#

# export deflate, inflate, deflate_bytes, inflates_bytes

import streams

# const, enum
const
  CHUNK= 64*1024  #=65536 default

  # comprssion levels
# Z_NO_COMPRESSION= 0
# Z_BEST_SPEED= 1
# Z_BEST_COMPRESSION= 9
  Z_DEFAULT_COMPRESSION= -1

  Z_NO_FLUSH= 0
  Z_FINISH  = 4

  #Z_VERSION_ERROR= -6
  #Z_BUF_ERROR = -5
  Z_MEM_ERROR = -4
  Z_DATA_ERROR= -3
  #Z_STREAM_ERROR= -2
  #Z_ERRNO = -1
  Z_OK= 0
  Z_STREAM_END= 1
  Z_NEED_DICT = 2


# z_stream
type
  Zstream = object # {.packed.}
    next_in: pointer  # position to input from
    avail_in: cuint   # the number of bytes in next_in
    total_in: culong
    next_out: pointer # position to output to
    avail_out: cuint  # the number of free bytes in next_out
    total_out: culong

    msg: pointer    # const char* ?
    state: pointer  # internal, not visible

    zalloc: pointer
    zfree: pointer
    opaque: pointer # private data

    data_type: cint
    adler: culong
    reserved: culong

  ZstreamPtr= ptr Zstream


# zlib
const
#  ZLIB_VERSION= "1.2.3"
  #lib_file= "C:\\Program Files\\GnuWin32\\bin\\zlib1.dll"
# ZLIB_VERSION= "1.2.7"
# lib_file= "C:\\Home\\progs\\C\\SmallProj\\zlib\\zlib1.dll"
#  lib_file= "zlib1.dll"

# MacOS, Linux
  lib_file= "libz.1.dylib"

{. push, cdecl, dynlib:lib_file .}
proc zlibVersion() : cstring {. importc .}
proc deflateInit(strm:ZstreamPtr, level:cint, version:cstring, stream_size:cint) :
      cint {. importc:"deflateInit_" .}
proc deflateEnd(strm:ZstreamPtr): cint {. importc .}
proc deflate_c(strm:ZstreamPtr, flush:cint): cint {. importc:"deflate" .}

proc inflateInit(strm: ZstreamPtr, version:cstring, stream_size:cint) :
      cint {. importc:"inflateInit_" .}
proc inflateEnd (strm: ZstreamPtr): cint {. importc .}
proc inflate_c(strm:ptr Zstream, flush:cint): cint {. importc:"inflate" .}
{. pop .}

#let ZLIB_VERSION= $zlibVersion()


# [in] in,out: bynary ports
# [return] #t: OK, #f:failed
proc deflate* (inp, outp: Stream, level=Z_DEFAULT_COMPRESSION, chunk=CHUNK) : bool =

  proc init(level, chunk: int) : (ref Zstream, string, string) =
    let
      zstreamRef= new Zstream
      zstream= addr zstreamRef[]
      ret= deflateInit(zstream, level.cint, zlibVersion(), sizeof(Zstream).cint)
    if ret==Z_OK:
      return (zstreamRef, newString(chunk), newString(chunk))
    else:
      return (nil, nil, nil)  # failed to initialize

  proc flush(zstreamRef: ref Zstream, out_buf:var string, chunk: int, flush_ctrl:int) =
    let zstream= addr zstreamRef[]
    let out_buf_ptr= addr out_buf[0]
    zstream.avail_out= chunk.cuint
    zstream.next_out= out_buf_ptr
    discard deflate_c(zstream, flush_ctrl.cint)
            #ret:Z_OK, Z_STREAM_END, Z_STREAM_ERROR, Z_BUF_ERROR
    #
    let out_len= chunk - zstream.avail_out.int
    outp.writeData(out_buf_ptr, out_len)
    if zstream.avail_out==0:
    #if zstream.avail_in > 0.cuint:
      flush(zstreamRef, out_buf, chunk, flush_ctrl) #some might not be processed

  # Begin
  var (zstreamRef, in_buf, out_buf)= init(level, chunk)
  if not zstreamRef.isNil:
    while not inp.atEnd: #not EOF
      # read into the Zstream.next_in buffer, whose length is Zstream.avail_in
      let in_buf_ptr= addr in_buf[0]
      zstreamRef.next_in= in_buf_ptr
      zstreamRef.avail_in= inp.readData(in_buf_ptr, chunk).cuint
      flush(zstreamRef, out_buf, chunk, Z_NO_FLUSH)
    zstreamRef.avail_in= 0
    flush(zstreamRef, out_buf, chunk, Z_FINISH)
    discard deflateEnd(addr zstreamRef[])
    return true
  else:
    return false

proc inflate* (inp, outp: Stream, chunk=CHUNK) : bool =

  proc init(chunk: int) : (ref Zstream, string, string) =
    let
      zstreamRef= new Zstream
      zstream= addr zstreamRef[]
      ret= inflateInit(zstream, zlibVersion(), sizeof(Zstream).cint)
    if ret==Z_OK:
      return (zstreamRef, newString(chunk), newString(chunk))
    else:
      return (nil, nil, nil)  # failed to initialize

  proc flush(zstreamRef: ref Zstream, out_buf:var string, chunk: int) : int =
    let zstream= addr zstreamRef[]
    let out_buf_ptr= addr out_buf[0]
    zstreamRef.avail_out= chunk.cuint
    zstreamRef.next_out= out_buf_ptr
    let ret= inflate_c(zstream, Z_NO_FLUSH)
    if ret in [Z_NEED_DICT, Z_DATA_ERROR, Z_MEM_ERROR]:
      # error
      return ret
    else:
      # ok
      let out_len= chunk - zstreamRef.avail_out.int
      outp.writeData(out_buf_ptr, out_len)
      if zstream.avail_out==0:
        discard flush(zstreamRef, out_buf, chunk)
      return ret  #= Z_OK(?) or Z_STREAM_END

  # Begin
  var (zstreamRef, in_buf, out_buf)= init(chunk)
  if not zstreamRef.isNil:
    let zstream= addr zstreamRef[]
    while not inp.atEnd:  #not EOF
      let in_buf_ptr= addr in_buf[0]
      zstreamRef.next_in= in_buf_ptr
      zstreamRef.avail_in= inp.readData(in_buf_ptr, chunk).cuint
      let ret= flush(zstreamRef, out_buf, chunk)
      case ret
        of Z_STREAM_END:
            discard inflateEnd(zstream)
            return true
        of Z_NEED_DICT, Z_DATA_ERROR, Z_MEM_ERROR:
            discard inflateEnd(zstream)
            return false
        else:
            #loop
            discard
    #end while
    discard inflateEnd(zstream)
    return true
  else:
    return false


proc deflate_bytes* (v: string) : string =
  var
    in_strm= newStringStream(v)
    out_strm= newStringStream()
  let ret= deflate(in_strm, out_strm)
  #out_strm.flush
  result= out_strm.data
  in_strm.close
  out_strm.close

proc inflate_bytes* (v: string) : string =
  var
    in_strm= newStringStream(v)
    out_strm= newStringStream()
  let ret= inflate(in_strm, out_strm)
  #out_strm.flush
  result= out_strm.data
  in_strm.close
  out_strm.close


#-- TEST --
when isMainModule:
  import os, strutils

  echo "zlib version=", zlibVersion()
  echo "zstream size=", $size_of(Zstream)
#[
  let zstream= create(Zstream) #ptr Zstream
  let ret= deflateInit(zstream, 6.cint, zlibVersion(), sizeof(Zstream).cint)
  echo "ret= ", ret
  discard resize(zstream, 0)
]#
  let zstreamRef= new Zstream
  let zstream= addr zstreamRef[]
  let ret= deflateInit(zstream, cint(6), zlibVersion(), cint(sizeof(Zstream)))
  echo "ret= ",ret
  
  if paramCount()==0:
    echo "Usage: zlib filename"
  else:
    let data= readFile(paramStr(1))
#    echo "----------"
#    echo data
#    echo "----------"
    let data2= deflate_bytes(data)
    let data3= inflate_bytes(data2)
    echo "len orig=$# compressed=$# inflated=$#, same? $#" %
        [$data.len, $data2.len, $data3.len, $(data==data3)]
#    echo data3

# vim: ts=2 sw=2 et
