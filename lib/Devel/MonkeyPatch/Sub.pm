package Devel::MonkeyPatch::Sub;

#FIXME tests
# * glob, glob ref, bareword of fully qualified name, bareword of relative name, string of fully qualified name, string of relative name
# * creating new method
# * creating new non-method sub
# * replacing method
# * replacing non-method sub
# * wrapping existing method
# * wrapping existing non-method sub
# * monkey-patching localized subs
# * nesting
# * stacktrace (subnames)
# * prototypes

use strict;
use warnings;

use 5.005;

=head1 NAME

Devel::MonkeyPatch::Sub - Does the dirty work of monkey-patching subs for you.

=head1 SYNOPSIS

  # wrap a method
  wrap_sub Foo::Bar::some_sub => sub {
    my $self = shift;

    # do something

    return $self->original::method(@_);
  };

  # install a new method
  replace_sub Foo::Bar::some_sub => sub {
    my $self = shift;

    # do something
  };

=head1 DISCLAIMER

This is ALPHA SOFTWARE. Use at your own risk. Features may change.

=head1 DESCRIPTION

Monkey-patching (or guerilla-patching or duck-punching or whatever you call it)
is the process of changing the code at runtime. The most prominent example is
replacing or wrapping methods of a class.

=head2 Hand-coded monkey-patching

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
wrapping (or simply adding/replacing) methods 'in place'.

=head2 Differences from Aspect and Hook::LexWrap

The L<Aspect> module gives you a full-fledged AOP API where you can easily wrap
even dozens of subroutines in one call, with clear and nice syntax. It is much
more powerful and flexible when selecting what to wrap. Its model to run code
before or after the original method and modify values is more elegant. It even
tweaks L<CORE/caller> to make things look better. Still, it has these
disadvantages over L<Devel::MonkeyPatch::Sub>:

=over

=item

With L<Aspect> you can run any code before or after the original method, but if
the original method throws an exception, you cannot currently catch it.

=item

With L<Aspect> the L<Aspect/before> and L<Aspect/after> advices are in separate
scopes than the call to the original method, so you cannot localize variables
for the duration of the call to the original subroutine.

=item

With L<Aspect> you cannot currently add a new method to a class.

=back

L<Devel::MonkeyPatch::Sub> is also more lightweight than L<Aspect>.

Using L<Hook::LexWrap> (which L<Aspect> is based on) shares the above
disadvantages with L<Aspect>.

=head1 EXPORTS

No methods are exported by default. You can import L<replace_sub> and
L</wrap_sub> if you want to.

L</original::method> and L<original::sub> are unconditionally created in the
L<original> package (not an original idea to use that namespace for anything
sensible, so I hope it won't clash with your code).

=head1 METHODS

=cut

our $VERSION = 0.01;

use base qw(Exporter);
our @EXPORT_OK = qw(replace_sub wrap_sub);

use Sub::Prototype;
use Sub::Name;
use Symbol;

{
  package original;

  use strict;
  use warnings;

  our $sub;

=head2 original::method(LIST)

Calls the original method (ie. that was in effect before the monkey-patching)
with LIST as parameters. Returns the value returned by that method.

Should only be called from inside the subroutine that is installed by
L</wrap_sub> (otherwise the behaviour is undefined).

=cut

  sub method
  {
    goto $sub if $sub;
  }


=head2 original::sub(LIST)

The same as L</original::method>.

=cut

  {
    no warnings 'once';
    *sub = \&method;
  }
}

#
# _subname(GLOB)
#
# Returns the fully-qualified name of the symbol referenced by GLOB.
#
# If it is an unqualified name, it is qualified it with the package name of the
# second caller of L</_subname>.
#
sub _subname(*)
{
  my ($glob) = @_;

  my $sub_name = Symbol::qualify(ref $glob ? *$glob : $glob, caller(1));
  $sub_name =~ s/^\*//;

  return $sub_name;
}


=head2 replace_sub(NAME|GLOB, CODE)

Replaces the subroutine identified by NAME|GLOB with CODE (if a sub with that
name alreay existed), or installs CODE as a new sub with the given name (if no
such sub existed before).

The first parameter (NAME or GLOB) that identifies the sub to be
replaced/created can be a typeglob, a bareword or a string. If it is an
unqualified name, it is qualified with the package name of the caller of
L</replace_sub>.

All the subroutines installed will have the fully qualified name of the
subroutine they're replacing assigned to via L<Sub::Name/subname>. The
prototype of the new subroutine is set to that of the original subroutine (if
it had any prototype).

Returns: reference to the new sub (ie. what GLOB|NAME will refer to after the
patching)

Note: you cannot not call C<< $self->original::method(@_) >> from subroutines
installed via L</replace_sub>. (The behaviour of L</original::method> is
undefined in subroutines created via L</replace_sub>.) If you need
L</original::method>, use L</wrap_sub> instead.

=cut

#FIXME refactor common parts of replace_sub and wrap_sub to _wrap_sub(*&$) (where 3rd param is $setup_wrapper)
sub replace_sub(*&)
{
  my ($glob, $new_sub) = @_;

  my $sub_name = _subname($glob);

  subname $sub_name => $new_sub;

  {
    no strict 'refs';
    no warnings 'redefine';

    my $old_sub = *$glob{CODE};
    my $wrapper_sub = $new_sub;

    if (defined $old_sub && defined (my $prototype = prototype($old_sub))) {
      set_prototype $new_sub => $prototype;
    }

    return *$sub_name = $wrapper_sub;
  }
}


=head2 wrap_sub(NAME|GLOB, CODE)

Replaces the subroutine identified by NAME|GLOB with CODE (if a sub with that
name alreay existed), or installs CODE as a new sub with the given name (if no
such sub existed before).

You can call the original sub from CODE via the C<< $self->original::method(@_)
>> syntax (see L</original::method>). If the sub did not exist before wrapping
it, C<< $self->original::method(@_) >> will be simply a no-op.

The first parameter (NAME or GLOB) that identifies the sub to be
replaced/created can be a typeglob, a bareword or a string. If it is an
unqualified name, it is qualified with the package name of the caller of
L</replace_sub>.

All the subroutines installed will have the fully qualified name of the
subroutine they're replacing assigned to via L<Sub::Name/subname>. The
prototype of the new subroutine is set to that of the original subroutine (if
it had any prototype).

Returns: reference to the new sub (ie. what GLOB|NAME will refer to after the
patching)

Note: If you do not intend to call C<< $self->original::method(@_) >> from CODE,
you should use the faster L</replace_sub> instead.

=cut

sub wrap_sub(*&)
{
  my ($glob, $new_sub) = @_;

  my $sub_name = _subname($glob);

  subname $sub_name => $new_sub;

  {
    no strict 'refs';
    no warnings 'redefine';

    my $old_sub = *$sub_name{CODE};
    my $wrapper_sub = subname $sub_name => sub {
      local $original::sub = $old_sub;
      return $new_sub->(@_);
    };

    if (defined (my $prototype = prototype($old_sub))) {
      set_prototype $wrapper_sub => $prototype;
    }

    return *$sub_name = $wrapper_sub;
  }
}

1;

__END__

=head1 EXAMPLES

  # create or replace a new sub
  replace_sub Foo::Bar::some_sub => sub {
    print "hello\n";
  };

  # wrap an existing method
  wrap_sub Foo::Bar::some_sub => sub {
    my $self = @_;

    $_[0] = 42;

    $self->original::method(@_);
  };

  # wrap an existing function
  wrap_sub Foo::Bar::some_sub => sub {
    $_[0] = 42;

    original::sub(@_);
  };


  # wrap a method by name
  wrap_sub 'Foo::Bar::some_sub' => sub {
    ...
  };

  # wrap a method by name (bareword)
  wrap_sub Foo::Bar::some_sub => sub {
    ...
  };

  # wrap a method by typeglob
  wrap_sub *Foo::Bar::some_sub => sub {
    ...
  };


  # wrap a method with dynamic scope
  local *Foo::Bar::some_sub = \&Foo::Bar::some_sub;
  wrap_sub *Foo::Bar::some_sub => sub {
    ...
  };


  # wrap a method in a context-preserving way (ie. it will work with
  # context-sensitive methods)
  use Context::Preserve;
  wrap_sub Foo::Bar::some_sub => sub {
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

The current implementation of L</wrap_sub> uses 2 extra function calls compared
to the hand-coded version outlined in L</DESCRIPTION> (which in turn uses 1
extra function call compared to the unwrapped function). You may or may not
care about that. Not measured the actual effect of it yet.

L</replace_sub> is exempt of this defect, it has no runtime penalty compared to
the hand-coded version.

=head2 Monkey-patching is next to evil

Monkey-patching can save the day (and did it several times), but is a dangerous
device. Extensively replacing/wrapping others' methods without serious reasons
is not considered to be a good practice. Try to stand the temptation, and do
not do it unless you really have to. See eg.
L<http://en.wikipedia.org/wiki/Monkey_patching#Pitfalls>.

=head2 Use Aspect for AOP

If you want to do some real Aspect Oriented Programming (AOP) instead of just
wrapping/replacing/adding some random method, you're better off with using the
L<Aspect> module. See also L</Differences from Aspect>.

=head2 caller() shows your wrapper

Unlike L<Hook::LexWrap> or L<Aspect>, L<Devel::MonkeyPatch::Sub> does not (yet)
override C<caller>. The problem is that some subroutines expect that they are
called by the actual user code, and then they will behave less usefully if
there's a wrapper inbetween.

=head2 subname() and set_prototype() is called even on named subs

Currently L<Sub::Name/subname> is called on CODE even if CODE is a reference to
a named subroutine, which is clearly the wrong behaviour (it should skip the
L<Sub::Name/subname> call in that case). The same goes for the
L<Sub::Prototype/set_prototype> call.

=head1 SEE ALSO

L<Sub::Name>, L<Aspect>, L<Hook::LexWrap>, L<Context::Preserve>

=head1 SUPPORT

Please submit bugs to the CPAN RT system at
http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Devel%3A%3AMonkeyPatch%3A%3ASub
or via email at bug-devel-monkeypatch-sub@rt.cpan.org.

=head1 AUTHOR

Norbert Buchmüller <norbi@nix.hu>

=head1 COPYRIGHT

Copyright 2009 Norbert Buchmüller.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
