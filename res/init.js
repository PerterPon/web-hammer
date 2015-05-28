
/*
  init
  Author: yuhan.wyh<yuhan.wyh@alibaba-inc.com>
  Create: Wed May 27 2015 06:28:00 GMT+0800 (CST)
*/

"use strict";

window.__phantomReady = function( options ) {

  var hostname = options.hostname;
  var port     = options.masterPort;
  var url      = 'http://' + hostname + ':' + port + '/phantom_ready';

  jsonP( url );

}

window.__loadScriptDone = function( options ) {
  var hostname = options.hostname;
  var port     = options.masterPort;
  var url      = 'http://' + hostname + ':' + port + '/loadscript_done';

  jsonP( url );
}

window.__runScriptDone = function( options, coverageObj ) {
  var hostname = options.hostname;
  var port     = options.masterPort;
  var url      = 'http://' + hostname + ':' + port + '/runscript_done';

  jsonP( url, 'POST', JSON.stringify( coverageObj ) );
}

function jsonP( url, method, data ) {
  if( void( 0 ) === method ) {
    method = 'GET';
  }
  var xhr = new XMLHttpRequest();
  
  // xhr.setRequestHeader( "Content-Type", "application/json" );
  xhr.open( method, url );
  xhr.send( data );

}