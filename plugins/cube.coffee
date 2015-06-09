
# /*
#   cube
# */
# Author: PerterPon<PerterPon@gmail.com>
# Create: Wed May 27 2015 07:08:39 GMT+0800 (CST)
# 

"use strict"

Cube = require 'node-cube'

path = require 'path'

cp   = require 'cp'

fs   = require 'fs'

eventPipe    = require 'event-pipe'

childProcess = require 'child_process'

CUBE_BACKUP  = './__test__'

class CubePlugin

  constructor : ( @options, done = -> ) ->

    @initParams()

    that = @

    pipe = eventPipe()
    pipe.on 'error', done

    pipe.lazy ->
      that.prepareFile @

    pipe.lazy ->
      that.initCubeServer @

    pipe.lazy ->
      done null

    pipe.run()

  initParams : ->
    cwd      = process.cwd()
    @options.resDir  ?= './res'
    @options.testDir ?= './tests'

    @options.urlBase ?= '/'

  prepareFile : ( done ) ->

    { testDir, resDir } = @options

    cwd = process.cwd()

    if false is path.isAbsolute resDir
      resDir  = path.join cwd, resDir
    if false is path.isAbsolute testDir
      testDir = path.join cwd, testDir

    pipe = eventPipe()
    pipe.on 'error', done

    resTestDir = path.join resDir, CUBE_BACKUP

    pipe.lazy ->
      cp = childProcess.spawn 'rm', [ '-rf', resTestDir ]
      cp.on 'exit', =>
        @ null

    pipe.lazy ->
      cp = childProcess.spawn 'cp', [ '-r', testDir, path.join resDir, CUBE_BACKUP ]
      cp.on 'exit', =>
        @ null

    pipe.lazy ->
      done null

    pipe.run()

  initCubeServer : ( done ) ->
    { resDir }  = @options

    cwd = process.cwd()
    @middleware = Cube.init
      root       : path.join cwd, resDir
      middleware : true
      processors : [ 'cube-ejs', 'cube-jade', 'cube-less', 'cube-stylus' ]

    done()

  afterMountMiddleware : ( app, done ) ->
    app.use '/', ( req, res, next ) =>
      @middleware req, res, next

    done()

  scriptLoader : ( done ) ->
    { resDir, testDir, urlBase } = @options
    cwd = process.cwd()

    done null, ( file, done ) ->
      baseFile = path.join cwd, testDir
      file     = file.replace baseFile, ''

      done null, """
      Cube.init( {
        base : \"#{urlBase}\",
        enableCss : true
      } );
      Cube.use( \"/__test__#{file}\", function() {
        window.callPhantom( 'luantai.scriptload.done' );
      } );
      """

  injectJs : ( done ) ->
    cubeJsPath  = path.join __dirname, '../node_modules/node-cube/runtime/cube.min.js'
    cubeCssPath = path.join __dirname, '../node_modules/node-cube/runtime/cube_css.min.js'
    ejsRuntime  = path.join __dirname, '../node_modules/node-cube/runtime/ejs_runtime.min.js'
    jadeRuntime = path.join __dirname, '../node_modules/node-cube/runtime/jade_runtime.min.js'
    done null, [
      cubeJsPath
      cubeCssPath
      ejsRuntime
      jadeRuntime
    ]

module.exports = CubePlugin
