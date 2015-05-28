
console.log( 'this is test2 file' );

describe( 'tests333333', function() {
  it( 'test444444', function ( done ) {
    expect( document.getElementsByTagName( 'body' ).length ).to.be( 1 );
    done();
  } );
  it( 'test255555', function( done ) {
    console.log( 'test2' );
    done();
  } );
} );
