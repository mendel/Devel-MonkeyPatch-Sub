#!perl -T

use Test::Most tests => 1;

BEGIN {
	use_ok( 'Devel::MonkeyPatch::Sub' );
}

diag( "Testing Devel::MonkeyPatch::Sub $Devel::MonkeyPatch::Sub::VERSION, Perl $], $^X" );
