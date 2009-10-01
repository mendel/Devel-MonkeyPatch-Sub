#!/usr/bin/env perl

use strict;
use warnings;

use inc::Module::Install 0.91;

name 'Devel-MonkeyPatch-Sub';
all_from 'lib/Devel/MonkeyPatch/Sub.pm';
readme_from 'lib/Devel/MonkeyPatch/Sub.pm' => 'clean';
auto_set_repository;

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
test_requires 'FindBin' => '1.49';
test_requires 'Path::Class' => '0.16';
test_requires 'Devel::StackTrace' => '1.21';

author_requires 'Test::NoTabs' => '0.9',
author_requires 'Test::Pod' => '1.26',
author_requires 'Test::Pod::Coverage' => '1.04',
author_requires 'Pod::Coverage' => '0.19',
author_requires 'Module::Install::ExtraTests' => '0.006';
author_requires 'Module::Install::ReadmeFromPod' => '0.06';
author_requires 'Module::Install::AuthorRequires' => '0.02';
author_requires 'Module::Install::Repository' => '0.06';

extra_tests;

auto_install;

WriteAll;
