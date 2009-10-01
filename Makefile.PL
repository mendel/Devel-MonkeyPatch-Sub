#!/usr/bin/env perl

use strict;
use warnings;

use inc::Module::Install 0.91;

name 'Devel-MonkeyPatch-Sub';
all_from 'lib/Devel/MonkeyPatch/Sub.pm';

requires 'Exporter' => '5.62';
requires 'Symbol' => '1.06';
requires 'Sub::Name' => '0.04';
requires 'Sub::Prototype' => '0.02';

test_requires 'Test::Most' => '0.21';
test_requires 'Test::More' => '0.92';
test_requires 'Test::Differences' => '0.4801';
test_requires 'Test::Deep' => '0.103';
test_requires 'Test::Warn' => '0.21';
test_requires 'Test::Exception' => '0.27';
test_requires 'File::Spec' => '3.3';
test_requires 'FindBin' => '1.49';
test_requires 'Path::Class' => '0.16';
test_requires 'Devel::StackTrace' => '1.21';

my %force_requires_if_author = (
  'Test::NoTabs' => '0.9',
  'Test::Pod' => '1.26',
  'Test::Pod::Coverage' => '1.04',
  'Pod::Coverage' => '0.19',
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
