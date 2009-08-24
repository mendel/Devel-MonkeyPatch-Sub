#!/usr/bin/env perl

use strict;
use warnings;

use inc::Module::Install 0.91;

name 'Devel-MonkeyPatch-Sub';
all_from 'lib/Devel/MonkeyPatch/Sub.pm';

requires 'Exporter' => 0;
requires 'Symbol' => 0;
requires 'Sub::Name' => 0;
requires 'Sub::Prototype' => 0;

test_requires 'Test::Most' => 0;
test_requires 'File::Spec' => 0;
test_requires 'FindBin' => 0;
test_requires 'Devel::StackTrace' => 0;

my %force_requires_if_author = (
  'Test::NoTabs' => 0,
  'Test::Pod' => 0,
  'Test::Pod::Coverage' => 1.04,
  'Pod::Coverage' => 0.19,
);

# (lifted from DBIx::Class)
if ($Module::Install::AUTHOR) {
  warn <<'EOW';
******************************************************************************
******************************************************************************
***                                                                        ***
*** AUTHOR MODE: all optional test dependencies converted to hard requires ***
***                                                                        ***
******************************************************************************
******************************************************************************

EOW

  print "Regenerating README\n";
  system('pod2text lib/Devel/MonkeyPatch/Sub.pm > README');

  foreach my $module (keys %force_requires_if_author) {
    build_requires ($module => $force_requires_if_author{$module});
  }
}

auto_install;

tests_recursive 't';

WriteAll;

# Re-write META.yml to _exclude_ all forced requires (we do not want to ship this)
# (lifted from DBIx::Class)
if ($Module::Install::AUTHOR) {

  Meta->{values}{build_requires} = [ grep 
    { not exists $force_requires_if_author{$_->[0]} }
    ( @{Meta->{values}{build_requires}} )
  ];

  Meta->write;
}
