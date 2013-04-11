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

    my $search_path = $param{search_path};
    my @checks;
    if (ref($param{check}) eq 'CODE') {
        push @checks, +{ test => $param{check}, name => '', };
    }
    else {
        for my $check ( $param{check}, @{ $param{checks} || [] } ) {
            my ($name) = keys %{$check || +{}};
            my $test   = $name ? $check->{$name} : undef;
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
    my @exceptions = @{ $param{except} || [] };

    if ($param{fork}) {
        require Test::SharedFork;
        Test::More::note("Tests run under forking. Parent PID=$$");
    }

    my $count = 0;
    for my $class (
        grep { !_is_excluded( $_, @exceptions ) }
            _classes($search_path, \%param) ) {
        $count++;
        for my $check (@checks) {
            _exec_test($check, $class, $count, $param{fork});
        }

    }

    Test::More::note( "total: $count module". ($count > 1 ? 's' : '') );
}

sub _exec_test {
    my ($check, $class, $count, $fork) = @_;

    unless ($fork) {
        _ok($check, $class, $count);
        return;
    }

    my $pid = fork();
    die 'could not fork' unless defined $pid;

    if ($pid) {
        waitpid($pid, 0);
    }
    else {
        _ok($check, $class, $count, $fork);
        exit;
    }
}

sub _ok {
    my ($check, $class, $count, $fork) = @_;

    Test::More::ok(
        $check->{test}->($class, $count),
        "$check->{name}$class". ( $fork && $fork == 2 ? "(PID=$$)" : '' )
    );
}

sub _classes {
    my ($search_path, $param) = @_;

    local @INC = @{ $param->{lib} || ['lib'] };
    my $finder = Module::Pluggable::Object->new(
        search_path => $search_path,
    );
    my @classes = ( $search_path, $finder->plugins );

    return $param->{shuffle} ? _shuffle(@classes) : sort(@classes);
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

simplest

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

            # `except` and `lib` are optional.
            except => [
                'MyApp::Role',
                qr/MyApp::Exclude::.*/,
            ],

            lib => [
                'lib',
                't/lib',
            ],

            shuffle => 1, # shuffle a use list: optional

            fork => 1,    # use each module after forking: optional
        );
    }


=head1 DESCRIPTION

Test::AllModules is do some tests for modules in search path.


=head1 EXPORTED FUNCTIONS

=head2 all_ok(%args)

do C<check(s)> code as C<Test::More::ok()> for every module in search path.

=over 4

=item search_path

=item check

=item checks

=item except

=item lib

=item shuffle

=item fork

=back

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
