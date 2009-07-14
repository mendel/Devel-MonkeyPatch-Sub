#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(t/lib);

use Test::Most tests => 2;
use Devel::StackTrace;

use Devel::MonkeyPatch::Sub qw(replace_sub wrap_sub);

my %lineno;

# test subs to replace
{
  package Foo;

  sub sub_to_replace
  {
    BEGIN { $lineno{sub_to_replace} = __LINE__ + 1; };
    return Devel::StackTrace->new;
  }

  sub sub_to_wrap
  {
    BEGIN { $lineno{sub_to_wrap} = __LINE__ + 1; };
    return Devel::StackTrace->new;
  }
}


{
  replace_sub Foo::sub_to_replace => sub {
    BEGIN { $lineno{sub_to_replace_replacement} = __LINE__ + 1; };
    return Devel::StackTrace->new;
  };

  BEGIN { $lineno{sub_to_replace_called} = __LINE__ + 1; };
  my $stacktrace = Foo::sub_to_replace();

  cmp_deeply(
    [ map { $_->as_string } $stacktrace->frames ],
    [
      re(qr{^Devel::StackTrace::new\('Devel::StackTrace'\) called at \Q$0\E line $lineno{sub_to_replace_replacement}$}),
      re(qr{^Foo::sub_to_replace at \Q$0\E line $lineno{sub_to_replace_called}$}),
    ],
    "Stacktrace from replaced sub is as expected"
  );
}

{
  wrap_sub Foo::sub_to_wrap => sub {
    BEGIN { $lineno{sub_to_wrap_replacement} = __LINE__ + 1; };
    return original::sub(@_);
  };

  BEGIN { $lineno{sub_to_wrap_called} = __LINE__ + 1; };
  my $stacktrace = Foo::sub_to_wrap();

  cmp_deeply(
    [ map { $_->as_string } $stacktrace->frames ],
    [
      re(qr{^Devel::StackTrace::new\('Devel::StackTrace'\) called at \Q$0\E line $lineno{sub_to_wrap}$}),
      re(qr{^Foo::sub_to_wrap at \Q$0\E line $lineno{sub_to_wrap_replacement}$}),
      re(qr{^Foo::sub_to_wrap at .*(?i:\bDevel\b.+\bMonkeyPatch\b.+\bSub\.pm) line \d+$}),
      re(qr{^Foo::sub_to_wrap at \Q$0\E line $lineno{sub_to_wrap_called}$}),
    ],
    "Stacktrace from wrapped sub is as expected"
  );
}
