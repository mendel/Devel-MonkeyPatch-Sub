#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(t/lib);

use Test::Most;

use Devel::MonkeyPatch::Sub qw(replace_sub wrap_sub);

# test subs to replace
{
  package Foo;

  sub sub_to_replace
  {
    return (caller(0))[3] . " (@_)";
  }

  sub sub_to_replace_and_alias
  {
    return (caller(0))[3] . " (@_)";
  }

  sub sub_to_wrap
  {
    return (caller(0))[3] . " (@_)";
  }

  sub sub_to_wrap_and_alias
  {
    return (caller(0))[3] . " (@_)";
  }

  sub other_sub
  {
    return (caller(0))[3] . " (@_)";
  }
}


{
  {
    local *Foo::sub_to_replace = \&Foo::sub_to_replace;

    my $new_sub = replace_sub Foo::sub_to_replace => sub {
      return (caller(0))[3] . " (@_) replacement";
    };

    is(Foo::sub_to_replace(1, 2, 3), "Foo::sub_to_replace (1 2 3) replacement",
      "Replacing localized sub works"
    );

    is($new_sub, \&Foo::sub_to_replace,
      "Returns the reference to the new sub"
    );
  }

  is(Foo::sub_to_replace(1, 2, 3), "Foo::sub_to_replace (1 2 3)",
    "Replaced localized sub is restored when the scope is left"
  );
}

{
  {
    no warnings 'redefine';
    local *Foo::sub_to_replace_and_alias = \&Foo::other_sub;

    my $new_sub = replace_sub Foo::sub_to_replace_and_alias => sub {
      return (caller(0))[3] . " (@_) replacement";
    };

    is(Foo::sub_to_replace_and_alias(1, 2, 3), "Foo::sub_to_replace_and_alias (1 2 3) replacement",
      "Replacing localized+aliased sub works"
    );

    is($new_sub, \&Foo::sub_to_replace_and_alias,
      "Returns the reference to the new sub"
    );
  }

  is(Foo::sub_to_replace_and_alias(1, 2, 3), "Foo::sub_to_replace_and_alias (1 2 3)",
    "Replaced localized+aliased sub is restored when the scope is left"
  );
}


{
  {
    local *Foo::sub_to_wrap = \&Foo::sub_to_wrap;

    my $new_sub = wrap_sub Foo::sub_to_wrap => sub {
      return original::sub(@_) . " replacement";
    };

    is(Foo::sub_to_wrap(1, 2, 3), "Foo::sub_to_wrap (1 2 3) replacement",
      "Replacing localized sub works"
    );

    is($new_sub, \&Foo::sub_to_wrap,
      "Returns the reference to the new sub"
    );
  }

  is(Foo::sub_to_wrap(1, 2, 3), "Foo::sub_to_wrap (1 2 3)",
    "Replaced localized sub is restored when the scope is left"
  );
}

{
  {
    no warnings 'redefine';
    local *Foo::sub_to_wrap_and_alias = \&Foo::other_sub;

    my $new_sub = wrap_sub Foo::sub_to_wrap_and_alias => sub {
      return original::sub(@_) . " replacement";
    };

    is(Foo::sub_to_wrap_and_alias(1, 2, 3), "Foo::other_sub (1 2 3) replacement",
      "Replacing localized+aliased sub works"
    );

    is($new_sub, \&Foo::sub_to_wrap_and_alias,
      "Returns the reference to the new sub"
    );
  }

  is(Foo::sub_to_wrap_and_alias(1, 2, 3), "Foo::sub_to_wrap_and_alias (1 2 3)",
    "Replaced localized+aliased sub is restored when the scope is left"
  );
}

done_testing;
