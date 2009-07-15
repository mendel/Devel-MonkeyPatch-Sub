#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(t/lib);

use Test::Most tests => 6;

use Devel::MonkeyPatch::Sub qw(wrap_sub);

# test subs to replace
{
  {
    package Foo;

    sub sub_glob
    {
      return (caller(0))[3];
    }

    sub sub_glob_ref
    {
      return (caller(0))[3];
    }

    sub sub_bareword_fully_qualified
    {
      return (caller(0))[3];
    }

    sub sub_string_fully_qualified
    {
      return (caller(0))[3];
    }

  }

  sub sub_bareword_relative
  {
    return (caller(0))[3];
  }

  sub sub_string_relative
  {
    return (caller(0))[3];
  }
}


{
  wrap_sub *Foo::sub_glob => sub {
    return original::sub(@_) . " replacement";
  };

  is(Foo::sub_glob(), "Foo::sub_glob replacement",
    "Using glob to specify target works"
  );
}

{
  wrap_sub \*Foo::sub_glob_ref => sub {
    return original::sub(@_) . " replacement";
  };

  is(Foo::sub_glob_ref(), "Foo::sub_glob_ref replacement",
    "Using glob ref to specify target works"
  );
}

{
  wrap_sub Foo::sub_bareword_fully_qualified => sub {
    return original::sub(@_) . " replacement";
  };

  is(
    Foo::sub_bareword_fully_qualified(),
    "Foo::sub_bareword_fully_qualified replacement",
    "Using fully-qualified bareword to specify target works"
  );
}

{
  wrap_sub sub_bareword_relative, sub {
    return original::sub(@_) . " replacement";
  };

  is(
    sub_bareword_relative(),
    "main::sub_bareword_relative replacement",
    "Using relative bareword to specify target works"
  );
}

{
  wrap_sub 'Foo::sub_string_fully_qualified' => sub {
    return original::sub(@_) . " replacement";
  };

  is(
    Foo::sub_string_fully_qualified(),
    "Foo::sub_string_fully_qualified replacement",
    "Using fully-qualified string to specify target works"
  );
}

{
  wrap_sub 'sub_string_relative' => sub {
    return original::sub(@_) . " replacement";
  };

  is(
    sub_string_relative(),
    "main::sub_string_relative replacement",
    "Using relative string to specify target works"
  );
}
