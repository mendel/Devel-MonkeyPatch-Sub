#!/usr/bin/env perl

use strict;
use warnings;

use inc::Module::Install;

name 'Devel-MonkeyPatch';
all_from 'lib/Devel/MonkeyPatch.pm';

requires 'Exporter' => 0;
requires 'Sub::Name' => 0;
requires 'Symbol' => 0;

auto_install;

tests_recursive 't';

WriteAll;
