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
	$output and $output->push("Attempting to import $fn...");
	my $termcolor = config('Debug','termcolors') or 0;
	use Common qw( getColorsbyName );
	use DateTime;
	use DateTime::Format::DateParse;
	my $infcol = ($termcolor ? Common::getColorsbyName("green") : "");
	my $basecol = ($termcolor ? Common::getColorsbyName("base") : "");
	my $pccol = ($termcolor ? Common::getColorsbyName("cyan") : "");
	my $npccol = ($termcolor ? Common::getColorsbyName("ltblue") : "");
	print "Contains " . $#{$rss->{items}} . " items...";
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
			print "Deleting old item from $date.\n";
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

=item processDay()
	Given a filename ($fn) and an RSS object ($r), opens the text file and looks for certain keywords, whose data will be processed and stored with all tokens replaced with appropriate values.
	returns the RSS object? or any error codes? Haven't decided.
=cut
sub processDay {
	my ($fn,$r) = @_;
	my $guid = castRSS::getGUID();
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
	if ($start eq 'today') {
		$dp = DateTime->now;
	} else {
		$start =~/([0-9]{4})-?([0-9]{2})-?([0-9]{2})/;
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
	print "Stored start date as " . $dp->ymd() . ". Awaiting further coding. Sorry for the delay.\n";
	return 0;
}
print ".";


print " OK; ";
1;
