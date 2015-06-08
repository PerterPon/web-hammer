
"use strict";

var webserver = require( 'webserver' );
var webpage   = require( 'webpage' );
var system    = require( 'system' );
var fs        = require( 'fs' );

var masterPort  = phantom.args[ 0 ];
var phantomPort = phantom.args[ 1 ];
var hostname    = phantom.args[ 2 ];
var dirName     = phantom.args[ 3 ];
var injectedJs  = phantom.args[ 4 ];
var feedbacks   = phantom.args[ 5 ].split( ',' );

var luantaiParams = {
  masterPort  : masterPort,
  phantomPort : phantomPort,
  hostname    : hostname,
  dirName     : dirName
};

/**
 * [page. The page object which run the codes.]
 * @type {[type]}
 */
var page = null;

/**
 * [server. The phantom server.]
 * @type {[type]}
 */
var server = null;

/**
 * [injectionCode the code which will inject to page.]
 * @type {[type]}
 */
var injectionCode = [];

/**
 * [coverage description]
 * @type {Object}
 */
var coverage = {};

initServer();

initPage();

/**
 * [injectJs when init phantom, inject this js]
 * @param  {[type]} page [description]
 * @return {[type]}      [description]
 */
function injectJs( page ) {
  page.injectJs( dirName + '/res/console.js' );
  page.injectJs( dirName + '/node_modules/mocha/mocha.js' );
  page.injectJs( dirName + '/res/extensions.js' );
  page.injectJs( dirName + '/node_modules/expect.js/index.js' );
  page.injectJs( dirName + '/res/init.js' );
  var willInjectJs = injectedJs.split( ',' );
  var i = 0;
  for ( i = 0; i < willInjectJs.length; i ++ ) {
    page.injectJs( willInjectJs[ i ] );
  }
}

/**
 * [initPage init the page object, prepare to open the html page.]
 * @return {[type]} [description]
 */
function initPage () {

  page = webpage.create();

  var that = this;

  // when page was initialized, inject the framework to the page.
  page.onInitialized = function() {

  };

  page.onLoadFinished = function() {
    // inject unit test framework.
    injectJs( page );

  }

  // page closing.
  page.onClosing = function ( closingPage ) {
    console.log( 'page:' + closingPage.url + ' closing!' );
  };

  // on console messages
  page.onConsoleMessage = function ( message ) {
    system.stdout.writeLine( message );
  };

  // when resource load error
  page.onResourceError = function ( resourceError ) {
    console.error( 'Unable to load resource (#' + resourceError.id + 'URL:' + resourceError.url + ')' );
    console.error( 'Error code: ' + resourceError.errorCode + '. Description: ' + resourceError.errorString );
  };

  // when load resouce timeout
  page.onResourceTimeout = function ( request ) {
    console.warn( 'load resource timeout: ' + request.id + ': ' + JSON.stringify( request ) );
  };

  // when javascript script got some error.
  page.onError = function ( msg, trace ) {
    var msgStack = [ 'ERROR: ' + msg ];

    if ( trace && trace.length ) {
      msgStack.push( 'TRACE:' );
      trace.forEach( function( t ) {
        msgStack.push( ' -> ' + t.file + ': ' + t.line + ( t.function ? ' (in function "' + t.function +'")' : '' ) );
      } );
    }

    console.error( msgStack.join( '\n' ) );
  };

  page.onCallback = function( data ) {

    if( 'luantai.scriptload.done' === data ) {
      loadscriptDone();
    } else if ( true === data[ 'luantai.scriptrun.done' ] ) {
      runScriptDone();
    }

    return true;
  };

  page.open( 'http://' + hostname + ':' + masterPort + '/blank', function() {

    // init feedback items
    page.evaluate( function ( feedbacks ) {
      var feedbackItems = feedbacks;
      var i = null;
      for( var i = 0; i < feedbackItems.length; i ++ ) {
        if( void( 0 ) === window[ feedbackItems[ i ] ] ) {
          window[ feedbackItems[ i ] ] = {};
        }
      }
    }, feedbacks );

    // call stage that phantom was ready.
    phantomReady();
  } );

}

/**
 * [initServer init the phantom server]
 * @return {[type]} [description]
 */
function initServer () {
  server  = webserver.create();
  try {
    var service = server.listen( hostname + ':' + phantomPort, onRequestComing );  
  } catch( e ) {
    console.log( e );
  }
  

  if ( service ) {
    console.log( 'phantom server was running on port: ' + phantomPort );
  } else {
    console.log( '\u001b[31mphantom server start with error!\u001b[0m' );
    exit();
  }
}

/**
 * [onRequestComing when phantom got an request]
 * @param  {[type]} req [description]
 * @param  {[type]} res [description]
 * @return {[type]}     [description]
 */
function onRequestComing( req, res ) {
  var method = req.method;
  var url    = req.url;
  var action = url.split( '/' ).pop();

  if ( 'POST' === method.toUpperCase() || 'PUT' === method.toUpperCase() ) {
    var data = JSON.parse( req.post );  
  }

  // load script
  if( 'loadscript' === action ) {
    evaluate( data );

  // load scriot done, start run script
  } else if ( 'runscript' === action ) {
    runMocha();

  // init feed back informations
  } else if ( 'initfeedback' === action ) {
    initFeedBack();
  }

  res.statusCode = 200;
  res.headers = {
    Cache          : "no-cache",
    "Content-Type" : "text/plain;charset=utf-8"
  }

  res.write( JSON.stringify( {}, null, 4 ) );
  res.close();
}

/**
 * [evaluate description]
 * @param  {[type]} data [description]
 * @return {[type]}      [description]
 */
function evaluate( data ) {

  var script  = data.file;
  var name    = data.name;
  var target  = data.target;
  var next    = data.next;
  var timeout = data.timeout;

  if ( void( 0 ) === target ) {
    target    = 'http://' + hostname + ':' + masterPort + '/blank';
  }

  page.evaluate( function( script ) {

    // set mocha ui.
    mocha.ui( 'bdd' );

    // build mocha code
    !( new Function( script ) )();
    
  }, script );

}

function loadscriptDone() {
  page.evaluate( function( luantaiParams ) {
    window.__loadScriptDone( luantaiParams );
  }, luantaiParams );
}

/**
 * [runMocha run mocha]
 * @return {[type]} [description]
 */
function runMocha() {

  page.evaluate( function( reporter ) {
    try {
      mocha.setup( {
        reporter: reporter || Mocha.reporters.Custom
      } );
    } catch ( e ) {}
  }, 'spec' );
  page.evaluate( mochaRunner );

}

/**
 * [mochaRunner description]
 * @return {[type]} [description]
 */
function mochaRunner() {
  console.log( '\u001b[93mtest start...\u001b[0m' );

  var runner = mocha.run();
  runner.on( 'end', function() {
    window.callPhantom( { 'luantai.scriptrun.done' : true } );
  } );
}

function runScriptDone() {
  page.evaluate( function( luantaiParams, feedbacks ) {
    var feedBackData = {};
    var i = null;
    var itemName = null;
    for( i = 0; i < feedbacks.length; i ++ ) {
      itemName   = feedbacks[ i ];
      feedBackData[ itemName ] = window[ itemName ];
    }
    window.__runScriptDone( luantaiParams, feedBackData );
  }, luantaiParams, feedbacks );
}

/**
 * [phantomReady when phantom was ready, notify the stage.]
 * @return {[type]} [description]
 */
function phantomReady() {
  page.evaluate( function( luantaiParams ) {
    window.__phantomReady( luantaiParams );
  }, luantaiParams );
}

/**
 * [reset description]
 * @return {[type]} [description]
 */
function reset() {
  page   = null;
  server = null;
  injectionCode = [];
  coverage      = {};
}

/**
 * [exit exit this mission.]
 * @return {[type]} [description]
 */
function exit() {
  phantom.exit();
  page.open( 'http://' + hostname + ':' + masterPort + '/exit' );
}
