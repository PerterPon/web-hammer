
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

eventPipe      = require 'event-pipe'

class Server extends EventEmitter

  constructor : ( @options, done ) ->
    { port } = @options
    @app     = connect()
    that     = @

    pipe     = eventPipe()
    pipe.on 'error', done

    # mount middleware
    pipe.lazy ->
      that.useMiddlewares @

    # listen port
    pipe.lazy ->
      that.app.listen port, done

    pipe.run()

  # /**
  #  * [useMiddlewares description]
  #  *
  #  * @return {[type]} [description]
  ##
  useMiddlewares : ( done ) ->
    that    = @
    { app } = @

    pipe = eventPipe()
    pipe.on 'error', ( error ) ->

    pipe.lazy ->
      process.nextTick @
    # before mount middleware for plugin
    pipe.lazy ->
      that.emit 'before_mount_middleware', @

    # mount the luantai middleware
    pipe.lazy ->
      app.use that.crossDomain() 

      debug 'use middleware: blank'
      app.use '/blank', that.blankPage()

      debug 'use middleware: phantom ready'
      app.use '/phantom_ready', that.phantomReady()

      debug 'use middleware: load script done'
      app.use '/loadscript_done', that.loadScriptDone()

      debug 'use middleware: run script done'
      app.use '/runscript_done', that.runScriptDone()

      @ null
    # after mount middleware for plugin
    pipe.lazy ->
      that.emit 'after_mount_middleware', @

    pipe.lazy ->
      done null
    pipe.run()

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
      console.log 'loadscript_done'
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
