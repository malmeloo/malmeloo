import std/[tables, options]

import board
import gamedb
import logging

type StatTable* = Table[string, int]

var ALL_GAMES: seq[Board]

proc getAllGames(): seq[Board] =
  if ALL_GAMES.len > 0:  # crude caching
    return ALL_GAMES

  debugMsg "Loading all games... This may take a while"
  for id in 0 .. getGameId():
    let board = loadBoard(id)
    if board.isNone:
      continue

    result.add(board.get)
  
  ALL_GAMES = result


proc getMarkWinStats*(): StatTable =
  result = {
    "Draw": 0,
    $Mark.Black: 0,
    $Mark.White: 0
  }.toTable

  let games = getAllGames()
  for game in games:
    if not game.isGameOver():
      continue

    let winner = game.getWinner()
    if winner.isNone:
      result["Draw"] = result.getOrDefault("Draw") + 1
    elif winner.get == Mark.Black:
      result[$Mark.Black] = result.getOrDefault($Mark.Black) + 1
    elif winner.get == Mark.White:
      result[$Mark.White] = result.getOrDefault($Mark.White) + 1
