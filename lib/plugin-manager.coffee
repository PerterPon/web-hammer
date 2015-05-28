
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

pluginPool = {}

class PluginManager

  constructor : ( @options, plugins, done ) ->
    @initPlugins plugins, done

  initPlugins : ( plugins, done ) ->
    console.log plugins

    pipe = eventPipe()
    pipe.on 'error', done

    for plugin in plugins
      # build in plugins.
      try
        pluginPath = path.join __dirname, '../plugins/', plugin
        Plugin     = require pluginPath

      # node_modules plugin or self plugin
      try
        Plugin     = require plugin

      unless Plugin
        error      = new Error "plugin: #{plugin} was not exists!"
        return done error
      else
        debug "start to init plugin: #{plugin}"

        do ( plugin ) ->
          pluginIns = null
          pipe.lazy ->
            pluginIns = new Plugin {}, @
          pipe.lazy ->
            pluginPool[ plugin ] = pluginIns

    pipe.lazy ->
      done null

    pipe.run()

  getPlugin : ( name ) ->
    pluginPool[ name ] or pluginPool

module.exports = PluginManager
