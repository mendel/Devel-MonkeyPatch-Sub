package Devel::MonkeyPatch::Method;

#FIXME tests
# * stacktrace (subnames)
# * nesting
# * glob, glob ref, bareword of fully qualified name, bareword of relative name, string of fully qualified name, string of relative name
# * monkey-patching localized subs
# * wrapping existing method
# * wrapping existing non-method sub
# * creating new method
# * creating new non-method sub

use strict;
use warnings;

use 5.005;

=head1 NAME

Devel::MonkeyPatch::Method - Does the dirty work of monkey-patching subs for you.

=head1 SYNOPSIS

  monkeypatch Foo::Bar::some_sub => sub {
    my $self = shift;

    # do something

    return $self->original::method(@_);
  };

=head1 DISCLAIMER

This is ALPHA SOFTWARE. Use at your own risk. Features may change.

=head1 DESCRIPTION

Monkey-patching (or guerilla-patching or duck-punching or whatever you call it)
is the process of changing the code at runtime. The most prominent example is
replacing or wrapping methods of a class.

The usual idom to wrap a method 'in place':

  use Sub::Name;

  {
    no strict 'refs';
    no warnings 'redefine';

    my $orig_method = \&Foo::Bar::some_sub;
    *Foo::Bar::some_sub = subname 'Foo::Bar::some_sub' => sub {
      use strict;
      use warnings;

      my $self = shift;

      # do something

      return $self->$orig_method(@_);
    };
  }

Now, there are two problems with that:

=over

=item

It contains a lot of duplication (look, C<Foo::Bar::some_sub> is written 3
times) and the whole construct is a heavy boilerplate.

=item

If by accident you forget to switch back on the strictures and warnings, more
code is compiled and run under C<no strict 'refs'> (and C<no warnings
'redefine'>) than should be.

=back

This module tries to provide a more convenient and expressive interface for
wrapping methods 'in place'.

=head2 Differences from Aspect

The L<Aspect> module gives you a full-fledged AOP API where you can easily wrap
even dozens of subroutines in one call, with clear and nice syntax. It is much
more powerful and flexible when selecting what to wrap. Its model to run code
before or after the original method and modify values is more elegant. It even
tweaks L<CORE/caller> to make things look better. Still, it has two
disadvantages over L<Devel::MonkeyPatch::Method>:

=over

=item

With L<Aspect> you can run any code before or after the original method, but if
the original method throws an exception, you cannot catch it.

=item

With L<Aspect> the L<Aspect/before> and L<Aspect/after> advices are in separate
scopes than the call to the original method, so you cannot localize variables
during the call to the original variable.

=back

=head1 METHODS

=cut

our $VERSION = 0.01;

use base qw(Exporter);
our @EXPORT = qw(monkeypatch);

use Sub::Name;
use Symbol;

{
  package original;

  use strict;
  use warnings;

  our $sub;

=head2 next::method(LIST)

=head2 next::sub(LIST)

Calls the original method (ie. that was in effect before the monkey-patching)
with LIST as parameters. Returns the value returned by that method.

Should only be called from inside the subroutine that is installed by
monkey-patching.

=cut

  sub method
  {
    goto $sub if $sub;
  }

  no warnings 'once';
  *sub = \&method;
}

=head2 monkeypatch(NAME, CODE)
=head2 monkeypatch(GLOB, CODE)

Monkey-patches the given sub: replaces it with CODE.

The first parameter (NAME, GLOB) that identifies the sub to be replaced can
be a typeglob, a bareword or a string. If it is an unqualified name, it is
qualified it with the package name of the caller of L</monkeypatch>.

First it assigns a name (that is the same as the fully-qualified name of the
sub you're patching) to the sub using L<Sub::Name/subname>, then replaces the
symbol table code entry with CODE.

=cut

sub monkeypatch(*&)
{
  my ($glob, $new_sub) = @_;

  no strict 'refs';

  my $old_sub = *$glob{CODE};
  my $caller_pkg = (caller(0))[0];

  my $sub_name = Symbol::qualify(ref $glob ? *$glob : $glob, $caller_pkg);
  $sub_name =~ s/^\*//;

  subname $sub_name => $new_sub;

  {
    no warnings 'redefine';

    *$glob = subname $sub_name => sub {
      local $original::sub = $old_sub;
      return $new_sub->(@_);
    };
  }

  return $old_sub;
}

1;

__END__

=head1 EXAMPLES

  # add a new sub
  monkeypatch Foo::Bar::some_sub => sub {
    print "hello\n";
  };

  # wrap an existing method
  monkeypatch Foo::Bar::some_sub => sub {
    my $self = @_;

    $_[0] = 42;

    $self->original::method(@_);
  };

  # wrap an existing function
  monkeypatch Foo::Bar::some_sub => sub {
    $_[0] = 42;

    original::sub(@_);
  };


  # wrap a method by name
  monkeypatch 'Foo::Bar::some_sub' => sub {
    ...
  };

  # wrap a method by name (bareword)
  monkeypatch Foo::Bar::some_sub => sub {
    ...
  };

  # wrap a method by typeglob
  monkeypatch *Foo::Bar::some_sub => sub {
    ...
  };


  # wrap a method with dynamic scope
  local *Foo::Bar::some_sub = \&Foo::Bar::some_sub;
  monkeypatch *Foo::Bar::some_sub => sub {
    ...
  };


  # wrap a method in a context-preserving way (ie. it will work with
  # context-sensitive methods)
  use Context::Preserve;
  monkeypatch Foo::Bar::some_sub => sub {
    my $self = shift;
    my $args = \@_;

    return preserve_context { $self->original::method(@$args) }
      after => sub {
        my ($self) = @_;

        $self->set_something(42);
      };
  };

=head1 BUGS, CAVEATS AND NOTES

=head2 Performance

The current implementation uses 2 extra function calls compared to the
hand-coded version outlined in L</DESCRIPTION> (which in turn uses 1 extra
function call compared to the unwrapped function). You may or may not care
about that (anyways, probably you're not using this module in production code).

Not measured the actual effect of it yet.

=head2 Monkey-patching is next to evil

Monkey-patching can save the day (and did it several times), but is a dangerous
device. Extensively replacing/wrapping methods without serious reasons is not
considered to be a good practice. Try to avoid the temptation, and do not do it
unless you really have to. See eg.
L<http://en.wikipedia.org/wiki/Monkey_patching#Pitfalls>.

=head2 Use Aspect for AOP

If you want to do some real Aspect Oriented Programming (AOP) instead of just
wrapping some random method, you're better off with using the L<Aspect> module.
See also L</Differences from Aspect>.

=head1 SEE ALSO

L<Sub::Name>, L<Aspect>, L<Context::Preserve>

=head1 SUPPORT

Please submit bugs to the CPAN RT system at
http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Devel%3A%3AMonkeyPatch%3A%3AMethod
or via email at bug-devel-monkeypatch-method@rt.cpan.org.

=head1 AUTHOR

Norbert Buchmüller <norbi@nix.hu>

=head1 COPYRIGHT

Copyright 2009 Norbert Buchmüller.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
