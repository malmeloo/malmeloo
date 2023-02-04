import std/[os, strutils, tables, options]

import config
import board
import logging

let CUR_GAMEID_PATH = joinPath(GAME_DB_DIR, ".currentgame")


proc getGameId*(): int =
  try:
    result = readFile(CUR_GAMEID_PATH).strip.parseInt
  except IOError, ValueError:  # no file or not an integer
    result = 0

proc writeGameId*(id: int) =
  writeFile(CUR_GAMEID_PATH, id.intToStr)

proc parseMove(moveStr: string): Option[Move] =
  let parts = moveStr.split("|")

  try:
    return some[Move](Move(
      pos: parts[0].parseInt,
      skip: parts[1] == "0",
      mark: (if parts[1] == "1": Mark.Black else: Mark.White),
      author: parts[2],
      timestamp: parts[3].parseInt
    ))
  except ValueError, IndexDefect:
    return none(Move)

proc serializeMove(move: Move): string =
  result &= $move.pos & "|"
  result &= (if move.skip: "0" else: $ord(move.mark)) & "|"
  result &= move.author & "|"
  result &= $move.timestamp


proc loadBoard*(id: int = getGameId()): Option[Board] =
  let fileName = "game-" & $id & ".txt"

  debugMsg "Loading " & fileName
  var f: File
  defer: f.close()
  try:
    f = open(joinPath(GAME_DB_DIR, fileName))
  except IOError:
    return none(Board)

  debugMsg "Building board"
  result = some[Board](createNewBoard())
  var isMoves = false
  var line: string
  while true:
    try:
      line = f.readLine().strip
    except EOFError:
      break
    
    if line == "----":
      isMoves = true
      continue
    elif not isMoves or line.len == 0:
      continue

    let move = parseMove(line)
    if move.isNone:
      errorMsg "Discarding move (unparseable): " & line
      continue
  
    # actually perform the move
    if not result.get.doMove(move.get):
      errorMsg "Invalid move: " & $move.get

proc saveBoard*(board: Board, id: int = getGameId()): bool =
  let fileName = "game-" & $id & ".txt"

  var f: File
  defer: f.close()
  try:
    f = open(joinPath(GAME_DB_DIR, fileName), fmWrite)
  except IOError:
    return false

  for key, val in board.metadata.pairs:
    f.writeLine(key & ": " & val)
  f.writeLine("----")
  for move in board.moveHistory:
    f.writeLine(serializeMove(move))
  
  writeGameId(getGameId())  # make sure current game id is "clean"

  return true
