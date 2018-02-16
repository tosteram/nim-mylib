#[
;File	sqlite3.nim
;Date	2015-10-13 for ypsilon
;Usage ex.
;	(import (prefix (sqlite3) sql:)
;	(define d (sql:open "file.sql"))
;	;;insert
;	(define ins (sql:prepare d
;				"insert into test (name, inum, dnum, bin) values (?,?,?,?)"))
;	(sql:execute ins "aaa" 2 3.4 (u8-list->bytevector '(10,11,12)))
;	(sql:reset ins)
;	(sql:execute ins "bbb" 33 5.0 (u8-list->bytevector '(100,110,120,130)))
;	(sql:finalize ins)
;	;; read
;	(define s (sql:prepare d "select * from test where id=?"))
;	(sql:fetch s id1)
;	(sql:finalize s)

	2017-03-02 for Nim
]#

# export:
#   open close
#		get-error version
#		begin-transaction commit rollback
#		prepare exec execute fetch fetch-one fetch-all
#		step reset finalize
#		--constants
#		SQLITE_OK SQLITE_ROW SQLITE_DONE

# Windows
when hostOS=="windows":
  #const lib_file= "C:\\Program Files\\GnuWin32\\bin\\sqlite3.dll"
  const lib_file= "sqlite3_32.dll"
else:
  # MacOS / Linux
  const lib_file= "sqlite3.so"
{.push, cdecl, dynlib:lib_file.}

proc open_c(file:cstring, ptr_to_db:var pointer): cint {.importc:"sqlite3_open".}
proc close_c(db:pointer): cint {.importc:"sqlite3_close".}
proc errcode_c(db:pointer): cint {.importc:"sqlite3_errcode".}
proc errmsg_c(db:pointer): cstring {.importc:"sqlite3_errmsg".}
proc prepare_c(db:pointer, sql:cstring, sql_len:int, ptr_to_stmt:var pointer, tail:var pointer): cint {.importc:"sqlite3_prepare".}

proc bind_int(stmt:pointer, n:cint, val:cint): cint {.importc:"sqlite3_bind_int", discardable.}
proc bind_double(stmt:pointer, n:cint, val:cdouble): cint {.importc:"sqlite3_bind_double", discardable.}
proc bind_text(stmt:pointer, n:cint, val:cstring, size:csize, d_tor:int): cint {.importc:"sqlite3_bind_text", discardable.}
# The last argument type is void(*)(void*) destructor,
# or SQLITE_STATIC=0, SQLITE_TRANSIENT=-1
proc bind_blob(stmt:pointer, n:cint, val:pointer, size:csize, d_tor:int): cint {.importc:"sqlite3_bind_blob", discardable.}
proc bind_null(stmt:pointer, n:cint): cint {.importc:"sqlite3_bind_null", discardable.}
#proc clear_bindings(stmt:pointer): cint {.importc:"sqlite3_clear_bindings", discardable.}

#proc bind_parameter_index(stmt:pointer, name:cstring):
#   cint {.importc:"sqlite3_bind_parameter_index".}

proc step* (stmt:pointer): cint {.importc:"sqlite3_step".}
proc reset* (stmt:pointer): cint {.importc:"sqlite3_reset", discardable.}
proc finalize* (stmt:pointer): cint {.importc:"sqlite3_finalize", discardable.}

proc column_count(stmt:pointer): cint {.importc:"sqlite3_column_count".}
#proc column_name(stmt:pointer, n:cint): cstring {.importc:"sqlite3_column_name".}
proc column_type(stmt:pointer, n:cint): cint {.importc:"sqlite3_column_type".}
proc column_int(stmt:pointer, n:cint): cint {.importc:"sqlite3_column_int".}
proc column_double(stmt:pointer, n:cint): cdouble {.importc:"sqlite3_column_double".}
proc column_text(stmt:pointer, n:cint): cstring {.importc:"sqlite3_column_text".}
proc column_blob(stmt:pointer, n:cint): pointer {.importc:"sqlite3_column_blob".}
proc column_bytes(stmt:pointer, n:cint): cint {.importc:"sqlite3_column_bytes".}

#(define get-table (c-function sql3 "sql3" int sqlite3_get_table (void* char* void* void* void* void*)))
#proc last_insert_rowid(db:pointer): uint64 {.importc:"sqlite3_last_insert_rowid".}
#proc changes(db:pointer): int {.importc:"sqlite3_changes".}
#proc busy_timeout(db:pointer, millisec:cint): cint {.importc:"sqlite3_busy_timeout".}

{.pop.}

# constants
const
  SQLITE_OK* = 0
  SQLITE_ROW* = 100
  SQLITE_DONE* = 101
#SQLITE_ERROR 1, SQLITE_BUSY 5, SQLITE_MISUSE 21, 

  SQLITE_INTEGER= 1
  #SQLITE_INT64= ?
  SQLITE_FLOAT= 2
  SQLITE_TEXT= 3
  SQLITE_BLOB= 4
  SQLITE_NULL= 5

  SQLITE_STATIC= 0
  SQLITE_TRANSIENT= -1

type
  DbConn* = pointer
  Stmt* = pointer

  ValType* = enum
    tInt, tFloat, tText, tBlob, tNull

  DbVal* = object
    case vtype*: ValType
    of tInt: intVal*: int
    of tFloat: floatVal*: float
    of tText: textVal*: string
    of tBlob: blobVal*: string
    of tNull: nil

proc dbInt*(v:int): DbVal = DbVal(vtype:tInt, intVal:v)
proc dbFloat*(v:float): DbVal = DbVal(vtype:tFloat, floatVal:v)
proc dbText*(v:string): DbVal = DbVal(vtype:tText, textVal:v)
proc dbBlob*(v:string): DbVal = DbVal(vtype:tBlob, blobVal:v)
proc dbNull*(): DbVal = DbVal(vtype:tNull)

#-------

# filename: UTF-8
# [return] db object or #f
proc openDb* (filename:string): DbConn =
  let ret= open_c(filename, result)
  if ret!=SQLITE_OK:
    raise newException(IOError, "Unable to open: " & filename)

proc closeDb* (db: DbConn) =
  if db!=nil:
    let ret= close_c(db)
    if ret==SQLITE_OK:
      discard
    else:
      raise newException(IOError, $db.errmsg_c)

proc get_error* (db:DbConn): (int, string) =
  return (errcode_c(db).int, $errmsg_c(db))

# [return] sql-statement object or #f
proc prepare* (db:DbConn, sqlstr:string): Stmt =
  var tail: pointer
  let ret= prepare_c(db, sqlstr, -1, result, tail)
  if ret!=SQLITE_OK:
    raise newException(ValueError, $db.errmsg_c)

proc bind_param(stmt:Stmt, col:cint, data:DbVal) =
  case data.vtype
    of tInt:
      bind_int(stmt, col, data.intVal.cint)
    of tFloat:
      bind_double(stmt, col, data.floatVal.cdouble)
    of tText:
      bind_text(stmt, col, data.textVal, -1, SQLITE_STATIC)  # TODO static or transient?
    of tBlob:
      bind_blob(stmt, col, unsafeAddr(data.blobVal[0]), data.blobVal.len, SQLITE_STATIC)
    else:
      bind_null(stmt, col)

# [in]params: list of data
proc bind_params(stmt:Stmt, params:varargs[DbVal]) =
  for col0, param in params:
    bind_param(stmt, cint(col0+1), param)

proc get_types(stmt:Stmt) : seq[int] =
  let count= column_count(stmt)
  result= newSeq[int](count)
  for col in 0..<count:
    result[col]= column_type(stmt, col)
  #NB type conversion

proc get_row_data(stmt:Stmt, types:openArray[int]) : seq[DbVal] =
  result= newSeq[DbVal](types.len)
  for col, typ in types:
    case typ
      of SQLITE_INTEGER:
        result[col]= dbInt(column_int(stmt, col.cint))
      of SQLITE_FLOAT:
        result[col]= dbFloat(column_double(stmt, col.cint))
      of SQLITE_TEXT:
        result[col]= dbText($column_text(stmt, col.cint))
      of SQLITE_BLOB:
        let blob= column_blob(stmt, col.cint)
        let size= column_bytes(stmt, col.cint)
        let val= newString(size)
        copyMem(unsafeAddr(val[0]), blob, size)
        result[col]= dbBlob(val)
      else:
        result[col]= dbNull()

#----------
#statement

# Execute the stmt with params
# [return] SQLITE_DONE, (.._ROW), .._BUSY, .._ERROR, .._MISUSE
# stmt must be finalized after the call
proc exec* (stmt:Stmt, params:varargs[DbVal]) : int {.discardable.} =
  bind_params(stmt, params)
  return step(stmt)

# Execute the stmt with new params
# bindings are reset before exec; use this to repeat inserting, deleting.. varying params
# [return] SQLITE_DONE, (.._ROW), .._BUSY, .._ERROR, .._MISUSE
# stmt must be finalized after the call
proc exec_new* (stmt:Stmt, params:varargs[DbVal]) : int {.discardable.} =
  reset(stmt)
  bind_params(stmt, params)
  result= step(stmt)

# one-shot execution
proc exec* (db:DbConn, sqlstr:string, params:varargs[DbVal]) : int {.discardable.} =
  let stmt= prepare(db, sqlstr)
  result= exec(stmt, params)
  stmt.finalize

proc begin_transaction* (db:DbConn) =
  exec(db, "begin transaction")
proc commit* (db:DbConn) =
  exec(db, "commit")
proc rollback* (db:DbConn) =
  exec(db, "rollback")

template with_transaction* (db:DbConn, sql:string, actions: untyped): untyped =
  let stmt {.inject.} = prepare(db, sql)
  begin_transaction(db)
  actions
  stmt.finalize
  commit(db)

# [return] list(row) or #f(error)
# stmt must be finalized after the call
proc fetch* (stmt:Stmt, params:varargs[DbVal]) : seq[DbVal] =
  case exec(stmt, params)
    of SQLITE_ROW:
      return get_row_data(stmt, get_types(stmt))
    of SQLITE_DONE:
      return @[]  #nil
    else:
      return nil #TODO

# [return] list, '() if no data
proc fetch_one* (db:DbConn, sqlstr:string, params:varargs[DbVal]) : seq[DbVal] =
  let stmt= prepare(db, sqlstr)
  result= fetch(stmt, params)
  stmt.finalize

iterator fetch_rows* (db:DbConn, sql:string, params:varargs[DbVal]) : seq[DbVal] =
  let stmt= prepare(db, sql)
  bind_params(stmt, params)
  while step(stmt)==SQLITE_ROW:
    yield get_row_data(stmt, get_types(stmt))
  stmt.finalize

# [return] list of rows
proc fetch_all* (db:DbConn, sqlstr:string, params:varargs[DbVal]) : seq[seq[DbVal]] =
  result= @[]
  for r in fetch_rows(db, sqlstr, params):
    result.add(r)

proc version* (db: DbConn): string =
  let ver= fetch_one(db, "select sqlite_version()")
  return ver[0].textVal


#-- Test
when isMainModule:
  import strutils

  let db= openDb(":memory:")
  echo "version=", version(db)

  exec(db, "drop table if exists test")
  exec(db, "create table if not exists test (id integer, t text, f float, b blob)")

  let rows0= fetch_all(db, "select id,t,f,b from test")
  echo "initial rows len=", $rows0.len

  with_transaction(db, "insert into test (id,t,f,b) values (?,?,?,?)"):
    exec_new(stmt,
        dbInt(1), dbText("Abc xyz"), dbFloat(5.67), dbBlob("123x\0OK\x01Just"))
    exec_new(stmt,
        dbInt(2), dbText("This is a pen."), dbFloat(1.2345), dbBlob("123ABC\x01Just"))
    exec_new(stmt,
        dbInt(3), dbText("Abc 漢字かな 123"), dbFloat(123.0),
        dbBlob("\x10\xf0\0Book\x01Marks"))

#  begin_transaction(db)
#  let stmt= prepare(db, "insert into test (id,t,f,b) values (?,?,?,?)")
#  exec_new(stmt,
#      dbInt(1), dbText("Abc xyz"), dbFloat(5.67), dbBlob("123x\0OK\x01Just"))
#  exec_new(stmt,
#      dbInt(2), dbText("This is a pen."), dbFloat(1.2345), dbBlob("123ABC\x01Just"))
#  exec_new(stmt,
#      dbInt(3), dbText("Abc 漢字かな 123"), dbFloat(123.0),
#      dbBlob("\x10\xf0\0Book\x01Marks"))
#  stmt.finalize
#  commit(db)

  let rows= fetch_all(db, "select id,t,f,b from test where id>=?", dbInt(2))
  echo $rows

  for r in fetch_rows(db, "select id,t,f,b from test"):
    echo "id=$# t=$# f=$# b.len=$# b=$#" %
          [$r[0].intVal, r[1].textVal, $r[2].floatVal, $r[3].blobVal.len, r[3].blobVal]

  closeDb(db)

# vim: ts=2 sw=2 et
