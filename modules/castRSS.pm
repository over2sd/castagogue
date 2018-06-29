package castRSS;
print __PACKAGE__;

use strict;
use warnings;
use FIO qw( config );

=item updateRSS()
	Given an RSS feed filename ($fn) and an output (file or STDOUT ($output)), creates an RSS object and cleans out items that have already passed.
	Returns RSS item for $fn.
=cut
sub updateRSS {
	$|++;
	require XML::RSS;
	
	my ($fn,$output) = @_;
	my $rss = XML::RSS->new;
	$rss->parsefile($fn);
	$output and $output->push("Attempting to import $fn...");
	my $termcolor = config('Debug','termcolors') or 0;
	use Common qw( getColorsbyName );
	use DateTime;
	my $infcol = ($termcolor ? Common::getColorsbyName("green") : "");
	my $basecol = ($termcolor ? Common::getColorsbyName("base") : "");
	my $pccol = ($termcolor ? Common::getColorsbyName("cyan") : "");
	my $npccol = ($termcolor ? Common::getColorsbyName("ltblue") : "");
	for my $i (@{$rss->{items}}) {
		my $date = qq{$i->{'pubDate'}};
		my $end = DateTime->now;
		my $start = DateTime::Format::DateParse->parse_datetime( $date );
		if (($start - $end) > 0) {
			print "Deleting old item from $date.\n";
			$i->remove_item;
		}
    }
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

print " OK; ";
1;
