package Test::AllModules;
use strict;
use warnings;
use Module::Pluggable::Object;
use Test::More ();

our $VERSION = '0.07';

sub import {
    my $class = shift;

    my $caller = caller;

    no strict 'refs'; ## no critic
    for my $func (qw/ all_ok /) {
        *{"${caller}::$func"} = \&{"Test::AllModules::$func"};
    }
}

sub all_ok {
    my %param = @_;

    my $search_path = delete $param{search_path};
    my $check       = delete $param{check};
    my $checks      = delete $param{checks};
    my $except      = delete $param{except};
    my $lib         = delete $param{lib};
    my $fork        = delete $param{fork};
    my $shuffle     = delete $param{shuffle};

    my @checks;
    if (ref($check) eq 'CODE') {
        push @checks, +{ test => $check, name => '', };
    }
    else {
        for my $code ( $check, @{ $checks || [] } ) {
            my ($name) = keys %{$code || +{}};
            my $test   = $name ? $code->{$name} : undef;
            if (ref($test) eq 'CODE') {
                push @checks, +{ test => $test, name => "$name: ", };
            }
        }
    }

    unless ($search_path) {
        Test::More::plan skip_all => 'no search path';
        exit;
    }

    Test::More::plan('no_plan');
    my @exceptions = @{ $except || [] };

    if ($fork) {
        require Test::SharedFork;
        Test::More::note("Tests run under forking. Parent PID=$$");
    }

    my $count = 0;
    for my $class (
        grep { !_is_excluded( $_, @exceptions ) }
            _classes($search_path, $lib, $shuffle) ) {
        $count++;
        for my $code (@checks) {
            _exec_test($code, $class, $count, $fork);
        }

    }

    Test::More::note( "total: $count module". ($count > 1 ? 's' : '') );
}

sub _exec_test {
    my ($code, $class, $count, $fork) = @_;

    unless ($fork) {
        _ok($code, $class, $count);
        return;
    }

    my $pid = fork();
    die 'could not fork' unless defined $pid;

    if ($pid) {
        waitpid($pid, 0);
    }
    else {
        _ok($code, $class, $count, $fork);
        exit;
    }
}

sub _ok {
    my ($code, $class, $count, $fork) = @_;

    Test::More::ok(
        $code->{test}->($class, $count),
        "$code->{name}$class". ( $fork && $fork == 2 ? "(PID=$$)" : '' )
    );
}

sub _classes {
    my ($search_path, $lib, $shuffle) = @_;

    local @INC = @{ $lib || ['lib'] };
    my $finder = Module::Pluggable::Object->new(
        search_path => $search_path,
    );
    my @classes = ( $search_path, $finder->plugins );

    return $shuffle ? _shuffle(@classes) : sort(@classes);
}

# This '_shuffle' method copied
# from http://blog.nomadscafe.jp/archives/000246.html
sub _shuffle {
    map { $_[$_->[0]] } sort { $a->[1] <=> $b->[1] } map { [$_ , rand(1)] } 0..$#_;
}

# This '_any' method copied from List::MoreUtils.
sub _any (&@) { ## no critic
    my $f = shift;

    foreach ( @_ ) {
        return 1 if $f->();
    }
    return;
}

sub _is_excluded {
    my ( $module, @exceptions ) = @_;
    _any { $module eq $_ || $module =~ /$_/ } @exceptions;
}

1;

__END__

=head1 NAME

Test::AllModules - do some tests for modules in search path


=head1 SYNOPSIS

    use Test::AllModules;

    BEGIN {
        all_ok(
            search_path => 'MyApp',
            check => sub {
                my $class = shift;
                eval "use $class;1;";
            },
        );
    }


=head1 DESCRIPTION

Test::AllModules is do some tests for modules in search path.


=head1 EXPORTED FUNCTIONS

=head2 all_ok(%args)

do C<check(s)> code as C<Test::More::ok()> for every module in search path.

=over 4

=item * B<search_path> => 'Class'

A namespace to look in. see: L<Module::Pluggable::Object>

=item * B<check> => \&test_code_ref or hash( TEST_NAME => \&test_code_ref )
=item * B<checks> => \@array: include hash( TEST_NAME => \&test_code_ref )

The code to execute each module. The code receives C<$class> and C<$count>. The result from the code is passed to C<Test::More::ok()>.

=item * B<except> => \@array: include scalar or qr//

This parameter is optional.

=item * B<lib> => \@array

Additional library paths.

This parameter is optional.

=item * B<fork> => 1:fork, 2:fork and show PID

If this option was set a value(1 or 2) then each check-code executes after forking.

This parameter is optional.

=item * B<shuffle> => boolean

If this option was set the true value then modules will be sorted in random order.

This parameter is optional.

=back


=head1 EXAMPLES

if you need the name of test

    use Test::AllModules;

    BEGIN {
        all_ok(
            search_path => 'MyApp',
            check => +{
                'use_ok' => sub {
                    my $class = shift;
                    eval "use $class;1;";
                },
            },
        );
    }

actually the count is also passed

    use Test::AllModules;

    BEGIN {
        all_ok(
            search_path => 'MyApp',
            check => sub {
                my ($class, $count) = @_;
                eval "use $class;1;";
            },
        );
    }

more tests, all options

    use Test::AllModules;

    BEGIN {
        all_ok(

            search_path => 'MyApp',

            checks => [
                +{
                    'use_ok' => sub {
                        my $class = shift;
                        eval "use $class;1;";
                    },
                },
            ],

            except => [
                'MyApp::Role',
                qr/MyApp::Exclude::.*/,
            ],

            lib => [
                'lib',
                't/lib',
            ],

            shuffle => 1,

            fork => 1,
        );
    }


=head1 REPOSITORY

Test::AllModules is hosted on github
<http://github.com/bayashi/Test-AllModules>


=head1 AUTHOR

dann

Dai Okabayashi E<lt>bayashi@cpan.orgE<gt>


=head1 SEE ALSO

L<Test::LoadAllModules>


=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
