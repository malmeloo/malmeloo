import std/[tables, options, sugar, algorithm, times]

import board
import gamedb
import logging

type StatTable* = seq[seq[string]]

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
  var scores = {
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
      scores["Draw"] = scores.getOrDefault("Draw") + 1
    elif winner.get == Mark.Black:
      scores[$Mark.Black] = scores.getOrDefault($Mark.Black) + 1
    elif winner.get == Mark.White:
      scores[$Mark.White] = scores.getOrDefault($Mark.White) + 1
  
  for pair in scores.pairs:
    result.add(@[pair[0], $pair[1]])
  result.sort((p1, p2) => cmp(p1[1], p2[1]), SortOrder.Descending)

proc getMoveHistory*(): StatTable =
  var history: seq[Move]
  for game in getAllGames():
    for move in game.moveHistory:
      history.add(move)
  history.reverse()

  for move in history:
    let dt = fromUnix(move.timestamp).inZone(utc())

    result.add(@[
      "@" & move.author,
      indexToLetters(move.pos),
      $move.mark,
      dt.format("yyyy-MM-dd HH:mm:ss") & " (UTC)"
    ])
