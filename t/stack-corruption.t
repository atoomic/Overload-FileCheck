#!/usr/bin/perl

# Copyright (c) 2018, cPanel, LLC.
# All rights reserved.
# http://cpanel.net
#
# This is free software; you can redistribute it and/or modify it under the
# same terms as Perl itself. See L<perlartistic>.

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use Overload::FileCheck q/:all/;

sub mystat {
    my ( $stat_or_lstat, $f ) = @_;

    note "stat for file: ", $f;
    return stat_as_file( size => 1234 );
}

mock_all_from_stat( \&mystat );

my @array;
push @array, boom($0);    # Bizarre copy of ARRAY in list assignment
push @array, boom($0);    # Bizarre copy of ARRAY in list assignment

is scalar @array, 2, "2 elements in array";
is \@array, [ $0, $0 ], "array with two elements as expected";

done_testing;

sub boom {
    my ($path) = @_;

    open my $fh, '<', $path;

    my $exists = -f $fh && -s _;

    return $exists ? $path : undef;
}
