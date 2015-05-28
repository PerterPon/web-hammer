
# /*
#   cube
# */
# Author: yuhan.wyh<yuhan.wyh@alibaba-inc.com>
# Create: Wed May 27 2015 07:08:39 GMT+0800 (CST)
# 

"use strict"

Cube = require 'node-cube'

path = require 'path'

cp   = require 'cp'

fs   = require 'fs'

eventPipe = require 'event-pipe'

childProcess = require 'child_process'

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
    @options.resDir  ?= path.join cwd, './res'
    @options.testDir ?= path.join cwd, './tests'

    { resDir, testDir } = @options
    if false is path.isAbsolute resDir
      resDir  = path.join cwd, resDir
    if false is path.isAbsolute testDir
      testDir = path.join cwd, testDir
    @options.resDir  = resDir
    @options.testDir = testDir

    @options.urlBase ?= '/'

  prepareFile : ( done ) ->

    { testDir, resDir } = @options

    pipe = eventPipe()
    pipe.on 'error', done

    resTestDir = path.join resDir, './__test__'

    pipe.lazy ->
      cp = childProcess.spawn 'rm', [ '-rf', resTestDir ]
      cp.on 'exit', =>
        @ null

    pipe.lazy ->
      cp = childProcess.spawn 'cp', [ '-r', testDir, path.join resDir, './__test__' ]
      cp.on 'exit', =>
        @ null

    pipe.lazy ->
      done null

    pipe.run()

  initCubeServer : ( done ) ->
    { resDir }    = @options

    @middleware = Cube.init
      root       : resDir
      middleware : true

    done()

  afterMountMiddleware : ( app, done ) ->
    app.use '/', @middleware

    done()

  scriptLoader : ( done ) ->
    { resDir, urlBase } = @options

    done null, ( file, done ) ->
      basename = path.basename file

      done null, """
      Cube.init( {
        base : \"#{urlBase}\"
      } );
      Cube.use( \"/__test__/#{basename}\", function() {
        console.log( 'luantai.scriptload.done' );
        window.callPhantom( 'luantai.scriptload.done' );
      } );
      """

  injectJs : ->
    cubeJsPath = path.join __dirname, '/node_modules/node-cube/runtime/cube.js'
    [
      cubeJsPath
    ]

module.exports = CubePlugin
