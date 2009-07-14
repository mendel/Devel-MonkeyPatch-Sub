#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(t/lib);

use Test::More tests => 4;

use Devel::MonkeyPatch::Sub qw(replace_sub);

# test subs to wrap
{
  package Foo;

  sub new
  {
    my ($class, $id) = @_;

    return bless { id => $id }, $class;
  }

  sub method_to_replace
  {
    my $self = shift;

    return +(caller(0))[3] . " (id: $self->{id}) (@_)";
  }

  sub sub_to_replace
  {
    return +(caller(0))[3] . " (@_)";
  }
}


{
  my $id = rand 1000;

  my $foo = Foo->new($id);

  replace_sub Foo::method_to_replace => sub {
    my $self = shift;

    return +(caller(0))[3] . " (id: $self->{id}) (@_) replacement";
  };

  is(
    $foo->method_to_replace(1, 2, 3),
    "Foo::method_to_replace (id: $id) (1 2 3) replacement",
    "Replacing existing method works"
  );
}

{
  my $id = rand 1000;

  my $foo = Foo->new($id);

  replace_sub Foo::method_to_create => sub {
    my $self = shift;

    return +(caller(0))[3] . " (id: $self->{id}) (@_) replacement";
  };

  is(
    $foo->method_to_create(1, 2, 3),
    "Foo::method_to_create (id: $id) (1 2 3) replacement",
    "Creating new method works"
  );
}

{
  replace_sub Foo::sub_to_replace => sub {
    return +(caller(0))[3] . " (@_) replacement";
  };

  is(Foo::sub_to_replace(1, 2, 3), "Foo::sub_to_replace (1 2 3) replacement",
    "Replacing existing sub works"
  );
}

{
  replace_sub Foo::sub_to_create => sub {
    return +(caller(0))[3] . " (@_) replacement";
  };

  is(Foo::sub_to_create(1, 2, 3), "Foo::sub_to_create (1 2 3) replacement",
    "Creating new sub works"
  );
}

