
# /*
#   stage
# */
# Author: yuhan.wyh<yuhan.wyh@alibaba-inc.com>
# Create: Mon May 25 2015 09:17:49 GMT+0800 (CST)
# 

"use strict"

require 'colors'

debug         = require( 'debug' )( 'luantai' )

phantom       = require 'phantomjs'

path          = require 'path'

fs            = require 'fs'

fse           = require 'fs-extra'

http          = require 'http'

Server        = require './server'

util          = require './util'

PluginManager = require './plugin-manager'

childProcess  = require 'child_process'

eventPipe     = require 'event-pipe'

request       = require 'request'

ScriptLoader  = require './script-loader'

coffee        = require 'coffee-script'

host          = '127.0.0.1'

injectedJs    = []

feedbacks     = []

feedbackMap   = {}

class Stage

  constructor : ( @args ) ->
    @generatePort()
    @parseConfig()

  # /**
  #  * [generatePort now we have two servers, 1. master server. 2. phantom server.]
  #  * @return {[type]} [description]
  ##
  generatePort : ->
    @masterPort  = 10000 + Math.floor Math.random() * 1000
    @phantomPort = 10000 + Math.floor Math.random() * 1000

  # /**
  #  * [parseConfig parse config form the param]
  #  * @return {[type]} [description]
  ##
  parseConfig : ->
    { config, file, plugins } = @args
    cwd = process.cwd()

    # if pass an config file param.
    if config
      if false is path.isAbsolute config
        config = path.join cwd, config
      if false is fs.existsSync config
        error  = new Error "config file was not found: #{config}"
        throw err
        process.exit()
      else
        configItem = require config

    # or get the param form arguments
    else
      file         = [ file ]
      configItem   = { file, plugins }

    { file } = configItem
    file     = @trans2Files file
    file     = @filterFiles file

    configItem.file = file
    @fileList       = file

    @parsedConfig   = configItem
    @init configItem

  trans2Files : ( files ) ->
    if false is Array.isArray files
      files   = [ files ]

    cwd = process.cwd()

    testFiles = []
    for file in files
      if false is path.isAbsolute file
        file  = path.join cwd, file

      if true is fs.lstatSync( file ).isDirectory()
        files     = util.iterateFolder file
        testFiles = testFiles.concat files
      else
        if false is fs.existsSync file
          error   = new Error "test file: #{file} was not exists!"
          throw error
          @exit()
        else
          testFiles.push file

    testFiles

  filterFiles : ( files ) ->
    { rule } = @args
    rule    ?= '.*'

    filteredFiles = []
    filterRule    = new RegExp rule
    for file in files
      basename    = path.basename file
      if true is filterRule.test basename
        filteredFiles.push file

    filteredFiles

  init : ( config ) ->
    util.stopDot 'initialize done!'
    { plugins, file, env } = config
    that = @

    pipe = eventPipe()
    pipe.on 'error', ( error ) =>
      { message, stack } = error
      debug JSON.stringify { message, stack }
      throw error
      @exit()

    # copy project files to out folder
    # pipe.lazy ->
    #   debug 'copy files'
    #   that.prapareFiles @

    # init plugins
    pipe.lazy ->
      debug 'start init plugins'
      that.initPlugins plugins, @

    # init script loader
    pipe.lazy ->
      debug 'start script loader'
      that.scriptLoader @

    # init feed back
    pipe.lazy ->
      debug 'start feed back'
      that.feedback @

    pipe.lazy ->
      debug 'start deal inject js'
      that.injectJs @

    # init luantai server
    pipe.lazy ->
      debug 'start init server'
      that.initServer @

    # init phantom
    pipe.lazy ->
      debug 'start init phantom'
      that.initPhantom @

    # start file test
    pipe.lazy ->
      debug 'start file test'
      that.loadPhantomFile @

    pipe.run()

  # prapareFiles : ( done ) ->
  #   prepareShell = path.join __dirname, '../bin/prepare-files'
  #   luantaiDir   = path.join __dirname, '..'
  #   projectDir   = process.cwd()
  #   childProcess.spawn ''
    # util.dotting 'preparing files'
    # cwd = process.cwd()
    # outPath  = path.join cwd, './out'
    # fse.removeSync outPath
    # fs.mkdirSync outPath

    # copyFile = ( fPath ) ->
    #   files      = fs.readdirSync fPath
    #   for file in files
    #     filePath = path.join fPath, file
    #     console.log filePath
    #     if true is fs.lstatSync( filePath ).isDirectory()
    #       fs.mkdirSync filePath.replace cwd, outPath
    #       copyFile filePath
    #     else
    #       content   = fs.readFileSync filePath
    #       if path.extname( filePath ) in [ 'coffee' ]
    #         content = coffee.compile "#{content}"

    #       outFilePath = filePath.replace cwd, outPath
    #       fs.writeFileSync outFilePath, content

    # copyFile cwd
    # util.dotting 'all files ready!'
    # done null

  # /**
  #  * [initPlugins description]
  #  * @param  {[type]}   plugins =             [] [description]
  #  * @param  {Function} done    [description]
  #  * @return {[type]}           [description]
  ##
  initPlugins : ( plugins = [], done ) ->
    @pluginManager = new PluginManager plugins, @parsedConfig, done

  # /**
  #  * [initServer description]
  #  * @param  {Function} done [description]
  #  * @return {[type]}        [description]
  ##
  initServer : ( done ) ->
    util.dotting 'trying to start luantai server'

    { masterPort } = @
    serverOption   =
      port : masterPort

    @server = new Server serverOption, done
    @bindServerEvent()

  # /**
  #  * [bindServerEvent bind server event]
  #  * @param  {[type]} server [description]
  #  * @return {[type]}        [description]
  ##
  bindServerEvent : ->
    { server } = @
    server.on 'before_mount_middleware', @beforeMountMiddleware.bind @
    server.on 'after_mount_middleware',  @afterMountMiddleware.bind  @
    server.on 'loadscript_done',         @loadPhantomFile.bind @
    server.on 'runscript_done',          @finishTest.bind @
    server.on 'exit',                    @exit.bind @

  # /**
  #  * [initPhantom start phantomjs]
  #  * @return {[type]} [description]
  ##
  initPhantom : ( done ) ->
    util.stopDot 'luantai server start success!'

    console.log '\u001b[93mtrying to start phantomjs...\u001b[0m'
    phantomHost = path.join __dirname, './phantom-host.js'
    phantomPath = path.join __dirname, '../node_modules/.bin/phantomjs'
    { masterPort, phantomPort } = @
    rootPath    = path.join __dirname, '..'

    debug "start phantom with param: #{phantomHost}, #{host}, #{masterPort}, #{phantomPort}"
    @phantom    = childProcess.spawn phantomPath, [
      # phantom host file add
      phantomHost
      # luantai server port
      masterPort
      # phantom server port 
      phantomPort
      # host address, now it is 127.0.0.1
      host
      # luantai root path
      rootPath
      # will injected js
      injectedJs.join ','
      # when test done, the val from "window" object pass to the plugin.
      feedbacks.join ','
    ]
    @phantom.stdout.pipe process.stdout
    @phantom.stderr.pipe process.stderr
    @server.once 'phantom_ready', done

  # /**
  #  * [fileTestDone description]
  #  * @return {[type]} [description]
  ##
  loadPhantomFile : ->
    if 0 is @fileList.length
      @startRunTest()
      return

    file = @fileList.shift()

    { phantomPort } = @

    pipe = eventPipe()
    pipe.on 'error', () ->

    ScriptLoader file, ( err, file ) ->

      body = JSON.stringify
        file   : file

      reqOptions =
        url    : "http://#{host}:#{phantomPort}/loadscript"
        method : 'POST'
        body   : body
        headers  :
          "Content-Type"   : "application/json"
          "Content-Length" : Buffer.byteLength body, 'utf8'

      request reqOptions, ->

  # /**
  #  * [startRunTest description]
  #  * @return {[type]} [description]
  ##
  startRunTest : ->
    { phantomPort } = @
    reqOptions =
      url : "http://#{host}:#{phantomPort}/runscript"

    request reqOptions, ->

  # /**
  #  * [beforeMountMiddleware plugin hooker]
  #  * @param  {Function} done [description]
  #  * @return {[type]}        [description]
  ##
  beforeMountMiddleware : ( done ) ->
    pipe = eventPipe()
    pipe.on 'error', ( error ) =>
      console.log '\u001b[31m before mount plugin middleware error \u001b[0m'
      { message, stack } = error
      console.log JSON.stringify { message, stack }
      @exit 1

    { pluginManager, server } = @
    plugins = pluginManager.getPlugin()
    for name, plugin of plugins
      beforeMountMiddleware = plugin.beforeMountMiddleware
      if beforeMountMiddleware
        beforeMountMiddleware = beforeMountMiddleware.bind plugin
        do ( name, plugin, beforeMountMiddleware ) ->
          pipe.lazy ->
            beforeMountMiddleware server.app, @

    pipe.lazy ->
      debug "all before plugin mount middleware done!"
      done null
    pipe.run()

  # /**
  #  * [afterMountMiddleware plugin hooker]
  #  * @param  {Function} done [description]
  #  * @return {[type]}        [description]
  ##
  afterMountMiddleware : ( done ) ->
    pipe = eventPipe()
    pipe.on 'error', ( error ) =>
      console.log '\u001b[31m after mount plugin middleware error \u001b[0m'
      { message, stack } = error
      console.log JSON.stringify { message, stack }
      @exit 1

    { pluginManager, server } = @
    plugins = pluginManager.getPlugin()
    for name, plugin of plugins
      afterMountMiddleware = plugin.afterMountMiddleware
      if afterMountMiddleware
        afterMountMiddleware = afterMountMiddleware.bind plugin
        do ( name, plugin, afterMountMiddleware ) ->
          pipe.lazy ->
            afterMountMiddleware server.app, @

    pipe.lazy ->
      debug "all after plugin mount middleware done!"
      done null
    pipe.run()

  # /**
  #  * [scriptLoader plugin hooker]
  #  * @param  {Function} done [description]
  #  * @return {[type]}        [description]
  ##
  scriptLoader : ( done ) ->

    { pluginManager } = @

    pipe = eventPipe()
    pipe.on 'error', done

    plugins = pluginManager.getPlugin()
    for name, plugin of plugins
      scriptLoader = plugin.scriptLoader
      if scriptLoader
        scriptLoader = scriptLoader.bind plugin
        do ( name, plugin, scriptLoader ) ->
          pipe.lazy ->
            scriptLoader @

          pipe.lazy ( fn ) ->
            ScriptLoader.register fn
            done null

    pipe.lazy ->
      debug 'all script loader register done!'
      done null

    pipe.run()

  # /**
  #  * [injecteJs plugin hooker]
  #  * @param  {Function} done [description]
  #  * @return {[type]}        [description]
  ##
  injectJs : ( done ) ->
    { pluginManager } = @

    pipe = eventPipe()
    pipe.on 'error', done

    plugins = pluginManager.getPlugin()
    for name, plugin of plugins
      injectJs = plugin.injectJs
      if injectJs
        injectJs = injectJs.bind plugin
        do ( name, plugin, injectJs ) ->
          pipe.lazy ->
            injectJs @

          pipe.lazy ( willInectedJs = [] ) ->
            injectedJs = injectedJs.concat willInectedJs
            done null

    pipe.lazy ->
      debug 'all script loader register done!'
      done null

    pipe.run()

  # /**
  #  * [feedback plugin hooker]
  #  * @param  {Function} done [description]
  #  * @return {[type]}        [description]
  ##
  feedback : ( done ) ->
    { pluginManager } = @

    pipe = eventPipe()
    pipe.on 'error', done

    plugins = pluginManager.getPlugin()
    for name, plugin of plugins
      { feedback } = plugin
      if feedback
        feedback   = feedback.bind plugin
        do ( name, plugin, feedback ) ->
          pipe.lazy ->
            feedback @

          pipe.lazy ( feedbackVal = [] ) ->
            feedbackMap[ name ] = feedbackVal
            feedbacks = feedbacks.concat feedbackVal
            done null

    pipe.lazy ->
      debug 'all script loader register done!'
      done null

    pipe.run()

  # /**
  #  * [finishTest plugin hooker]
  #  * @param  {Function} done [description]
  #  * @return {[type]}        [description]
  ##
  finishTest : ( feedback ) ->
    console.log '\u001b[92mall test done!\u001b[0m'

    try
      feedbackData = JSON.parse feedback
    catch e
      feedbackData = {}

    that = @
    { pluginManager } = @

    pipe = eventPipe()
    pipe.on 'error', ( error ) ->
      throw error

    plugins = pluginManager.getPlugin()
    for name, plugin of plugins
      finishTest   = plugin.finishTest
      if finishTest
        finishTest = finishTest.bind plugin

        do ( name, plugin, finishTest ) ->
          pipe.lazy ->
            feedbackVal = feedbackMap[ name ]
            if undefined isnt feedbackVal
              pluginFeedbackData = {}
              for val in feedbackVal
                pluginFeedbackData[ val ] = feedbackData[ val ]
              finishTest pluginFeedbackData, @

    pipe.lazy ->
      console.log 'luantai will exit!'
      that.exit()

    pipe.run()

  # /**
  #  * [exit exit everything]
  #  * @param  {[type]} code [description]
  #  * @return {[type]}      [description]
  ##
  exit : ( code ) ->
    process.exit code
    @phantom?.exit code

module.exports = 
  start : ( args ) ->
    new Stage args
