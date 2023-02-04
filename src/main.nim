import std/[os, options, times, tables, strutils]

import board
import gamedb
import logging
import github
import markdown

proc exit(error: bool) =
  discard sendComment()
  discard closeIssue(not error)

  quit(if error: 1 else: 0)


proc startNewGame(username: string) =
  debugMsg "Start new game"

  discard addCommentMsg("thanks_submit_move", username)

  let oldBoard = loadBoard()
  if oldBoard.isSome and not oldBoard.get.isGameOver():
    errorMsg "It's not game over yet!"
    discard addCommentMsg("error_no_gameover")
    exit(true)

  let currentId = getGameId()
  let newBoard = createNewBoard()
  newBoard.metadata["Started-By"] = username
  newBoard.metadata["Started-At"] = epochTime().int.intToStr
  
  let ok = saveBoard(newBoard, currentId + 1)
  if not ok:
    errorMsg "Failed to save board!"
    discard addCommentMsg("error_board_save")
    exit(true)
  
  writeGameId(currentId + 1)
  if not updateFile(newBoard):
    warningMsg "Could not update target file"
  debugMsg "New game ok!"

  discard addCommentMsg("game_create_success")
  discard addCommentMsg("raw", 
    makeDropdown("View current board state", generateBoardTable(newBoard))
  )
  discard sendComment()


proc doMove(username: string, moveStr: string) =
  debugMsg "Do move"

  let moveInt = readableMoveToInt(moveStr)
  if moveInt.isNone:
    errorMsg "Move syntax invalid: " & moveStr
    discard addCommentMsg("error_move_syntax")
    exit(true)

  var board = loadBoard()
  if board.isNone:
    debugMsg "Couldn't load board!"
    discard addCommentMsg("error_board_load")
    exit(true)

  var move: Move
  try:
    move = Move(
      skip: moveStr.toLower() == "skip",
      pos: moveInt.get,
      mark: board.get.turn,
      author: username,
      timestamp: epochTime().int
    )
  except ValueError:
    debugMsg "Invalid move arguments"
    discard addCommentMsg("error_move_syntax")
    exit(true)
  
  var ok = board.get.doMove(move)
  if not ok:
    debugMsg "Invalid move, valid moves: " & $board.get.validMoves(board.get.turn)
    discard addCommentMsg("error_move_invalid")
    exit(true)
  
  ok = saveBoard(board.get)
  if not ok:
    debugMsg "Could not save board state"
    discard addCommentMsg("error_board_save")
    exit(true)

  if not updateFile(board.get):
    warningMsg "Could not update target file"

  debugMsg "New move ok!"
  discard addCommentMsg("thanks_submit_move", username)

  echo "Current board:"
  echo board.get
  discard addCommentMsg("raw", 
    makeDropdown("View current board state", generateBoardTable(board.get))
  )

  if board.get.isGameOver():
    let winner = board.get.getWinner()
    if winner.isNone:
      debugMsg "It's a tie!"
      discard addCommentMsg("winner_tie")
    else:
      debugMsg $winner.get & " won!"
      discard addCommentMsg("winner_determined", $winner.get)
  else:
    debugMsg "The game isn't over yet!"
    discard addCommentMsg("move_success")

  discard sendComment()


if isMainModule:
  try:
    let username = paramStr(1)
    let issueArgs = paramStr(2).split("|")
    
    case issueArgs[0].toLower
    of "newgame":
      startNewGame(username)
      exit(false)
    of "move":
      doMove(username, issueArgs[1])
      exit(false)
    else:
      debugMsg "Unknown command"
      discard addCommentMsg("error_command")
      exit(true)
  except IndexDefect:
    debugMsg "Missing argument"
    discard addCommentMsg("error_command")
    exit(true)
  
  exit(false)
