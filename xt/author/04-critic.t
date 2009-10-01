use strict;
use warnings;

use Test::Most;

use FindBin;
use Path::Class;
use lib dir($FindBin::Bin)->subdir('lib')->stringify;

eval { require Test::Perl::Critic };
if ( $@ ) {
  plan tests => 1;
  fail( 'You must install Test::Perl::Critic to run 04critic.t' );
  exit;
}

my $rcfile = dir($FindBin::Bin)->file('04-critic.rc')->stringify;
Test::Perl::Critic->import( -profile => $rcfile );
all_critic_ok();
