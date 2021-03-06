#!/usr/bin/perl
use strict;
use warnings;
#use diagnostics;
use utf8;

use Getopt::Long;
use lib "./modules/";
use skrDebug;

# castapic
#######  This will be an app that takes a file of image URLs and lets the user type in a description for each, then save those descriptions into another file.
####### This is necessary because image hosting services don't usually give you access to your images in a sensible filename.

my $PROGRAMNAME = "Castapic";
my $version = "0.032a";

print "[I] $PROGRAMNAME v$version is running.";
flush STDOUT;

my $conffilename = 'config.ini';
my $debug = 0; # verblevel
sub howVerbose { return $debug; }

unless (-d "itn" and -d "lib" and -d "schedule") {
	-d "itn" or print "itn missing. ";
	-d "lib" or print "lib missing. ";
	-d "schedule" or print "schedule missing. ";
	die "Please run runfirst.pl to correct these errors.\n";
#	use runfirst;
}

my $outfile = 'default.ini';
my $infile = 'ulist.txt';

GetOptions(
	'outputfile|o=s' => \$outfile,
	'infile|i=s' => \$infile,
	'conf|c=s' => \$conffilename,
	'verbose|v' => \$debug,
);

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

use Prima qw(Application Buttons MsgBox FrameSet Edit );
my $gui = PGK::createMainWin($PROGRAMNAME,$version);
my $text = $$gui{status};
Sui::storeData('status',$text);
PGUI::populateMainWin(undef,$gui,0);
my @lines = FIO::readFile("notes.txt",$text,1); # open the file for notes
$$gui{notes} = \@lines; # store array for use later
$text->push("Ready.");
Options::formatTooltips();
print "\n";
Prima->run();
print "Exiting normally\n";
1;
