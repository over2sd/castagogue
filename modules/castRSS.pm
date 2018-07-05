package castRSS;
print __PACKAGE__;

use strict;
use warnings;
use FIO qw( config );

sub beforeIt {
	my ($d1,$d2) = @_;
#print "Comparing " . $d1->ymd() . " to " . $d2->ymd() . ":";
	if ($d1->year() > $d2->year()) {
		return 0;
	} elsif ($d1->month() > $d2->month()) {
		return 0;
	} elsif ($d1->day() > $d2->day()) {
		return 0;
	} else {
		return 1;
	}
}

=item prepare()
	Given an RSS feed filename ($fn) and an output (file or STDOUT ($output)), creates an RSS object and cleans out items that have already passed.
	Returns RSS item for $fn.
=cut
sub prepare {
	$|++;
	require XML::RSS;
	
	my ($fn,$output) = @_;
	my $rss = XML::RSS->new;
	$rss->parsefile($fn);
	$output and $output->push("\n[I] Attempting to import $fn...");
	my $termcolor = config('Debug','termcolors') or 0;
	use Common qw( getColorsbyName );
	use DateTime;
	use DateTime::Format::DateParse;
	my $infcol = ($termcolor ? Common::getColorsbyName("green") : "");
	my $basecol = ($termcolor ? Common::getColorsbyName("base") : "");
	my $pccol = ($termcolor ? Common::getColorsbyName("cyan") : "");
	my $npccol = ($termcolor ? Common::getColorsbyName("ltblue") : "");
	#print "Contains " . $#{$rss->{items}} . " items...";
	my $itemno = 0;
	my $nextid = FIO::config('Main','nextid');
	for my $i (@{$rss->{items}}) {
		my $date = qq{$i->{'pubDate'}};
		my $end = DateTime->now;
		my $start = DateTime::Format::DateParse->parse_datetime( $date );
		if ($nextid < $i->{'guid'}) {
			$nextid = $i->{'guid'} + 0;
		}
		if (beforeIt($start,$end)) {
			print "\n[I] Deleting old item from $date.";
			splice(@{$rss->{items}},$itemno,1);
		}
		$itemno++;
    }
	FIO::config('Main','nextid',$nextid);
	$|--;
	return $rss;
}
print ".";

#new for castagogue
=item getGUID()
	Generates a very simple ID by incrementing the number in the INI file.
	returns an ID.
=cut
sub getGUID {
	print "?";
	my $value = FIO::config('Main','nextid');
	FIO::config('Main','nextid',$value + 1);
	return $value;
}

#new for castagogue
=item makeItem()
	Given an RSS object($r), a description ($desc), a URL ($url), and a publication dateTime ($pdt) (and optionally a category, $cat), creates an item in the RSS object.
=cut
sub makeItem {
	my ($r,$desc,$url,$pdt,$cat) = @_;
	my $pds = $pdt->strftime("%a, %d %b %Y %T %z");
	my $gi = getGUID();
	$r-add_item(
		title		=> qq{$pdt->day_name},
		link		=> "$url",
		pubDate		=> "$pds",
		guid		=> "$gi",
		category	=> qq{$cat},
	)
}
print ".";

=item processFile()
	Given a filename ($fn) and an RSS object ($r), opens the text file and looks for certain keywords, whose data will be processed and stored with all tokens replaced with appropriate values.
	Returns error code.
=cut
sub processFile {
	my $fn = shift;
	$fn = "schedule/$fn";
	my $v = main::howVerbose(); 
	if ( $v > 2) { print " $fn"; }
	my @items = [];
	unless ( -e $fn ) {
		print "-" if ($v > 0);
		return @items;
	} else {
		if ($v > 0) {
			print "+";
		} else {
			print ".";
		}
	# open file
	# read lines
	# find keywords
	# for each keyword, store data in hash
	# if last item, exit loop
	}
	return @items;
}


=item processDay()
	Given a date ($d) and an RSS object ($r), calls the processor for each file that day uses.
	returns the RSS object? or any error codes? Haven't decided.
=cut
sub processDay {
	my ($d,$r) = @_;
	if (main::howVerbose() > 0) {
		print "\nFor " . $d->ymd() . ": ";
	} else {
		print "|";
	}
	my $fn = lc($d->day_name()) . ".txt"; # check day.txt
	processFile($fn);
	$fn = substr($fn,0,-4) . $d->week_of_month() . ".txt"; # check day#.txt
	processFile($fn);
	$fn = substr($fn,0,-5) . ($d->week_of_month() % 2 ? "odd" : "even") . ".txt"; # check dayeven/dayodd.txt
	processFile($fn);
	$fn = $d->strftime("date%d.txt"); # check date0#.txt (same date each month events)
	processFile($fn);
	$fn = $d->ymd() . ".txt"; # check YYYY-MM-DD.txt (events generated for this date specifically)
	processFile($fn);
	# check for today.txt
	# process daily if present
	if (0) { # after pulling events, put them in RSS objects
		my $guid = castRSS::getGUID();
	}
	return 0;
}
print ".";

=item processRange()
	Given an RSS object ($r) and two dates in correct order ($start,$end), runs processDay on each day in the range.
	returns the number of days processed.
=cut
sub processRange {
	my ($r,$start,$end) = @_; # format of dates is YYYYMMDD padded with 0's.
	use DateTime;
	my $dp;
	my $ds;
	if ($start eq 'today') {
		$dp = DateTime->now;
	} else {
		$start =~/([0-9]{4})-?([0-9]{2})-?([0-9]{2})/;
		if ( !defined $1 || !defined $2 || !defined $3) { die "I could not parse $start for some reason as a date.\n" }
		$dp = DateTime->new(
				year => $1,
				month => $2,
				day => $3,
				hour => 23,
				minute => 59,
				second => 59,
				time_zone => 'floating',
			);
	}
	if ($end eq 'tomorrow') {
		$ds = DateTime->now()->add(days => 1);
	} else {
		$end =~/([0-9]{4})-?([0-9]{2})-?([0-9]{2})/;
		if ( !defined $1 || !defined $2 || !defined $3) { die "I could not parse $end for some reason as a date.\n" }
		$ds = DateTime->new(
				year => $1,
				month => $2,
				day => $3,
				hour => 23,
				minute => 59,
				second => 59,
				time_zone => 'floating',
			);
	}
	if (beforeIt($ds,$dp)) { die "I cannot go backward in time. Sorry.\n"; }
	print "\n[I] Processing files from " . $dp->ymd() . " to " . $ds->ymd() . ":";
	while (beforeIt($dp,$ds)) {
		processDay($dp,$r);
		$dp = $dp + DateTime::Duration->new( days=> 1 );
	}

	return 0;
}
print ".";


print " OK; ";
1;
