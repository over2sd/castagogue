#!/usr/bin/perl

=head1 UListPrep

A simple script for stripping the filename out of an FTP directory listing in, for example, the format of:
	filename	timestamp	size	
	filename	timestamp	size	

=head2 USAGE

	./ulistprep.pl <filename> <keep pattern> [prepend, such as base url for the directory] [outputfilename]

=cut

use warnings;
use strict;

my $fn = shift;
open FILE,$fn or die "Error opening $fn\n";
my $keeppat = shift or die("No keep pattern given!");
my $prepend = (shift or "");
my $out = shift;
if (defined $out) {
	open OUTPUT,">>","$out" or die "ERROR opening output file $out\n";
}

print "Trying to strip file but keep $keeppat";
unless ($prepend eq "") { print ", with each line will receiving $prepend"; }
if (defined $out) { print ". Output will go into $out"; }
print ".\n";
my $line;
my $count = 0;
my $total = 0;

while ($line=<FILE>){
	$line =~ /($keeppat)/;
	$total++;
	if (defined $1) {
		if (defined $out) {
			print OUTPUT "$prepend$1\n";
			print ".";
		} else {
			print "$prepend$1\n";
		}
		$count++;
	}
}

unless ($count) {
	print "Keep pattern must be present for this to work. If you are using backslash wildcards, be sure to double the backslash.\n";
}

if ($count and $out) {
	print "\n$count/$total lines stripped.\n";
}
