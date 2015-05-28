
# /*
#   istanbul
# */
# Author: yuhan.wyh<yuhan.wyh@alibaba-inc.com>
# Create: Wed May 27 2015 07:24:48 GMT+0800 (CST)
# 

"use strict"

CodeInstrumenter = require 'istanbul/lib/instrumenter'

urlLib = require 'url'

path   = require 'path'

class IstanbulPlugin

  constructor : ( @app, @options ) ->
    instrumenter = new CodeInstrumenter
      coverageVariable: '_test_'
    @app.use '/', ( req, res, next ) ->
      { url } = req
      __end   = res.end.bind res
      res.end = ( code ) ->
        { pathname, pathname } = urlLib.parse url, true
        extname      = path.extname pathname
        if extname in [ '.coffee', '.js', '.jsx', '.cjsx' ]
          code       = instrumenter.instrumentSync code, pathname
        __end code

      next()

  beforeMountMiddleware : ->

  afterMountMiddleware : ->

  scriptLoader : ->


module.exports = IstanbulPlugin
