
# /*
#   plugin-manager
# */
# Author: PerterPon<PerterPon@gmail.com>
# Create: Mon May 25 2015 11:47:08 GMT+0800 (CST)
# 

"use strict"

debug        = require( 'debug' )( 'luantai:plugin' )

path         = require 'path'

eventPipe    = require 'event-pipe'

scriptLoader = require './script-loader'

os           = require 'options-stream'

pluginPool   = {}

class PluginManager

  constructor : ( plugins, @parsedConfig, done ) ->
    @initPlugins plugins, done

  initPlugins : ( plugins = [], done ) ->

    { file } = @parsedConfig

    # hack for istanbul plugin
    cubeOptions = null

    pipe = eventPipe()
    pipe.on 'error', done
    for pluginItem in plugins
      for plugin, options of pluginItem

        # hack for istanbul plugin
        if 'cube' is plugin
          cubeOptions   = options

        # build in plugins.
        try
          pluginPath    = path.join __dirname, '../plugins/', plugin
          Plugin        = require pluginPath

        unless Plugin
          # node_modules plugin or self plugin
          try
            Plugin      = require plugin

        unless Plugin
          error         = new Error "plugin: #{plugin} was not exists!"
          return done error
        else

          do ( plugin, Plugin, options ) ->
            pluginIns   = null
            if 'istanbul' is plugin
              options   = os {}, options, cubeOptions, { file }
            pipe.lazy ->
              debug "start to init plugin: #{plugin}"
              pluginIns = new Plugin options, => process.nextTick @

            pipe.lazy ->
              pluginPool[ plugin ] = pluginIns
              @ null

    pipe.lazy ->

      process.nextTick done

    pipe.run()

  getPlugin : ( name ) ->
    pluginPool[ name ] or pluginPool

module.exports = PluginManager
