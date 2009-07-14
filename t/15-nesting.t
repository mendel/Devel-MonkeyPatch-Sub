#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(t/lib);

use Test::More tests => 4;

use Devel::MonkeyPatch::Sub qw(replace_sub wrap_sub);

# test subs to replace
{
  package Foo;

  sub sub_to_replace
  {
    return (caller(0))[3] . " (@_)";
  }

  sub sub_to_wrap
  {
    return (caller(0))[3] . " (@_)";
  }
}


{
  replace_sub Foo::sub_to_replace => sub {
    return (caller(0))[3] . " (@_) replacement#1";
  };

  my $new_sub = replace_sub Foo::sub_to_replace => sub {
    return (caller(0))[3] . " (@_) replacement#2";
  };

  is(Foo::sub_to_replace(1, 2, 3), "Foo::sub_to_replace (1 2 3) replacement#2",
    "Replacing replaced sub works"
  );

  is($new_sub, \&Foo::sub_to_replace,
    "Returns the reference to the new sub"
  );
}

{
  wrap_sub Foo::sub_to_wrap => sub {
    return original::sub(@_) . " replacement#1";
  };

  my $new_sub = wrap_sub Foo::sub_to_wrap => sub {
    return original::sub(@_) . " replacement#2";
  };

  is(Foo::sub_to_wrap(1, 2, 3), "Foo::sub_to_wrap (1 2 3) replacement#1 replacement#2",
    "Wrapping wrapped sub works"
  );

  is($new_sub, \&Foo::sub_to_wrap,
    "Returns the reference to the new sub"
  );
}
