import std/[os, strutils, sugar, tables, sequtils]
import std/[streams, parsecfg]

const CONFIG_PATH = "config.ini"

# load file
var file = newFileStream(CONFIG_PATH)
var conf: CfgParser
conf.open(file, CONFIG_PATH)

# variables
let GITHUB_REPO* = getEnv("GITHUB_REPOSITORY")
let GITHUB_TOKEN* = getEnv("GITHUB_TOKEN")
let GITHUB_ISSUE* = getEnv("ISSUE")

var TARGET_FILE*: string
var TARGET_BOARD_START*: string
var TARGET_BOARD_END*: string

var BOARD_SIZE_X*: int
var BOARD_SIZE_Y*: int
var BOARD_INIT_BLACK*: seq[int]
var BOARD_INIT_WHITE*: seq[int]

var GAME_DB_DIR*: string

var STRINGS*: Table[string, string]


proc processConf(section, key, value: string) =
  case section:
  of "General":
    case key:
    of "target_file": TARGET_FILE = value
    of "board_start": TARGET_BOARD_START = value
    of "board_end": TARGET_BOARD_END = value
  of "Board":
    case key:
    of "size_x": BOARD_SIZE_X = value.parseInt
    of "size_y": BOARD_SIZE_Y = value.parseInt
    of "init_black": BOARD_INIT_BLACK = value.split(",").map(v => v.strip.parseInt)
    of "init_white": BOARD_INIT_WHITE = value.split(",").map(v => v.strip.parseInt)
  
  of "Game":
    case key:
    of "game_db": GAME_DB_DIR = joinPath(getCurrentDir(), value)
  
  of "Strings":
    STRINGS[key] = value.strip


# parse config file
var curSection: string
while true:
  var e = next(conf)
  case e.kind:
  of cfgEof: break
  of cfgSectionStart:
    curSection = e.section
  of cfgKeyValuePair:
    processConf(curSection, e.key, e.value)
  of cfgOption: continue
  of cfgError:
    echo e.msg

conf.close()
