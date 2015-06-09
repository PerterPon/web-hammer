
# /*
#   util
# */
# Author: PerterPon<PerterPon@gmail.com>
# Create: Tue May 26 2015 12:15:53 GMT+0800 (CST)
# 

"use strict"

fs   = require 'fs'

path = require 'path'

dottor = null

module.exports =
  iterateFolder : ( fPath ) ->
    testFiles = []
    getFile   = ( fPath ) ->
      files   = fs.readdirSync fPath
      for file in files
        if true is fs.lstatSync( path.join fPath, file ).isDirectory()
          getFile path.join fPath, file
        else
          testFiles.push path.join fPath, file

    getFile fPath
    testFiles

  dotting : ( text, ellipsis = '..' ) ->
    if '...' is ellipsis
      ellipsis  = '.'
    else
      ellipsis += '.'
    process.stdout.cursorTo 0
    process.stdout.clearLine 1
    process.stdout.write "\u001b[93m#{text}#{ellipsis}\u001b[0m"
    dottor = setTimeout ->
      module.exports.dotting text, ellipsis
    , 500

  stopDot : ( text ) ->
    clearTimeout dottor
    text = "\u001b[92m#{text}\u001b[0m\n"
    process.stdout.cursorTo 0
    process.stdout.clearLine 1
    process.stdout.write text
