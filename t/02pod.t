use FindBin;
use File::Spec;
use Test::More;

eval "use Test::Pod 1.14";
plan skip_all => 'Test::Pod 1.14 required' if $@;
plan skip_all => 'set TEST_POD to enable this test'
  unless $ENV{TEST_POD}
    || $ENV{TEST_AUTHOR}
    || -e File::Spec->catfile($FindBin::Bin, File::Spec->updir, 'inc', '.author');

all_pod_files_ok();
