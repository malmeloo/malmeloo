import std/logging

var logger = newConsoleLogger(fmtStr="[$time] - $levelname: ")

proc debugMsg*(msg: string) =
  logger.log(lvlDebug, msg)

proc warningMsg*(msg: string) =
  logger.log(lvlWarn, msg)

proc errorMsg*(msg: string) =
  logger.log(lvlError, msg)
