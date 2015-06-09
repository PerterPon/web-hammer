
# /*
#   istanbul
# */
# Author: yuhan.wyh<yuhan.wyh@alibaba-inc.com>
# Create: Wed May 27 2015 07:24:48 GMT+0800 (CST)
# 

"use strict"

CodeInstrumenter = require 'istanbul/lib/instrumenter'

urlLib   = require 'url'

path     = require 'path'

istanbul = require 'istanbul'

FEED_BACK_VAL = '__luantaicoverageval2__'

# hack
CUBE_BACKUP   = '__test__'

class IstanbulPlugin

  constructor : ( @options, done ) ->
    { resDir, testDir, file, urlBase } = @options
    @options.file = @trans2AbsolutePath file
    resDir  ?= './res'
    testDir ?= './tests'
    urlBase ?= '/'

    @options.resDir  = resDir
    @options.testDir = testDir
    @options.urlBase = urlBase

    @instrumenter    = new CodeInstrumenter
      coverageVariable: FEED_BACK_VAL

    done null

  trans2AbsolutePath : ( files ) ->
    cwd = process.cwd()
    for file, idx in files
      if false is path.isAbsolute file
        file = path.join cwd, file

      files[ idx ] = file
    files

  feedback : ( done ) ->
    done null, [ FEED_BACK_VAL ]

  beforeMountMiddleware : ( app, done ) ->
    { file, urlBase, resDir, testDir } = @options
    urlBase  ?= '/'

    file      = JSON.parse JSON.stringify file
    cwd       = process.cwd()

    { instrumenter } = @
    app.use '/', ( req, res, next ) ->
      { url } = req
      { pathname }   = urlLib.parse url
      urlItem = pathname.split urlBase

      urlItem.shift()
      filePath   = urlItem.join urlBase

      # in case urlbase is '/'
      if '/' isnt filePath[ 0 ]
        filePath = "/#{filePath}"
        absolutePath = path.join cwd, resDir, filePath

      __end      = res.end.bind res
      res.end    = ( code ) ->
        { pathname, pathname } = urlLib.parse url, true
        extname  = path.extname pathname

        # only calculate script coverage
        if extname in [ '.coffee', '.js', '.jsx', '.cjsx' ]

          absolutePath = absolutePath.replace 'res/__test__', path.basename testDir

          # exculde the test file self.
          if absolutePath not in file
            code = instrumenter.instrumentSync code, pathname

        __end code

      next()

    done()

  finishTest : ( feedback, done ) ->
    cwd = process.cwd()

    istanbulCoverage = feedback[ FEED_BACK_VAL ]
    @onScriptDone istanbulCoverage
    done()

  onScriptDone : ( cov ) ->
    console.log """
    \u001b[93mstart generate coverage file...\u001b[0m
    """

    objectUtils = istanbul.utils

    lineForKey = ( summary, key ) ->
      metrics = summary[key]
      key    += '                   '.substring(0, 12 - key.length)
      color   = ''
      if metrics.pct < 60
        color = '\u001b[31m'
      else if metrics.pct < 75
        color = '\u001b[93m'
      else
        color = '\u001b[92m'
      result  = [ key , ':', metrics.pct + '%', '(', metrics.covered + '/' + metrics.total, ')'].join(' ')
      result  = color + result + '\u001b[0m'
      result

    summaries = []
    lists     = []

    for file of cov
      summaries.push objectUtils.summarizeFileCoverage cov[ file ]

    finalSummary = objectUtils.mergeSummaryObjects.apply null, summaries

    lists.push '=============================== Coverage summary ==============================='
    lists.push lineForKey finalSummary, 'statements'
    lists.push lineForKey finalSummary, 'branches'
    lists.push lineForKey finalSummary, 'functions'
    lists.push lineForKey finalSummary, 'lines'
    lists.push '================================================================================'
    lists.push '\n'
    console.log lists.join '\n'
    lists = lists.join '</br>'
    lists = lists
    .replace /\u001b\[31m/g, '<span class="fred">'
    .replace /\u001b\[93m/g, '<span class="fyelow">'
    .replace /\u001b\[92m/g, '<span class="fgreen">'
    .replace /\u001b\[0m/g,  '</span>'

    cwd = process.cwd()
    coverageDir = path.join cwd, './coverage'
    HtmlReport  = istanbul.Report.create 'html',
      verbose: false
      dir: coverageDir
      watermarks:
        statements : [ 50, 80 ]
        lines      : [ 50, 80 ]
        functions  : [ 50, 80 ]
        branches   : [ 50, 80 ]

    files = []

    { resDir } = @options

    newCode = {}
    for key, item of cov
      name = path.join cwd, resDir, key
      newCode[ name ] = item
      newCode[ name ].path = name
      files.push name

    cov = newCode
    cov = store :
      map : cov

    cov.fileCoverageFor = (key) ->
      cov.store.map[ key ]
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

module.exports = IstanbulPlugin
