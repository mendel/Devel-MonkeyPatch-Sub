package Devel::MonkeyPatch;

#FIXME tests
# * stacktrace (subnames)
# * nesting
# * glob, glob ref, bareword of fully qualified name, bareword of relative name, string of fully qualified name, string of relative name
# * monkey-patching localized subs
# * wrapping existing method
# * wrapping existing non-method sub
# * creating new method
# * creating new non-method sub
#FIXME documentation
# * describe what monkey-patching is
# * describe the goals (ie. not having more code "no strict 'refs'", "no warnings 'redefine'" than necessary
# * example
# * warnings about overuse
# * warnings about alpha quality code
#FIXME module build

use strict;
use warnings;

use base qw(Exporter);
our @EXPORT = qw(monkeypatch);

use Sub::Name;
use Symbol;

{
  package original;

  use strict;
  use warnings;

  our $sub;

  sub method
  {
    goto $sub if $sub;
  }

  no warnings 'once';
  *sub = \&method;
}

=head2 monkeypatch(NAME, CODE)
=head2 monkeypatch(GLOB, CODE)

Monkey-patches the given sub (can be a glob, bareword or string). If the name
is unqualified, qualifies it with the current package name.

Assigns a name (that is the same as the name sub you're patching) to the sub
using L<Sub::Name::subname>.

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

=head1 EXAMPLES

  # add a new sub
  monkeypatch Foo::Bar::somesub => sub {
    print "hello\n";
  };

  # wrap an existing method
  monkeypatch Foo::Bar::somesub => sub {
    my $self = @_;

    $_[0] = 42;

    $self->original::method(@_);
  };

  # wrap an existing function
  monkeypatch Foo::Bar::somesub => sub {
    $_[0] = 42;

    original::sub(@_);
  };

  # wrap a method by name
  monkeypatch 'Foo::Bar::somesub' => sub {
    ...
  };

  # wrap a method by name (bareword)
  monkeypatch Foo::Bar::somesub => sub {
    ...
  };

  # wrap a method by name (typeglob)
  monkeypatch *Foo::Bar::somesub => sub {
    ...
  };

  # wrap a method just for the current scope
  local *Foo::Bar::somesub = \&Foo::Bar::somesub;
  monkeypatch *Foo::Bar::somesub => sub {
    ...
  };

  # wrap a method in a context-preserving way (ie. it will work with
  # context-sensitive methods)
  use Context::Preserve;
  monkeypatch Foo::Bar::somesub => sub {
    my $self = shift;
    my $args = \@_;

    return preserve_context { $self->original::method(@$args) }
      after => sub {
        my ($self) = @_;

        $self->set_something(42);
      };
  };

=head1 SEE ALSO

L<Sub::Name>, L<Context::Preserve>

=cut

1;
