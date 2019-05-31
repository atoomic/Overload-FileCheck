#!/usr/bin/perl -w

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

use Overload::FileCheck ();

is Overload::FileCheck::_loaded(), 1, '_loaded';

is int Overload::FileCheck::CHECK_IS_TRUE(),  1, "CHECK_IS_TRUE";
is int Overload::FileCheck::CHECK_IS_FALSE(), 0, "CHECK_IS_FALSE";
is Overload::FileCheck::FALLBACK_TO_REAL_OP(), -1, "FALLBACK_TO_REAL_OP";

my @ops = qw{
  OP_FTIS
};

foreach my $op (@ops) {
    my $op_type = Overload::FileCheck->can($op)->();
    ok( $op_type, "$op_type: $op" );
}

done_testing;
