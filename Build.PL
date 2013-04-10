use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Test::AllModules',
    license             => 'perl',
    dist_author         => 'Dai Okabayashi <bayashi@cpan.org>',
    dist_version_from   => 'lib/Test/AllModules.pm',
    build_requires      => {
        'FindBin' => 0,
        'File::Spec' => 0,
    },
    requires => {
        'perl' => '5.8.1',
        'Module::Pluggable::Object' => 0,
        'Test::More' => 0.88,
        'Test::SharedFork' => 0,
        'Exporter' => 0,
    },
    add_to_cleanup      => [ 'Test-AllModules-*' ],
    meta_merge     => {
      resources => {
        repository  => 'http://github.com/bayashi/Test-AllModules'
      }
    },
    recursive_test_files => 1,
);

$builder->create_build_script();
