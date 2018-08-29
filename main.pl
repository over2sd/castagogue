#!/usr/bin/perl
use strict;
use warnings;
#use diagnostics;
use utf8;

# castagogue
my $PROGNAME = "Castagogue";
my $version = "0.011a";

$|++; # Immediate STDOUT, maybe?
print "[I] $PROGNAME v$version is running.";
flush STDOUT;

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

use lib "./modules/";
print "\n[I] Loading modules...";

require Sui; # My Data stores
require Common;
require FIO;
require NoGUI;
require castRSS; # castagogue RSS functions

if ($confme) {
	NoGUI::callOptBox($confme);
}

# Proof of concept for the Random Rotation Groups objects
# Not for production.

my $group = RRGroup->new(order => "mixed");
my ($index,$length) = $group->add(0,{name => "Tom Swift", age => 32},{name => "Harry Houdini", age => 27},{name => "John Smith", address => "1 Any St."});
#print "Put $length items at index $index of row 0.\n";
($index,$length) = $group->add(1,{place => "Boston", day => 32},{west => "East", up => "down"});
#print "Put $length items at index $index of row 1.\n";
($index,$length) = $group->add(0,{alf => "bet"});
#print "Put $length items at index $index of row 0.\n";
my %i = $group->item(0,1);
print "Contains " . $group->rows() . " rows. The first row contains " . $group->items(0) . " items. Second item in the row: " . $i{name} . "=" . $i{age} . "!\n";
### End of test code ###

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
1;