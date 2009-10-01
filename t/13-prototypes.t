#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;

use FindBin;
use Path::Class;
use lib dir($FindBin::Bin)->subdir('lib')->stringify;

use Devel::MonkeyPatch::Sub qw(replace_sub);

# test subs to replace
{
  package Foo;

  sub sub_to_replace($&*)
  {
    return (caller(0))[3] . " (@_)";
  }
}


{
  replace_sub *Foo::sub_to_replace => sub {
    return (caller(0))[3] . " (@_) replacement";
  };

  is(prototype(\&Foo::sub_to_replace), '$&*',
    "Prototype of the original sub is kept"
  );

  like(
    Foo::sub_to_replace(42, sub { 42 }, *Devel::MonkeyPatch::Sub::VERSION),
    qr/^Foo::sub_to_replace \(42 CODE\([^)]+\) GLOB\([^)]+\)\) replacement$/,
    "The replacement function seems to work according to old the prototype"
  );
}

done_testing;
