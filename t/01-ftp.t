#!/usr/bin/env perl
use warnings;
use strict;

use Test::More qw/no_plan/;

BEGIN {
	use_ok( 'Net::Ftp::RecursivePut' );
}

diag( "Testing Net::Ftp::RecursivePut $Net::Ftp::RecursivePut::VERSION, Perl $], $^X" );

use FindBin qw/$Bin/;
use Path::Class;
my $home = Path::Class::Dir->new("$Bin/data");
my $ftp = Net::Ftp::RecursivePut->new(
#    host => 'localhost',
#    login => 'kd',
#    passwd => 'higlepix',
    host => 'ftp.uow.edu.au',
    login => 'kdiment',
    passwd => '23Skidoo',
    base_home => "$home",
    base_dest => 'public_html/test',
);

is (ref($ftp), 'Net::Ftp::RecursivePut', 'made an object');

is (ref($ftp->get_ftp_connection), 'Net::FTP' , "ftp connection is ok");

is (ref($ftp->tree), 'Tree::Simple', 'got the tree');

$ftp->put_tree;
