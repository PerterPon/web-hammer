
var a = require( './test2' );

describe( 'tests', function() {
  it( 'test', function ( done ) {
    expect( document.getElementsByTagName( 'body' ).length ).to.be( 1 );
    done();
  } );
  it( 'test2', function( done ) {
    console.log( 'test2' );
    done();
  } );
} );
