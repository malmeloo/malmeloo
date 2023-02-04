import std/[strutils, strformat, sequtils, algorithm, sugar, tables, nre, uri]

import board
import config
import logging
import stats

const MAX_STAT_ENTRIES = 5

let COMMENT_RE = re"^<!--(.+?)-->$"


proc getIssueUrl(move: int): string =
  var moveStr: string
  if move < 0:  # new game
    moveStr = "Reversi|newgame"
  else:
    moveStr = fmt"Reversi|move|{indexToLetters(move mod BOARD_SIZE_X)}{move div BOARD_SIZE_X + 1}"
  return fmt"https://github.com/{GITHUB_REPO}/issues/new?title=" & encodeUrl(moveStr)

proc getStatusMessage(board: Board): string =
  let winner = board.getWinner()

  if not board.isGameOver():  # ongoing game
    result = STRINGS.getOrDefault("status_turn").format(board.turn)
  elif winner.isSome:  # game over, winner known
    result = STRINGS.getOrDefault("status_win").format(winner.get, getIssueUrl(-1))
  else:  # game over, draw
    result = STRINGS.getOrDefault("status_draw").format(getIssueUrl(-1))

  result &= "\n"

proc formatStatTable(table: StatTable): string =
  var pairs = table.pairs.toSeq.sorted((fst, snd) => fst[1] > snd[1])
  pairs = pairs[0 .. min(MAX_STAT_ENTRIES, pairs.len - 1)]
  
  result &= "<table>\n"
  for pair in pairs:
    result &= "<tr><td>" & pair[0] & "</td><td>" & $pair[1] & "</td></tr>\n"
  result &= "</table>"

proc createHorizontalTable(contents: Table[string, string]): string =
  var headers: seq[string]
  result &= "<table>\n"

  # table header
  result &= "<tr>\n"
  for header in contents.keys:
    result &= "<th>" & header & "</th>"
    headers.add(header)
  result &= "\n</tr>"

  result &= "<tr>\n"
  # table body
  for header in headers:
    result &= "<td>\n\n" & contents[header] & "\n\n</td>"
  result &= "\n</tr>\n"
  result &= "</table>"

proc generateBoardTable*(board: Board): string =
  # table header
  result = "| |"
  for x in 0 ..< BOARD_SIZE_X:
    result &= indexToLetters(x) & "|"
  result &= "\n|-|"
  for x in 0 ..< BOARD_SIZE_X:
    result &= "-|"
  result &= "\n"

  let possibleMoves = board.validMoves(board.turn)
  
  # table rows
  for y in 0 ..< BOARD_SIZE_Y:
    result &= "|" & $(y + 1) & "|"
    for x in 0 ..< BOARD_SIZE_X:
      let fieldNum = y * BOARD_SIZE_X + x
      if fieldNum in possibleMoves:
        result &= "[✓](" & getIssueUrl(fieldNum) & ")"
      elif board.fields[fieldNum] != Mark.Empty:
        result &= $board.fields[fieldNum]
      else:
        result &= " "
      result &= "|"
    result &= "\n"

proc makeDropdown*(header, text: string): string =
  result &= "<details>\n"
  result &= "<summary>" & header & "</summary>\n\n"
  result &= text & "\n"
  result &= "</details>"

proc getGameRepr(board: Board): string =
  result &= generateBoardTable(board)
  result &= "\n" & getStatusMessage(board)

  result &= "\n" & createHorizontalTable({
    "Winning mark": formatStatTable(getMarkWinStats())
  }.toTable)

proc updateFile*(board: Board): bool =
  var content: string
  try:
    content = readFile(TARGET_FILE)
  except IOError:
    debugMsg "Could not find target file to write to"
    return false

  var f: File
  try:
    f = open(TARGET_FILE, fmWrite)
  except IOError:
    debugMsg "Could not open target file for writing"
  defer: f.close()

  var doWrite = true
  for line in content.strip.split("\n"):
    let match = line.find(COMMENT_RE)
    if match.isSome and TARGET_BOARD_END in match.get.captures[0]:
      doWrite = true

    if doWrite:
      f.writeLine(line)

    if match.isSome and TARGET_BOARD_START in match.get.captures[0]:
      doWrite = false

      f.write(getGameRepr(board))
  
  return true
