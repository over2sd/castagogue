package castRSS;
print __PACKAGE__;

use strict;
use warnings;
use FIO qw( config );
use RItem;
use Common qw( infMes );

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
	print "Contains " . $#{$rss->{items}} . " items...";
	my $itemno = 0;
	my $nextid = FIO::config('Main','nextid');
	my $purging = (FIO::config('Disk','purgeRSS') or 0); # only delete old RSS items if the user wants it done.
	for my $i (@{$rss->{items}}) {
		my $date = qq{$i->{'pubDate'}};
		my $end = DateTime->now;
		my $start = DateTime::Format::DateParse->parse_datetime( $date );
		if ($nextid < hex($i->{'guid'})) {
			$nextid = hex($i->{'guid'}) + 1;
		}
		if ($purging && $start < $end) {
			infMes("Deleting old item from $date.",continues => 1);
			splice(@{$rss->{items}},$itemno,1);
			print " (" . $#{$rss->{items}} . " left) ";
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
	my ($r,$desc,$url,$pdt,$cat,$title,$pub) = @_;
	my $pds = $pdt->strftime("%a, %d %b %Y %T %z");
	my $gi = sprintf("%04x",getGUID());
	$r->add_item(
		title		=> ("$title" or qq{$pdt->day_name}),
		link		=> "$url",
		pubDate		=> ("$pub" or "$pds"),
		guid		=> "$gi",
		category	=> (qq{$cat} or "general"),
		description => (qq{$desc} or "A description was not given."),
	)
}
print ".";

=item timeAsRSS()
	Given a DateTime object ($d), returns a string formatted in what RSS expects.
=cut
sub timeAsRSS {
	my $d = shift;
	return $d->strftime("%a, %d %b %Y %T %z");
}
print ".";

=item processFile()
	Given a filename ($fn), a DateTime ($d), and an RSS object ($r), opens the text file and looks for certain keywords, whose data will be processed and stored with all tokens replaced with appropriate values.
	Optionally, add an output object where status messages should go ($output).
	Returns error code.
=cut
sub processFile {
	my ($fn,$d,$output) = @_;
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
		my $fh;
		unless (open($fh,"<$fn")) { # open file
			$output and $output->push("\n[E] Error opening file: $!" );
			FIO:config('Main','fatalerr') && die "I am slain by unopenable file $fn because $!";
		} else {
			my $rdate = substr(timeAsRSS($d),0,-15);
			my $ti = RItem->new(date => "$rdate");
			my $descact = 0;
			while (my $line = <$fh>) { # read lines
				chomp $line;
				$line =~ m/(.*?\=)?(.*)/; # find keywords
				my $k = (defined $1 ? substr($1,0,-1) : "---"); # remove the equals sign from the keyword, or mark the line as a continued text line
				$k =~ s/\s//g; # no whitespace in keywords, please
				if ($k eq "text") { # for each keyword, store data in hash
					$descact = 1;
					my $parsed = Sui::expandMe($2,$d); # this is date/description text
					$ti->text($parsed);
				} elsif ($descact && $k eq "---") { # this is another line of text
					my $parsed = Sui::expandMe($2,$d);
					$ti->text($ti->text() . "\n$parsed");
				} elsif ($k eq "image") { # the link/image that goes with the post
					$ti->link($2);
					$descact = 0;
				} elsif ($k eq "title") { # The post's title
					$ti->name($2);
					$descact = 0;
				} elsif ($k eq "time") { # the time to publish this post to social media
					$ti->time(sprintf("%04i",$2));
					$descact = 0;
				} elsif ($k eq "cat" or $k eq "category") { # the category for the post
					$ti->category($2);
					$descact = 0;
				} elsif ($k eq "group") { # allow the use of a group tag, which will be expanded to fill the title, description, and image fields of the item automatically
					Sui::expandGroup($2,$d,$ti);
					$descact = 0;
				} elsif ($k eq "last") { # the end of the post record
					$descact = 0;
					push(@items,$ti); # store record
					last if(!defined $2 || $2 eq "1"); # if last item, exit loop
					print $fn;
					$ti = RItem->new(date => "$rdate"); # start new record, in case there are more items in this file
				} else { # Oops! Error.
					warn "\n[W] I found unexpected keyword $k with value $2.\n";
				}
			}
			close($fh); # close file
		}
	}
	return @items;
}


=item processDay()
	Given a date ($d) and an RSS object ($r), calls the processor for each file that day uses.
	Optionally, add an output object where status messages should go ($out).
	returns the RSS object? or any error codes? Haven't decided.
=cut
sub processDay {
	my ($d,$r,$out) = @_;
	if (main::howVerbose() > 0) {
		print "\nFor " . $d->ymd() . ": ";
	} else {
		print "|";
	}
	my @items;
	my $fn = lc($d->day_name()) . ".txt"; # check day.txt
	push(@items,processFile($fn,$d,$out));
	$fn = substr($fn,0,-4) . $d->week_of_month() . ".txt"; # check day#.txt
	push(@items,processFile($fn,$d,$out));
	$fn = substr($fn,0,-5) . ($d->week_of_month() % 2 ? "odd" : "even") . ".txt"; # check dayeven/dayodd.txt
	push(@items,processFile($fn,$d,$out));
	$fn = $d->strftime("date%d.txt"); # check date0#.txt (same date each month events)
	push(@items,processFile($fn,$d,$out));
	$fn = $d->ymd() . ".txt"; # check YYYY-MM-DD.txt (events generated for this date specifically)
	push(@items,processFile($fn,$d,$out));
	# check for today.txt
	# process daily if present
	foreach my $i (@items) { # after pulling events, put them in RSS objects
		(ref($i) eq "RItem") || next;
#	my ($r,$desc,$url,$pdt,$cat,$title,$pub) = @_;
		makeItem($r,$i->text,$i->link,$d,$i->cat,$i->name,$i->timestamp);
	}
	return 0;
}
print ".";

=item processRange()
	Given an RSS object ($r) and two dates in correct order ($start,$end), runs processDay on each day in the range.
	Optionally, add an output object where status messages should go ($out).
	returns the number of days processed.
=cut
sub processRange {
	my ($r,$start,$end,$out) = @_; # format of dates is YYYYMMDD padded with 0's.
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
	($ds < $dp) && die "I cannot go backward in time. Sorry.\n";
	infMes("Processing files from " . $dp->ymd() . " to " . $ds->ymd() . ":");
	while ($dp < $ds) {
		processDay($dp,$r,$out);
		$dp = $dp + DateTime::Duration->new( days=> 1 );
	}
	return 0;
}
print ".";


print " OK; ";
1;
