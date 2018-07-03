#!/usr/bin/perl
use strict;
use warnings;
#use diagnostics;
use utf8;

# castagogue
my $version = "0.001a";

$|++; # Immediate STDOUT, maybe?
print "[I] Castagogue v$version";

use Getopt::Long;
my $conffilename = 'config.ini';
my $debug = 0; # verblevel
sub howVerbose { return $debug; }

my $outfile = '-';
my $rssfile = 'rss.xml';
my $begin = 'today';
my $conclude = 'tomorrow';
my $nextid = 1;

GetOptions(
	'outputfile|o=s' => \$outfile,
	'rssfile|i=s' => \$rssfile,
	'startdate|f=s' => \$begin,
	'enddate|t=s' => \$conclude,
	'nextid|g=i' => \$nextid,
	'conf|c=s' => \$conffilename,
	'verbose|v=i' => \$debug,
);

use lib "./modules/";
print "\n[I] Loading modules...";

require Sui; # My Data stores
require Common;
require FIO;
use NoGUI;
require castRSS; # castagogue RSS functions

FIO::loadConf($conffilename);
FIO::config('Debug','v',howVerbose());
FIO::config('Main','nextid',$nextid);
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



#my $out = openOutfile($outfile);
my $mainwindow = "placeholder";
my $out = StatusBar->new(owner => $mainwindow)->prepare();
my $rss = castRSS::prepare($rssfile,$out);
#use Data::Dumper;
#print "Now contains " . $#{$rss->{items}} . " items...";
#print $rss->as_string;
my $error = castRSS::processRange($rss,$begin,$conclude);

FIO::saveConf();
1;