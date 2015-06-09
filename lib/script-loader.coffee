
# /*
#   script-loader
# */
# Author: PerterPon<PerterPon@gmail.com>
# Create: Wed May 27 2015 09:51:52 GMT+0800 (CST)
# 

"use strict"

fs = require 'fs'

processers = []

loader = ( file, done ) ->
  fs.readFile file, ( err, data ) ->
    unless err
      data = """
      #{data}
      ;window.callPhantom( 'luantai.scriptload.done' );
      """
      done null, data

processers.push loader

loaderRegister = ( processer ) ->
  processers.push processer

module.exports = ( file, done ) ->
  processer = processers[ processers.length - 1 ]
  processer file, done

module.exports.register = loaderRegister
