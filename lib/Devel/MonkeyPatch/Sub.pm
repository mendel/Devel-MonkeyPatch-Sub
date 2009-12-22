package Devel::MonkeyPatch::Sub;

#FIXME change to pass the orig sub like 'my ($orig_sub, $self, @args) = @_' (like Class::MOP::Class or Moose does; no 'original' package)
#TODO goal is to make all the power that is available via Class::MOP readily, easily and handily available (ie. short and expressive idioms for all the routine monkey-patching tasks)
#TODO use Scope::Upper and implement replace_sub_lexically and wrap_sub_lexically (use Scope::Guard to restore the method)
#TODO create an add_sub_unless_can sub that does << replace_sub somesub => sub { } unless $module->can('somesub') >>

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

=head2 Advantages over hand-coded monkey-patching

The usual idom to wrap a method 'in place':

  use Sub::Name;

  {
    my $new_method = subname 'Foo::Bar::some_sub' => sub {
      my $self = shift;

      # do something

      return $self->$orig_method(@_);
    };

    no strict 'refs';
    no warnings 'redefine';

    my $orig_method = \&Foo::Bar::some_sub;
    *Foo::Bar::some_sub = $new_method;
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

=head2 Differences from Hook::LexWrap

=over

=item

L<Hook::LexWrap>'s model to run code before or after the original method
(instead of forcing the user to replace it) and modify values is more elegant.

=item

L<Hook::LexWrap> even tweaks L<perlfunc/caller> to make things look better.

=item

L<Hook::LexWrap> can lexically wrap subroutines, L<Devel::MonkeyPatch::Sub>
cannot. (FIXME add wrap_sub_lexically/replace_sub_lexically subs using
Scope::Upper)

=item

With L<Hook::LexWrap> you can run any code before or after the original method, but if
the original method throws an exception, you cannot currently catch it.

=item

With L<Hook::LexWrap> code in the L<Hook::LexWrap/pre> and
L<Hook::LexWrap/post> wrappers is in a separate scope from the call to the
original method, so you cannot localize variables for the duration of the call
to the original subroutine.

=item

With L<Hook::LexWrap> you cannot skip calling the original subroutine.

=item

With L<Hook::LexWrap> you cannot currently add a new method to a class.

=back

=head2 Differences from Aspect

=over

=item

The L<Aspect> module gives you a full-fledged AOP API where you can easily wrap
even dozens of subroutines in one call, with clear and nice syntax. It is much
more powerful and flexible when selecting what to wrap.

=item

Since L<Aspect> is based on L<Hook::LexWrap>, everything said in
L</"Differences from Hook::LexWrap"> applies.

=item

L<Devel::MonkeyPatch::Sub> is more lightweight than L<Aspect>.

=back

=head2 Differences from Class::MOP

=over

=item

L<Class::MOP> is the standard for introspecting/manipulating classes.

In fact L<Devel::MonkeyPatch::Sub> uses
L<Class::MOP::Class/add_around_method_modifier> internally for L</wrap_sub> and
L</replace_sub> if L<Class::MOP> is loaded and the class to be manipulated has
its L<Class::MOP::Class> metaclass instance initialized.

=item

L<Class::MOP> can run code before or after the original method (instead of
forcing the user to replace it) which is more elegant.

=item

With L<Class::MOP> you have to check yourself if the method already exists and
choose between L<Class::MOP::Class/add_around_method_modifier> and
L<Class::MOP::Class/add_method>. L<Devel::MonkeyPatch::Sub> does it
transparently for you.

=item

The way you call the original subroutine in a L<Devel::MonkeyPatch::Sub>
wrapper is nicer (though a bit slower) than the way you do it from an
L<Class::MOP::Class/add_around_method_modifier> wrapper.

=back

=head1 VERSION

Version 0.01

=cut

our $VERSION = 0.01;

=head1 EXPORT

No methods are exported by default. You can import L</replace_sub> and
L</wrap_sub> if you want to.

L</original::method> and L<original::sub> are unconditionally created in the
L<original> package (not an original idea to use that namespace for anything
sensible, so I hope it won't clash with your code).

=cut

use base qw(Exporter);
our @EXPORT_OK = qw(replace_sub wrap_sub);

use Sub::Prototype;
use Sub::Name;
use Symbol;
use Class::MOP;

=head1 METHODS

=cut

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
# _wrap_or_replace_sub($glob, $new_sub, $wrap)
#
# The actual implementation of L</replace_sub> and L</wrap_sub>.
#
# If C<$wrap> is true, does L</wrap_sub>, otherwise does L</replace_sub>.
#
# See L</replace_sub> and L</wrap_sub> for documentation.
#
sub _wrap_or_replace_sub($$$)
{
  my ($glob, $new_sub, $wrap) = @_;

  # this way we can accept globs, globrefs, subrefs and strings (both relative
  # and fully qualified)
  my $fully_qualified_method_name
    = Symbol::qualify(ref $glob ? *$glob : $glob, caller(1));
  $fully_qualified_method_name =~ s/^\*//;

  # Class::MOP does not do this currently
  subname $fully_qualified_method_name => $new_sub;

  my ($package, $method_name)
    = ($fully_qualified_method_name =~ /^(.*)::([^:]+)$/);

  my $metaclass = $package->can('meta') ? $package->meta : undef;
  # in case it was something else called 'meta'
  $metaclass = Class::MOP::Class->initialize($package)
    unless defined $metaclass && $metaclass->isa('Class::MOP::Class');

  my $was_immutable = $metaclass->is_immutable;
  $metaclass->make_mutable if $was_immutable;

  if ($metaclass->has_method($method_name)) {
    my $old_sub = $metaclass->find_method_by_name($method_name)->body;

    $metaclass->add_around_method_modifier($method_name =>
      subname $fully_qualified_method_name => sub {
        local $original::sub = shift;
        return $new_sub->(@_);
      }
    );

    # copy the prototype - Class::MOP does not do this (and it makes no sense
    # for actual methods, so it never will; but this code should work for plain
    # subs as well)
    if (defined (my $prototype = prototype($old_sub))) {
      my $wrapper_sub = $metaclass->find_method_by_name($method_name)->body;
      set_prototype $wrapper_sub => $prototype;
    }
  } else {
    $metaclass->add_method($method_name =>
      Class::MOP::Method->wrap($new_sub,
        package_name => $package,
        name => $method_name
      )
    );
  }

  $metaclass->make_immutable($metaclass->immutable_options) if $was_immutable;

  return $metaclass->find_method_by_name($method_name)->body;
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

sub replace_sub(*&)
{
  my ($glob, $new_sub) = @_;

  return _wrap_or_replace_sub($glob, $new_sub, 0);
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

  return _wrap_or_replace_sub($glob, $new_sub, 1);
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

=head2 Use Class::MOP for serious work

L<Class::MOP> gives you a more elaborate interface to tweaking classes. For
serious work I'd recommend using that instead.

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

L<Sub::Name>, L<Aspect>, L<Hook::LexWrap>, L<Sub::Install>, L<Sub::Installer>, L<Context::Preserve>

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
