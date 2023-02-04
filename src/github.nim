import std/[strformat, strutils, json, tables, httpclient]

import logging
import config

var canUse = true
if GITHUB_REPO == "" or GITHUB_TOKEN == "" or GITHUB_ISSUE == "":
  warningMsg "Missing environment variables; cannot use GitHub API"
  canUse = false

let ISSUE_URL = fmt"https://api.github.com/repos/{GITHUB_REPO}/issues/{GITHUB_ISSUE}"
let HEADERS = newHttpHeaders({
  "Accept": "application/vnd.github+json",
  "Authorization": "Bearer " & GITHUB_TOKEN,
  "X-GitHub-Api-Version": "2022-11-28"
})

let client = newHttpClient(headers = HEADERS)

debugMsg "Using issue endpoint: " & ISSUE_URL


var commentMsg: string

proc addCommentMsg*(id: string, args: varargs[string]): bool =
  let msg = STRINGS.getOrDefault(id)
  if msg == "": return false

  commentMsg &= "\n\n" & msg.format(args)
  commentMsg = commentMsg.strip

proc sendComment*(): bool =
  if not canUse or commentMsg.len == 0: return false

  debugMsg fmt"Sending comment (length: {commentMsg.len})"
  let body = %*{"body": commentMsg}
  let resp = client.request(ISSUE_URL & "/comments", httpMethod = HttpPost, body = $body)
  commentMsg = ""

  if resp.status.toLower != "201 created":
    errorMsg "Error while posting comment: " & resp.status
    errorMsg resp.body
    return false
  return true

proc closeIssue*(success: bool): bool =
  if not canUse: return false

  debugMsg fmt"Closing issue (success: {success})"
  let body = %*{"state": "closed", "labels": [(if success: "success" else: "error")]}
  let resp = client.request(ISSUE_URL, httpMethod = HttpPatch, body = $body)

  if resp.status.toLower != "200 ok":
    errorMsg "Error while closing issue: " & resp.status
    errorMsg resp.body
    return false
  return true
