﻿#!/usr/bin/perl
use strict;
use warnings;
#use diagnostics;
use utf8;

# castapic
#######  This will be an app that takes a file of image URLs and lets the user type in a description for each, then save those descriptions into another file.
####### This is necessary because image hosting services don't usually give you access to your images in a sensible filename.

my $PROGRAMNAME = "Castapic";
my $version = "0.002a";

$|++; # Immediate STDOUT, maybe?
print "[I] Castapic v$version is running.";
flush STDOUT;

use Getopt::Long;
my $conffilename = 'config.ini';
my $debug = 0; # verblevel
sub howVerbose { return $debug; }

my $outfile = 'default.ini';
my $infile = 'ulist.txt';

GetOptions(
	'outputfile|o=s' => \$outfile,
	'infile|i=s' => \$infile,
	'conf|c=s' => \$conffilename,
	'verbose|v=i' => \$debug,
);

use lib "./modules/";
print "\n[I] Loading modules...";

require Sui; # My Data stores
require Common;
require FIO;
require PGUI; # Prima GUI

FIO::loadConf($conffilename);
FIO::config('Debug','v',howVerbose());
# other defaults:
foreach (Sui::getDefaults()) {
	FIO::config(@$_) unless defined FIO::config($$_[0],$$_[1]);
}


sub openOutfile {
	my ($fn) = @_;
	my $fail = 0;
	my $outputfilehandle;
	if ($fn eq '-') { return *STDOUT; }
    open ($outputfilehandle, ">$fn") || ($fail = 1);
	if ($fail) { print "\n[E] Dying of file error: $! Woe, I am slain!"; exit(-1); }
	return $outputfilehandle;
}



use Prima qw(Application Buttons MsgBox FrameSet Edit );
my $gui = PGK::createMainWin($PROGRAMNAME,$version,800,500);
my $text = $$gui{status};
PGUI::populateMainWin(undef,$gui,0);
$text->push("Ready.");
Prima->run();

1;