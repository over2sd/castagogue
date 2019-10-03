#!/usr/bin/perl
use strict;
use warnings;
use diagnostics;
use utf8;
use DateTime;
require XML::RSS;

sub howVerbose { return 0; }
use lib "./modules/";
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
