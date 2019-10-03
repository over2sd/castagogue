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
my $version = "0.023a";

print "[I] $PROGRAMNAME v$version is running.";
flush STDOUT;

my $conffilename = 'config.ini';
my $debug = 0; # verblevel
sub howVerbose { return $debug; }

my $outfile = 'default.ini';
my $infile = 'ulist.txt';

GetOptions(
	'outputfile|o=s' => \$outfile,
	'infile|i=s' => \$infile,
	'conf|c=s' => \$conffilename,
	'verbose|v' => \$debug,
);
BEGIN {
	print "\nChecking Dependencies:";
	my $preqs = 0;
	my $place = 0;
	my ($found,@ml,$mod);
	$found = 0;
	@ml = qw(WWW::Mechanize DateTime::Format::DateParse DateTime::Format::Duration DateTime Config::IniFiles XML::LibXML::Reader XML::RSS Prima);
	for $mod (@ml) {
		if (eval "require $mod") {
			$found++;
		} else {
			my $pos = 2**$place;
			$preqs = $preqs | $pos;
		}
		$place++; # increase binary place
	}
	print "\n$found of " . scalar(@ml) . " required libraries found.\n";
	unless ($found == scalar(@ml)) {
		print "This program requires additional libraries to function. Please install the following modules: ";
		while ($place >= 0) {
			my $pos = 2**$place;
			my $missing = (($preqs & $pos) == $pos ? 1 : 0);
			print "$ml[$place] " if $missing;
			$place--;
		}
		print "\n";
		die "Some required modules are missing.\n";
	}
	unless (-d "itn" and -d "lib" and -d "schedule") {
		die "Some functions of this program will crash without the required directories.\nPlease run 'runfirst.pl' before trying to use this program.\n";
	}
}

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
PGUI::populateMainWin(undef,$gui,0);
my @lines = FIO::readFile("notes.txt",$text,1); # open the file for notes
$$gui{notes} = \@lines; # store array for use later
$text->push("Ready.");
Options::formatTooltips();
print "\n";
Prima->run();
print "Exiting normally\n";
1;
