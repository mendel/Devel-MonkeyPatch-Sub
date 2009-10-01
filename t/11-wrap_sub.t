#!/usr/bin/env perl

use strict;
use warnings;

use lib qw(t/lib);

use Test::Most;

use Devel::MonkeyPatch::Sub qw(wrap_sub);

# test subs to wrap
{
  package Foo;

  sub new
  {
    my ($class, $id) = @_;

    return bless { id => $id }, $class;
  }

  sub method_to_wrap
  {
    my $self = shift;

    return (caller(0))[3] . " (id: $self->{id}) (@_)";
  }

  sub sub_to_wrap
  {
    return (caller(0))[3] . " (@_)";
  }
}


{
  my $id = rand 1000;

  my $foo = Foo->new($id);

  my $new_sub = wrap_sub Foo::method_to_wrap => sub {
    my $self = shift;

    return $self->original::method(@_) . " replacement";
  };

  is(
    $foo->method_to_wrap(1, 2, 3),
    "Foo::method_to_wrap (id: $id) (1 2 3) replacement",
    "Wrapping existing method works"
  );

  is($new_sub, \&Foo::method_to_wrap,
    "Returns the reference to the new sub"
  );
}

{
  my $id = rand 1000;

  my $foo = Foo->new($id);

  my $new_sub = wrap_sub Foo::method_to_create => sub {
    my $self = shift;

    return
      (
        $self->original::method(@_) ||
        (caller(0))[3] . " (id: $self->{id}) (@_)"
      ) . " replacement";
  };

  is(
    $foo->method_to_create(1, 2, 3),
    "Foo::method_to_create (id: $id) (1 2 3) replacement",
    "Creating new method works"
  );

  is($new_sub, \&Foo::method_to_create,
    "Returns the reference to the new sub"
  );
}

{
  my $new_sub = wrap_sub Foo::sub_to_wrap => sub {
    return original::sub(@_) . " replacement";
  };

  is(Foo::sub_to_wrap(1, 2, 3), "Foo::sub_to_wrap (1 2 3) replacement",
    "Wrapping existing sub works"
  );

  is($new_sub, \&Foo::sub_to_wrap,
    "Returns the reference to the new sub"
  );
}

{
  my $new_sub = wrap_sub Foo::sub_to_create => sub {
    return
      (
        original::sub(@_) ||
        (caller(0))[3] . " (@_)"
      ) . " replacement";
  };

  is(Foo::sub_to_create(1, 2, 3), "Foo::sub_to_create (1 2 3) replacement",
    "Creating new sub works"
  );

  is($new_sub, \&Foo::sub_to_create,
    "Returns the reference to the new sub"
  );
}

done_testing;
