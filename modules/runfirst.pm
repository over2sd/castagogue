#!/usr/bin/perl
use strict;
use warnings;
use diagnostics;
use utf8;

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
}

use DateTime;
require XML::RSS;

use castRSS;



# mkdirs:
# itn (thumbs)
print "Ensuring presence of Thumbnail directory.\n";
-d "itn" or mkdir "itn";
# lib
print "Ensuring presence of Library directory.\n";
-d "lib" or mkdir "lib";
# schedule
print "Ensuring presence of Schedule directory.\n";
-d "schedule" or mkdir "schedule";

unless (-d "itn" and -d "lib" and -d "schedule") {
	die "Some functions of this program will crash without the required directories.\nAutomatic generation of directories has failed. Please create required directories 'itn', 'lib', and 'schedule' and re-run runfirst.pl before trying to use this program.\n";
}
my $now = DateTime->now;
my $pubdate = castRSS::timeAsRSS($now);

my $rss = XML::RSS->new(version => '2.0');
# add sample schedule files
# ask questions and write the first rss.xml file.
print "\nEnter the title of your RSS feed: ";
my $title = <>; chomp $title;
print "Enter the URL of your main Web page: ";
my $link = <>; chomp $link;
print "Enter a description for your RSS feed: ";
my $desc = <>; chomp $desc;
print "Building RSS file.\n";

$rss->channel(
	title => $title,
	link => $link,
	description => $desc,
	pubDate => $pubdate,
	lastBuildDate => $pubdate,
);
print "Enter the filename for your new RSS feed (rss.xml): ";
my $fn = <>;
chomp($fn);
$fn = "rss.xml" if ($fn eq "");
$rss->save($fn);
