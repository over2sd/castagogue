#!/usr/bin/perl
use strict;
use warnings;
#use diagnostics;
use utf8;

# castagogue
my $version = "0.001a";

$|++; # Immediate STDOUT, maybe?

use Getopt::Long;
my $conffilename = 'config.ini';
my $debug = 0; # verblevel
sub howVerbose { return $debug; }

GetOptions(
	'conf|c=s' => \$conffilename,
	'verbose|v=i' => \$debug,
);

use lib "./modules/";
# print "Loading modules...";

require Sui; # My Data stores
require Common;
require FIO;
require castRSS; # castagogue RSS functions

FIO::loadConf($conffilename);
FIO::config('Debug','v',howVerbose());
# other defaults:
foreach (Sui::getDefaults()) {
	FIO::config(@$_) unless defined FIO::config($$_[0],$$_[1]);
}


FIO::saveConf();
1;