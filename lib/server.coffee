
# /*
#   server
# */
# Author: yuhan.wyh<yuhan.wyh@alibaba-inc.com>
# Create: Tue May 26 2015 06:12:57 GMT+0800 (CST)
# 

"use strict"

connect = require 'connect'

path    = require 'path'

fs      = require 'fs'

urlLib  = require 'url'

debug   = require( 'debug' )( 'luantai:server' )

EventEmitter   = require( 'events' ).EventEmitter

IstanbulPlugin = require '../plugins/istanbul'

CubePlugin     = require '../plugins/cube'

scriptLoader   = require './script-loader'

bodyParser     = require 'body-parser'

class Server extends EventEmitter

  constructor : ( @options, done ) ->
    { port } = @options
    @app = connect()

    new IstanbulPlugin @app, scriptLoader

    @useMiddlewares()

    new CubePlugin @app, scriptLoader, {
      dir : './res'
    }

    @app.listen port, done

  # /**
  #  * [useMiddlewares description]
  #  *
  #  * @return {[type]} [description]
  ##
  useMiddlewares : ->
    { app } = @

    app.use @crossDomain() 

    debug 'use middleware: blank'
    app.use '/blank', @blankPage()

    debug 'user middleware: phantom ready'
    app.use '/phantom_ready', @phantomReady()

    app.use '/loadscript_done', @loadScriptDone()

    app.use '/runscript_done', @runScriptDone()

  crossDomain : ->
    { host, phantomPort } = @options
    ( req, res, next ) =>
      res.setHeader 'Access-Control-Allow-Origin', 'http://#{host}:#{phantomPort}'
      next()

  # /**
  #  * [blankPage if do not got an page, just offer one.]
  #  * @return {[type]} [description]
  ##
  blankPage : ->
    ( req, res, next ) =>
      blankFile = path.join __dirname, '../res/blank.html'
      fs.readFile blankFile, 'utf-8', ( err, data ) ->
        if err
          { message, stack } = err
          debug JSON.stringify { message, stack }
          throw err
          process.exit 1
        else
          res.end data

  # /**
  #  * [phantomReady when phantom ready, server will got this request.]
  #  * @return {[type]} [description]
  ##
  phantomReady : ->
    ( req, res, next ) =>
      @emit 'phantom_ready'
      res.end ''

  # /**
  #  * [loadscriptDone description]
  #  * @return {[type]} [description]
  ##
  loadScriptDone : ->
    ( req, res, next ) =>
      @emit 'loadscript_done'
      res.end ''

  # /**
  #  * [runScriptDone description]
  #  * @return {[type]} [description]
  ##
  runScriptDone : ->
    ( req, res, next ) =>
      that     = @
      bodyData = []
      req.on 'data', bodyData.push.bind bodyData
      req.on 'end', ->
        bodyData = Buffer.concat bodyData
        that.emit 'runscript_done', bodyData.toString()
        res.end ''

  # /**
  #  * [testDone description]
  #  * @return {[type]} [description]
  ##
  testDone : ->
    ( req, res, next ) =>
      { query } = urlLib.parse req.url, true
      { name } = query
      @emit "file_done", name
      res.end 'ok'

module.exports = Server
