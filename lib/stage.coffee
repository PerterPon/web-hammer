
# /*
#   stage
# */
# Author: yuhan.wyh<yuhan.wyh@alibaba-inc.com>
# Create: Mon May 25 2015 09:17:49 GMT+0800 (CST)
# 

"use strict"

require 'colors'

debug   = require( 'debug' )( 'luantai' )

connect = require 'connect'

phantom = require 'phantomjs'

path    = require 'path'

fs      = require 'fs'

http    = require 'http'

Server  = require './server'

util          = require './util'

PluginManager = require './plugin-manager'

childProcess  = require 'child_process'

eventPipe     = require 'event-pipe'

request       = require 'request'

CubePlugin    = require '../plugins/cube'

ScriptLoader  = require './script-loader'

istanbul      = require 'istanbul'

host          = '127.0.0.1'

injectedJs    = []

feedbacks     = []

feedbackMap   = {}

class Stage

  constructor : ( @args ) ->
    @clearSock()
    @generatePort()
    @parseConfig()

  # /**
  #  * [clearSock clear the domain sock files]
  #  * @return {[type]} [description]
  ##
  clearSock : ->
    phantom = path.join __dirname, '../out/phantom.sock'
    stage   = path.join __dirname, '../out/stage.sock'
    plugin  = path.join __dirname, '../out/plugin.sock'
    try
      fs.unlinkSync phantom
      fs.unlinkSync stage
      fs.unlinkSync plugin

  # /**
  #  * [generatePort now have two server, 1. master server. 2. phantom server.]
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

    # if pass an config file param.
    if config
      if false is path.isAbsolute config
        config = path.join __dirname, '../', config
      if false is fs.existsSync config
        error  = new Error "config file was not found: #{config}"
        throw err
        process.exit()
      else
        configItem = require config

    # or get the param form arguments
    else
      configItem = { file, plugins }

    @init configItem

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

    # init luantai server
    pipe.add ->
      debug 'start init server'
      that.initServer @

    # init phantom
    pipe.add ->
      debug 'start init phantom'
      that.initPhantom @

    # start file test
    pipe.add ->
      debug 'start file test'
      that.startFileTest file, @

    pipe.run()

  initPlugins : ( plugins = [], done ) ->
    @pluginManager = new PluginManager plugins, done

  initServer : ( done ) ->
    util.dotting 'trying to start luantai server'
    { masterPort } = @
    serverOption   =
      port : masterPort
    @server = new Server serverOption, done
    @server.on 'before_mount_middleware', @beforeMountMiddleware.bind @
    @server.on 'after_mount_middleware',  @afterMountMiddleware.bind  @

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

    @phantom    = childProcess.spawn phantomPath, [ phantomHost, masterPort, phantomPort, host, rootPath, injectedJs.join( ',' ), '123' ]
    @phantom.stdout.pipe process.stdout
    @phantom.stderr.pipe process.stderr
    @server.once 'phantom_ready', done

  # /**
  #  * [startFileTest description]
  #  * @return {[type]} [description]
  ##
  startFileTest : ( filePath ) ->
    console.log '\u001b[92mphantom start success!\u001b[0m'

    { rule }   = @args
    rule      ?= '.*'

    if false is fs.existsSync filePath
      error    = new Error "test file: #{filePath} was not exists!"
      throw error

    if false is path.isAbsolute filePath
      filePath = path.join __dirname, '../', filePath
    else
      filePath = filePath

    if true is fs.lstatSync( filePath ).isDirectory()
      files    = util.iterateFolder filePath, rule
    else
      files    = [ filePath ]

    @fileList  = files

    @fileTestDone()
    @server.on 'loadscript_done', @fileTestDone.bind @

  # /**
  #  * [fileTestDone description]
  #  * @return {[type]} [description]
  ##
  fileTestDone : ->
    console.log 'fileTestDone'
    if 0 is @fileList.length
      @startRunTest()
      return

    file = @fileList.shift()

    { phantomPort } = @

    ScriptLoader file, ( err, file ) ->

      body = JSON.stringify
        file : file

      reqOptions =
        url    : "http://#{host}:#{phantomPort}/loadscript"
        method : 'POST'
        body   : body
        headers :
          "Content-Type"   : "application/json"
          "Content-Length" : Buffer.byteLength body, 'utf8'

      request reqOptions, ->

  startRunTest : ->
    { phantomPort } = @
    reqOptions =
      url : "http://#{host}:#{phantomPort}/runscript"

    @server.on 'runscript_done', @onScriptDone.bind @

    request reqOptions, ->

  onScriptDone : ( coverageObj ) ->
    console.log """
    \u001b[92mall test done!
    \u001b[93mstart generate coverage file...\u001b[0m
    """

    objectUtils = istanbul.utils

    cov         = JSON.parse coverageObj

    lineForKey = ( summary, key ) ->
      metrics = summary[key]
      key += '                   '.substring(0, 12 - key.length)
      color = ''
      if metrics.pct < 60
        color = '\u001b[31m'
      else if metrics.pct < 75
        color = '\u001b[93m'
      else
        color = '\u001b[92m'
      result = [ key , ':', metrics.pct + '%', '(', metrics.covered + '/' + metrics.total, ')'].join(' ')
      result = color + result + '\u001b[0m'
      result

    summaries = []
    lists = []
    for file of cov
      summaries.push objectUtils.summarizeFileCoverage cov[ file ]

    finalSummary = objectUtils.mergeSummaryObjects.apply null, summaries

    lists.push '=============================== Coverage summary ==============================='
    lists.push lineForKey(finalSummary, 'statements')
    lists.push lineForKey(finalSummary, 'branches')
    lists.push lineForKey(finalSummary, 'functions')
    lists.push lineForKey(finalSummary, 'lines')
    lists.push '================================================================================'
    lists.push '\n'
    console.log lists.join '\n'
    lists = lists.join '</br>'
    lists = lists
    .replace(/\u001b\[31m/g, '<span class="fred">')
    .replace(/\u001b\[93m/g, '<span class="fyelow">')
    .replace(/\u001b\[92m/g, '<span class="fgreen">')
    .replace(/\u001b\[0m/g, '</span>')

    cwd = process.cwd()

    coverageDir = path.join cwd, './coverage'

    HtmlReport = istanbul.Report.create 'html',
      verbose: false
      dir: coverageDir
      watermarks:
        statements: [ 50, 80 ]
        lines: [ 50, 80 ]
        functions: [ 50, 80 ]
        branches: [ 50, 80 ]

    files = []
    for key of cov
      cov[path.join __dirname, '../res/', key] = cov[ key ]
      cov[path.join __dirname, '../res/', key].path = path.join __dirname, '../res/', key
      files.push path.join __dirname, '../res/', key

    cov = store :
      map : cov
    cov.fileCoverageFor = (key) ->
      cov.store.map[key]
    cov.files = () ->
      files

    for key of cov.store.map
      lastline = null
      Object.keys(cov.store.map[key].l).forEach (lineNumber) ->
        lastline = lineNumber
      if lastline
        delete cov.store.map[key].l[lastline]

    HtmlReport.writeReport cov, true
    console.log "coverage file was saved in #{coverageDir}"
    @exit()

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
  injecteJs : ( done ) ->
    { pluginManager } = @

    pipe = eventPipe()
    pipe.on 'error', done

    plugins = pluginManager.getPlugin()
    for name, plugin of plugins
      injecteJs = plugin.injecteJs
      if injecteJs
        injecteJs = injecteJs.bind plugin
        do ( name, plugin, injecteJs ) ->
          pipe.lazy ->
            injecteJs @

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
      feedback   = plugin.feedback
      if feedback
        feedback = feedback.bind plugin
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
  finishTest : ( feedbackData, done ) ->
    { pluginManager } = @

    pipe = eventPipe()
    pipe.on 'error', done

    plugins = pluginManager.getPlugin()
    for name, plugin of plugins
      finishTest   = plugin.finishTest
      if finishTest
        finishTest = finishTest.bind plugin
        do ( name, plugin, feedback ) ->
          pipe.lazy ->
            feedbackVal = feedbackMap[ name ]
            if undefined isnt feedbackVal
              pluginFeedbackData = {}
              for val in feedbackVal
                pluginFeedbackData[ val ] = feedbackData[ val ]
              finishTest pluginFeedbackData, @

    pipe.lazy ->
      done null

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
