#!/usr/bin/perl
use strict;
use warnings;
#use diagnostics;
use utf8;

# castagogue
my $PROGNAME = "Castagogue";
my $version = "0.015a";

$|++; # Immediate STDOUT, maybe?
print "[I] $PROGNAME v$version is running.";
flush STDOUT;

BEGIN {
	print "\nChecking Dependencies:";
	my $preqs = 0;
	my $place = 0;
	my ($found,@ml,$mod);
	$found = 0;
	@ml = qw(WWW::Mechanize DateTime::Format::DateParse DateTime::Format::Duration DateTime Config::IniFiles XML::LibXML::Reader XML::RSS);
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

use Getopt::Long;
my $conffilename = 'config.ini';
my $debug = 0; # verblevel
sub howVerbose { return $debug; }

my $outfile = 'rssnew.xml';
my $rssfile = 'rss.xml';
my $begin = 'today';
my $conclude = 'tomorrow';
my $nextid = 1;
my $helpme = 0;
my $confme = 0;

GetOptions(
	'outputfile|o=s' => \$outfile,
	'rssfile|i=s' => \$rssfile,
	'startdate|f=s' => \$begin,
	'enddate|t=s' => \$conclude,
	'nextid|g=i' => \$nextid,
	'conf|c=s' => \$conffilename,
	'verbose|v' => \$debug,
	'usage|h' => \$helpme,
	'options|?=s' => \$confme,
);

if ($helpme) {
	print "$PROGNAME [args]:
   --outputfile -o <filename>: Use this output file (for writing RSS feed)
   --rssfile -i <filename>:    Use this input file (for channel name, etc.)
   --startdate -f <date>:      Start processing from YYYYMMDD
   --enddate -t <date>:	       Stop processing after YYYYMMDD
   --nextid -g <integer>:      Use this as the next GUID in the feed
   --conf -c <filename>:       Read this configuration file
   --verbose -v                Be verbose
   --usage -h                  Display this useful message
   --options -? <section>/all: Displays options for the config file
	";
	exit(0);
}

$conclude =~/([0-9]{4})-?([0-9]{2})-?([0-9]{2})/;
if ( !defined $1 || !defined $2 || !defined $3) { die "\nI could not parse $conclude for some reason as a date.\n" }
$begin =~/([0-9]{4})-?([0-9]{2})-?([0-9]{2})/;
if ( !defined $1 || !defined $2 || !defined $3) { die "\nI could not parse $begin for some reason as a date.\n" }

use lib "./modules/";
print "\n[I] Loading modules...";

require Sui; # My Data stores
require Common;
require FIO;
require NoGUI;
require castRSS; # castagogue RSS functions
require RRGroup;

if ($confme) {
	NoGUI::callOptBox($confme);
}

FIO::loadConf($conffilename);
FIO::config('Debug','v',howVerbose());
FIO::config('Main','nextid',$nextid);
# other defaults:
foreach (Sui::getDefaults()) {
	FIO::config(@$_) unless defined FIO::config($$_[0],$$_[1]);
}

#my $out = openOutfile($outfile);
my $mainwindow = "placeholder";
my $out = StatusBar->new(owner => $mainwindow)->prepare();

my $rss = castRSS::prepare($rssfile,$out);
#use Data::Dumper;
#print $rss->as_string;
my $error = castRSS::processRange($rss,$begin,$conclude,$out);
print "\nNow contains " . $#{$rss->{items}} . " items...";
# TODO: Update pubDate for feed/channel
$rss->save($outfile);
unless (FIO::config('Disk','persistentnext')) {
	print "nextID was " . FIO::cfgrm('Main','nextid',undef); } # reset nextID if we want to get it from the file each time.
FIO::saveConf();
print "\nExiting normally.\n";
1;
