
# /*
#   plugin-manager
# */
# Author: yuhan.wyh<yuhan.wyh@alibaba-inc.com>
# Create: Mon May 25 2015 11:47:08 GMT+0800 (CST)
# 

"use strict"

debug      = require( 'debug' )( 'luantai:plugin' )

path       = require 'path'

eventPipe  = require 'event-pipe'

scriptLoader = require './script-loader'

pluginPool   = {}

class PluginManager

  constructor : ( @options, done ) ->
    { plugins } = @options
    @initPlugins plugins, done

  initPlugins : ( plugins = {}, done ) ->

    plugins = [ 
      {
        'istanbul' : {}
      }
      {
        'cube' :
          dir : '../'
      }
    ]

    pipe = eventPipe()
    pipe.on 'error', done
    for pluginItem in plugins
      for plugin, options of pluginItem

        # build in plugins.
        try
          pluginPath = path.join __dirname, '../plugins/', plugin
          Plugin     = require pluginPath

        unless Plugin
          # node_modules plugin or self plugin
          try
            Plugin     = require plugin

        unless Plugin
          error      = new Error "plugin: #{plugin} was not exists!"
          return done error
        else

          do ( plugin, Plugin ) ->
            pluginIns   = null
            pipe.lazy ->
              debug "start to init plugin: #{plugin}"
              pluginIns = new Plugin options, => process.nextTick @

            pipe.lazy ->
              if pluginIns.scriptLoader
                scriptLoader.register pluginIns.scriptLoader()
              pluginPool[ plugin ] = pluginIns
              @ null

    pipe.lazy ->
      done null

    pipe.run()

  getPlugin : ( name ) ->
    pluginPool[ name ] or pluginPool

module.exports = PluginManager
