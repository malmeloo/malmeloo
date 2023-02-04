import std/[strformat, nre, strutils, math, algorithm, tables, options]

import config

let MOVE_RE = re"(\w+)(\d+)"
let STAR_MOVES = [
  (-1,  0),
  (-1,  1),
  ( 0,  1),
  ( 1,  1),
  ( 1,  0),
  ( 1, -1),
  ( 0, -1),
  (-1, -1)
]
const START_ORD = ord('a')

proc isValid(pos: (int, int)): bool {.inline.} =
  return pos[0] >= 0 and pos[0] < BOARD_SIZE_X and pos[1] >= 0 and pos[1] < BOARD_SIZE_Y

proc `+`(a, b: (int, int)): (int, int) {.inline.} =
  (a[0] + b[0], a[1] + b[1])

proc intToCoords(i: int): (int, int) {.inline.} =
  (i mod BOARD_SIZE_X, i div BOARD_SIZE_X)

proc coordsToInt(c: (int, int)): int {.inline.} =
  c[1] * BOARD_SIZE_X + c[0]

proc indexToLetters*(ind: int): string {.inline.} =
  if ind == 0:
    return "a"

  var i = ind
  while i > 0:
    result = chr((i mod 26) + START_ORD) & result
    i = i div 26

proc lettersToIndex*(letters: string): int {.inline.} =
  for i, letter in letters.reversed:
    result += 26^i * (ord(letter) - START_ORD)

proc readableMoveToInt*(move: string): Option[int] =
  let match = move.match(MOVE_RE)
  if match.isNone: return none(int)

  try:
    let x = lettersToIndex(match.get.captures[0].toLower)
    let y = match.get.captures[1].parseInt - 1
    
    return some[int](y * BOARD_SIZE_X + x)
  except IndexDefect:
    return none(int)


type Mark* = enum
    Empty = 0
    Black = 1
    White = 2
proc `$`*(m: Mark): string =
  case m:
  of Mark.Empty:
    return "◻◻"
  of Mark.Black:
    return "⬛"
  of Mark.White:
    return "⬜"
proc other(m: Mark): Mark =
  case m:
  of Mark.Black:
    return Mark.White
  of Mark.White:
    return Mark.Black
  of Mark.Empty:
    return Mark.Empty

type Move* = ref object
  skip*: bool
  pos*: int
  mark*: Mark
  author*: string
  timestamp*: int
proc `$`*(m: Move): string =
  fmt"Move(skip={m.skip}, pos={m.pos}, mark={m.mark}, author={m.author}, ts={m.timestamp})"

type Board* = ref object
    turn*: Mark
    moveHistory*: seq[Move]
    fields*: seq[Mark]

    metadata*: Table[string, string]

proc getField(board: Board, c: (int, int)): Mark =
  board.fields[coordsToInt(c)]

proc findFlips(board: Board, pos: int, mark: Mark): seq[int] =
  var curPos = intToCoords(pos)
  for moveIncr in STAR_MOVES:
    var flips: seq[int]
    var curPos = curPos + moveIncr

    while isValid(curPos):
      let m = board.getField(curPos)
      if m == Mark.Empty:
        break
      elif m == mark:
        for mark in flips:
          result.add(mark)
        break

      flips.add(coordsToInt(curPos))
      curPos = curPos + moveIncr

proc validMoves*(b: Board, mark: Mark): seq[int] =
  for i, field in b.fields:
    if field == Mark.Empty and b.findFlips(i, mark).len > 0:
      result.add(i)

proc doMove*(b: var Board, move: Move): bool =
  let flips = b.findFlips(move.pos, move.mark)
  if flips.len == 0:  # no flips so invalid
    return false

  for i in flips:
    b.fields[i] = move.mark
  b.fields[move.pos] = move.mark

  b.moveHistory.add(move)

  # only change turn to other player if they have a valid move, otherwise force skip
  if b.validMoves(b.turn.other).len > 0:
    b.turn = b.turn.other

  return true

proc isGameOver*(b: Board): bool =
  b.validMoves(Mark.Black).len == 0 and b.validMoves(Mark.White).len == 0

proc getWinner*(b: Board): Option[Mark] =
  var count = 0
  for field in b.fields:
    case field:
    of Mark.Black: count.inc
    of Mark.White: count.dec
    of Mark.Empty: discard
  
  if count > 0: return some[Mark](Mark.Black)
  elif count < 0: return some[Mark](Mark.White)
  else: return none(Mark)

proc `$`*(b: Board): string =
  for i in 0 ..< b.fields.len:
    result = result & $b.fields[i] & " "
    
    if (i + 1) mod BOARD_SIZE_X == 0:
      result = result & "\n"

proc createNewBoard*(): Board =
  result = Board()
  result.turn = Mark.Black

  result.fields = newSeq[Mark](BOARD_SIZE_X * BOARD_SIZE_Y)
  for i in 0 ..< BOARD_SIZE_X * BOARD_SIZE_Y:
    if i in BOARD_INIT_BLACK:
      result.fields[i] = Mark.Black
    elif i in BOARD_INIT_WHITE:
      result.fields[i] = Mark.White
