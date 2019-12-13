package castRSS;
print __PACKAGE__;

use strict;
use warnings;
use FIO qw( config );
use RItem;
use Common qw( infMes );

#new for castagogue
=item prepare()
	Given an RSS feed filename ($fn) and an output (file or STDOUT ($output)), creates an RSS object and cleans out items that have already passed.
	Returns RSS item for $fn.
=cut
sub prepare {
	$|++;
	require XML::RSS;
	
	my ($fn,$output,$isgui) = @_;
	my $rss = XML::RSS->new;
	$rss->parsefile($fn);
	my $pb = Sui::passData('progress');
	$output and $output->push("\n[I] Attempting to import $fn...");
	my $termcolor = config('Debug','termcolors') or 0;
	use Common qw( getColorsbyName );
	use DateTime;
	use DateTime::Format::DateParse;
	my $infcol = ($termcolor ? Common::getColorsbyName("green") : "");
	my $basecol = ($termcolor ? Common::getColorsbyName("base") : "");
	my $pccol = ($termcolor ? Common::getColorsbyName("cyan") : "");
	my $npccol = ($termcolor ? Common::getColorsbyName("ltblue") : "");
	$output and $output->push("Contains " . $#{$rss->{items}} . " items...");
	$pb and $pb->max($#{$rss->{items}} + 1);
	my $opt;
	unless (Sui::passData('context') eq "CLI") { $opt = $output; } # if GUI, send InfMessages to GUI object.
	my $itemno = 0;
	my $nextid = FIO::config('Main','nextid');
	my $purging = (FIO::config('Disk','purgeRSS') or 0); # only delete old RSS items if the user wants it done.
	my $debug = main::howVerbose();
	foreach my $i (@{$rss->{items}}) {
		if (defined $pb) {
			$pb->value($pb->value + 1); # increment progress bar
			PGK::Pfresh(); # repaint
		}
		my $date = qq{$i->{'pubDate'}};
		my $end = DateTime->now;
		my $start = DateTime::Format::DateParse->parse_datetime( $date );
		my $rawid = $i->{'guid'};
		my ($most,$mid,$least);
		unless ($rawid =~ m/^[0-9a-zA-Z]{7}-[0-9a-zA-Z]{7}-[0-9a-fA-F]{7}$/) {
			$rawid =~ /([0-9a-zA-Z]{1,7}?)([0-9a-zA-Z]{1,7}?)([0-9a-fA-F]{7})$/;
			($most,$mid,$least) = ($1,$2,$3);
			$most = sprintf("%07s",$most);
			$mid = sprintf("%07s",$mid);
			infMes("* Found: $most-$mid-$least...",1,gobj => $opt);
		} else{
			$rawid =~ m/^([0-9a-zA-Z]{7})-([0-9a-zA-Z]{7})-([0-9a-fA-F]{7})$/;
			($most,$mid,$least) = ($1,$2,$3);
		}
		my $nextmost = (FIO::config('Disk','gui1') or 0);
		my $nextmid = (FIO::config('Disk','gui2') or 0);
		my $numinhex = hex($least);
print "For $numinhex...";
		if ($nextid < $numinhex) {
			$nextid = $numinhex + 1;
		}
		$most = ($nextmost > hex($most) ? $nextmost : hex($most));
		$mid = ($nextmid > hex($mid) ? $nextmid : hex($mid));
		FIO::config('Disk','gui1',$most); # save as int
		FIO::config('Disk','gui2',$mid); # save as int
		if ($purging && $start < $end) {
			infMes("Deleting old item from $date. (" . $#{$rss->{items}} . " left)",1,gobj => $opt);
			splice(@{$rss->{items}},$itemno,1);
		} elsif ($start < $end) {
			$debug and infMes("Keeping old item from $date.",1,gobj => $opt);
		} else {
			$debug and infMes("$date is after " . $end->ymd() . ".\n",1,gobj => $opt);
		}
		$itemno++;
    }
	if (defined $pb) {
		$pb->value($pb->value + 1); # increment progress bar
		PGK::Pfresh(); # repaint
	}
	FIO::config('Main','nextid',$nextid);
	$|--;
	return $rss;
}
print ".";

=item getGUID()
	Generates an adequate ID by incrementing the number in the INI file.
	returns an ID.
=cut
sub getGUID {
	print "G";
	my $value = FIO::config('Main','nextid');
	my $v3 = FIO::config('Disk','gui1');
	my $v2 = FIO::config('Disk','gui2');
	if ($value >= hex("fffffff")) {
		$value -= hex("fffffff");
		if ($v2 >= hex("fffffff")) {
			$v2 -= hex("fffffff");
			if ($v3 >= hex("fffffff")) {
				$v3 -= hex("fffffff");
			}
			$v3++;
		}
		$v2++;
	}
	FIO::config('Main','nextid',$value + 1);
	FIO::config('Disk','gui1',$v3);
	FIO::config('Disk','gui2',$v2);
	$v3 = Common::pad($v3,7,"0");
	$v2 = Common::pad($v2,7,"0");
	$value = Common::pad($value,7,"0");
	return sprintf("%07x-%07x-%07x",$v3,$v2,$value);
}

=item makeItem()
	Given an RSS object($r), a description ($desc), a URL ($url), and a publication dateTime ($pdt) (and optionally a category, $cat), creates an item in the RSS object.
=cut
sub makeItem {
	my ($r,$desc,$url,$pdt,$cat,$title,$pub) = @_;
	my $pds = $pdt->strftime("%a, %d %b %Y %T ");
	$pds = $pds . Sui::getTZ();
	my $gi = getGUID();
	defined $cat or $cat = 'general';
	(FIO::config('Main','autotag') or 0) and $desc = "$desc\n#$cat"; # add the category as a hashtag
	my $tdt = $pdt->day_name;
	$r->add_item(
		title		=> ("$title" or qq{$tdt}),
		link		=> "$url",
		pubDate		=> ("$pub" or "$pds"),
		guid		=> "$gi",
		category	=> qq{$cat},
		description => (qq{$desc} or "A description was not given."),
	);
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

=item processDatedFile()
	Given a filename ($fn, though it should generally be "dated.txt") and an RSS object ($r), opens the text file and looks for certain keywords, whose data will be processed and stored with all tokens replaced with appropriate values.
	Optionally, add an output object where status messages should go ($output).
	Returns a hash of all dated items.
=cut
sub processDatedFile {
	my ($fn,$output,$opt) = @_;
	infMes("Reading $fn..",1,$opt);
	my $pb = Sui::passData('progress');
	$pb and $pb->value($pb->value + 1);
	$fn = "schedule/$fn";
	my $v = main::howVerbose();
	if ( $v > 2) { print " $fn"; }
	my %items;
	unless ( -e $fn ) { # file does not exist; skipping
		print "-" if ($v > 0);
		return %items;
	} else {
		if ($v > 0) {
			print "+";
		} else {
			print ".";
			$opt and $opt->append(".");
		}
		my $fh;
		unless (open($fh,"<$fn")) { # open file
			$output and $output->push("\n[E] Error opening file: $!" );
			my $reason = "I am slain by unopenable file $fn because $!";
			(FIO::config('Main','fatalerr') ? die $reason : warn $reason);
			return; # in case I didn't die.
		} else {
			my $lead = DateTime::Duration->new( days=> (FIO::config('Main','eventlead') or 0)); # so we can add to it without losing our place.
			while (my $line = <$fh>) { # read lines
				chomp $line;
				my ($ldate,$limg,$ltitle,$ldesc,$ltime,$lcat);
				$ldate = $1 if $line =~ /date=(\d{4}-\d{2}-\d{2})>/;
# TODO: validity checking
				unless (defined $1) {
					0 and print "...skipping undated line...";
					next;
				}
				my $d = DateTime::Format::DateParse->parse_datetime( $ldate );
				my $rdate = substr(timeAsRSS($d),0,-15);
				$ltitle = $1 if $line =~ /title=([\d:\w\s]+)>/;
				my $ti = RItem->new(date => "$rdate", title => $ltitle);
				my $ed = $d + $lead; # so we can add to it without losing our place.
				$limg = $1 if $line =~ /image=(.+?)>/;
				$ldesc = $1 if $line =~ /desc=(.+?)>/;
				$ltime = $1 if $line =~ /time=(\d{3,4})>/;
				$lcat = $1 if $line =~ /cat=(\w+?)>/;
				$ldesc = Sui::expandMe($ldesc,$ed); # this is date/description text
				$ltitle = Sui::expandMe($ltitle,$ed); # this is date/description text
				$ti->text($ldesc);
				$ti->link($limg);
				$ti->name($ltitle);
				$ti->time(sprintf("%04i",$ltime));
				$ti->category($lcat);
$ti->set(meta => "dated");
				$items{$ldate} = [] unless exists $items{$ldate};
				push(@{$items{$ldate}},$ti); # store record
				if ($pb) { # increment operations and completion
					$pb->max($pb->max + 1);
					$pb->value($pb->value + 1);
				}
			}
			close($fh); # close file
		}
	}
	return %items;
}

=item countWeeks()
	DateTime counts weeks based on which week on the calendar they are. This is not useful behavior for finding if a date is the third Tuesday.
	This function takes a day of the month as an integer ($d) and returns a week number, 1-5 or 0-4, depending on whether $maskpos is 0 or 1.
=cut
sub countWeeks {
	my ($d,$maskpos) = @_;
	my $val = ($maskpos ? 5 : 6);
	if ($d < 32) { # fifth week
		$val--;
		if ($d < 28) { # fourth week
			$val--;
			if ($d < 21) { # third week
				$val--;
				if ($d < 14) { # second week
					$val--;
					if ($d < 7) { # first week
						$val--;
						if ($d < 1) { # bad week
							$val--;
						}
					}
				}
			}
		}
	} else { # day >= 32
		return -1;
	}
	return $val;
}

=item processFile()
	Given a filename ($fn), a DateTime ($d), and a hashref of existing items ($hr) opens the text file and looks for certain keywords, whose data will be processed and stored with all tokens replaced with appropriate values.
	Optionally, add an output object where status messages should go ($output).
	Returns array of RItems.
=cut
sub processFile {
	my ($fn,$d,$hr,$output,$opt,$timed) = @_;
	$fn = "schedule/$fn";
	my $v = main::howVerbose(); 
	if ( $v > 2) { print " $fn"; }
	my @items = [];
	unless ( -e $fn ) { # file does not exist; skipping
		print "-" if ($v > 0);
		return @items;
	} else {
		if ($v > 0) {
			print "+";
		} else {
			print ".";
			$opt and $opt->append(".");
		}
		my $fh;
		unless (open($fh,"<$fn")) { # open file
			$output and $output->push("\n[E] Error opening file: $!" );
			FIO:config('Main','fatalerr') && die "I am slain by unopenable file $fn because $!";
		} else {
			my $rdate = substr(timeAsRSS($d),0,-15);
			my $ti = RItem->new(date => "$rdate");
$ti->set('meta',"processFile");
			my $descact = 0;
			my $ed = $d + DateTime::Duration->new( days=> (FIO::config('Main','eventlead') or 0)); # so we can add to it without losing our place.

			while (my $line = <$fh>) { # read lines
				chomp $line;
				$line =~ m/(.*?\=)?(.*)/; # find keywords
				my $k = (defined $1 ? substr($1,0,-1) : "---"); # remove the equals sign from the keyword, or mark the line as a continued text line
				$k =~ s/\s//g; # no whitespace in keywords, please
				if ($k eq "text") { # for each keyword, store data in hash
					$descact = 1;
					my $parsed = Sui::expandMe($2,$ed); # this is date/description text
					$ti->text($parsed);
				} elsif ($descact && $k eq "---") { # this is another line of text
					my $parsed = Sui::expandMe($2,$ed);
					$ti->text($ti->text() . "\n$parsed");
				} elsif ($descact && $k eq "mask") { # this is another line of text (week masked) mask is sum of 1 = first, 2 = second, 4 = third, 8 = fourth, 16 = fifth, 32 = final (fourth or fifth)
					my $raw = $2;
					$raw =~ /(\d+),(.+)/;
					my $week = $1;
					my $pweek = countWeeks($ed->day());
					if($week == 32) { # final week
						my $date2 = $ed->clone;
						$date2->set_day(1)->add( months => 1 )->subtract( days => 1 );
						my $ender = $date2->day();
#						print "Last day: $ender - 6 = ";
						$ender -= 6;
#						print "first last of this weekday: $ender\n";
						next unless ($ender <= $ed->day());
						next unless (Common::getBit($pweek - 1,24)); # Fourth or fifth
						$week = 24;
					}
					next unless (Common::getBit($pweek - 1,$week));
					my $parsed = Sui::expandMe($2,$ed);
					$parsed =~ /^([0-9]{4})?,?(.*)/; # 24H time starts line
					if (defined $1) { # masked event with time
						print ">";
						if (not defined $$timed{$1}) {
							$$timed{$1} = [];
						}
						push(@{$$timed{$1}},$2);
						next; # prevents reprinting of line in following instruction
					}
					$ti->text($ti->text() . "\n$parsed");
				} elsif ($k eq "lead") { # how far ahead the post is dated from the publication date MUST be in the file before the text with date replacements, or the date will be wrong.
					my $lead = int($2);
					$ed = $d + DateTime::Duration->new( days=> $lead); # events are posted how far ahead?
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
					next if (exists $$hr{$ti->date(undef,1)} && Common::findIn($ti->title,@{$$hr{$ti->date(undef,1)}}));
					push(@{$$hr{$ti->date(undef,1)}},$ti->title);
					foreach my $t (sort keys %$timed) {
						my $time = ($t - ($t > 1259 ? 1200 : 0)) . " m";
						substr($time,(length($time) < 6 ? 1 : 2),0,":");
						substr($time,-1,0,($t > 1259 ? "p" : "a"));
						$ti->text($ti->text . "\n$time - ");
						my $first = 1;
						foreach my $event (@{$$timed{$t}}) {
							unless ($first) { $ti->text($ti->text . "\n\t"); }
							$first = 0;
							$ti->text($ti->text . "$event");
						}
					}
					push(@items,$ti); # store record
					last if(!defined $2 || $2 eq "1"); # if last item, exit loop
					print $fn;
					$ed = $d + DateTime::Duration->new( days=> (FIO::config('Main','eventlead') or 0)); # so we can add to it without losing our place.
					$ti = RItem->new(date => "$rdate"); # start new record, in case there are more items in this file
$ti->set('meta',"processFile");
				} elsif ($k eq "defer" || $k eq "defered") { # temporary hide
					next; # The user just wants this to be hidden, for now.
				} else { # Oops! Error.
					warn "\n[W] I found unexpected keyword $k with value $2. ($fn)\n";
				}
			}
			close($fh); # close file
		}
	}
	return @items;
}

=item addDatedToday()
	Given an RSS object ($r), a hashref of existing titles ($hr), and an arrayref of items to add ($ar), calls the processor for each item.
	Optionally, add an output object where status messages should go ($out).
	returns the RSS object? or any error codes? Haven't decided. Returns 0 for now.
=cut
sub addDatedToday {
	my ($r,$hr,$ar,$d,$out,$opt) = @_;
	if (main::howVerbose() > 0) {
		print "\nRunning dated objects: ";
	} else {
		print "Y";
		$opt and $opt->append(";");
	}
	my @items = @$ar;
	foreach my $i (@items) { # put items in RSS objects
		(ref($i) eq "RItem") || next;
		if (exists $$hr{$i->date(undef,1)} && scalar @{$$hr{$i->date(undef,1)}}) { # if a title list exists,
			next if (Common::findIn($i->title,@{$$hr{$i->date(undef,1)}}) > -1); # skip this item if its title is present for this date.
		}
		push(@{$$hr{$i->date(undef,1)}},$i->title); # otherwise, add it to the list...
		makeItem($r,$i->text,$i->link,$d,$i->cat,$i->name,$i->timestamp); # and add it to the RSS feed.
	}
	return 0;
}
print ".";


=item processDay()
	Given a date ($d) and an RSS object ($r), calls the processor for each file that day uses.
	Optionally, add an output object where status messages should go ($out).
	returns the RSS object? or any error codes? Haven't decided.
=cut
sub processDay {
	my ($d,$r,$hr,$out,$opt) = @_;
	if (main::howVerbose() > 0) {
		print "\nFor " . $d->ymd() . ": ";
	} else {
		print "|";
	}
	my $statxt = "Checking " . $d->ymd() . ": ";
	$opt and $opt->push($statxt);
	my $pb = Sui::passData('progress');
	my $sb = Sui::passData('status');
	my @items;
	my %timedentry;
	my $fn = lc($d->day_name()) . ".txt"; # check day.txt
	$pb and $pb->value($pb->value() + 1);
	$sb and $sb->push($statxt . "weekly");
	push(@items,processFile($fn,$d,$hr,$out,$opt,\%timedentry));
	$fn = substr($fn,0,-4) . $d->week_of_month() . ".txt"; # check day#.txt
	$pb and $pb->value($pb->value() + 1);
	$sb and $sb->push($statxt . "numweekly");
	push(@items,processFile($fn,$d,$hr,$out,$opt,\%timedentry));
	$fn = substr($fn,0,-5) . ($d->week_of_month() % 2 ? "odd" : "even") . ".txt"; # check dayeven/dayodd.txt
	$pb and $pb->value($pb->value() + 1);
	$sb and $sb->push($statxt . "odd/even");
	push(@items,processFile($fn,$d,$hr,$out,$opt,\%timedentry));
	$fn = $d->strftime("date%d.txt"); # check date0#.txt (same date each month events)
	$pb and $pb->value($pb->value() + 1);
	$sb and $sb->push($statxt . "monthly");
	push(@items,processFile($fn,$d,$hr,$out,$opt,\%timedentry));
	$fn = $d->ymd() . ".txt"; # check YYYY-MM-DD.txt (events generated for this date specifically)
	$pb and $pb->value($pb->value() + 1);
	$sb and $sb->push($statxt . "dated");
	push(@items,processFile($fn,$d,$hr,$out,$opt,\%timedentry));
	$fn = "today.txt"; # check for today.txt
#	$opt and $opt->push($statxt . "daily");
	$pb and $pb->value($pb->value() + 1);
	# process daily if present
	foreach my $i (@items) { # after pulling events, put them in RSS objects
		(ref($i) eq "RItem") || next;
		next if (exists $$hr{$i->timestamp} && findIn($i->title,@{$$hr{$i->timestamp}}));
		push(@{$$hr{$i->timestamp}},$i->title);
#	my ($r,$desc,$url,$pdt,$cat,$title,$pub) = @_;
		makeItem($r,$i->text,$i->link,$d,$i->cat,$i->name,$i->timestamp);
	}
	return 0;
}
print ".";


=item catalogRSS()
	Given an RSS object ($r), returns a hash of its item dates as keys, and its item titles for each date as an arrayref of values.

=cut
sub catalogRSS {
	my $r = shift;
	my %items;
	foreach my $i (@{$r->{items}}) {
		my $ldate = $i->{pubDate};
		my $d = DateTime::Format::DateParse->parse_datetime( $ldate );
		$ldate = $d->ymd();
		$items{$ldate} = [] unless exists $items{$ldate};
		push(@{$items{$ldate}},$i->{title}); # store record
	}
	return %items;
}
print ".";

=item processRange()
	Given an RSS object ($r) and two dates in correct order ($start,$end), runs processDay on each day in the range.
	Optionally, add an output object where status messages should go ($out).
	returns the number of days processed.
=cut
sub processRange {
	my ($r,$start,$end,$out,$isgui) = @_; # format of dates is YYYYMMDD padded with 0's.
# TODO: If $isgui, use popup windows instead of dying.
	my $opt;
	$opt = $out if $isgui;
	my $pb = Sui::passData('progress');
	$pb->value($pb->value() + 1);
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
	infMes("Processing files from " . $dp->ymd() . " to " . $ds->ymd() . ":",,$opt);
	my $length = $ds - $dp;
	my $diff = $length->days;
	$pb and $pb->max(($diff * 6) + 2);
	$pb and PGK::Pfresh();
	my %items = catalogRSS($r); # grab item titles to prevent duplication.
	$pb and $pb->value($pb->value() + 1);
	$pb and PGK::Pfresh();
#use Data::Dumper; print Dumper \%items;
	my %dated = processDatedFile("dated.txt",\%items,$out,$opt);
#print ";;;" . Dumper %dated;
	while ($dp <= $ds) {
		processDay($dp,$r,\%items,$out,$opt);
		addDatedToday($r,\%items,($dated{$dp->ymd()} or []),$dp,$out,$opt); # TODO: Add items from %dated ($dated{$dp})
#		print $dp->ymd() . " ... " . Dumper \@{$dated{$dp->ymd()}};
		$pb and $pb->value($pb->value() + 1);
		$dp = $dp + DateTime::Duration->new( days=> 1 );
		$pb and PGK::Pfresh();
	}
	return 0;
}
print ".";

sub remove {
	my ($rss,$item) = @_;
	my @items = @{ $rss->{items} };
	my $name = $items[$item]->{title};
	$rss->{items} = \@items;
	$rss->{delete} = [] unless defined $rss->{delete};
	push(@{ $rss->{delete} },$items[$item]->{guid});
	print "Item $item, $name, marked for deletion.\n";
}
print ".";

sub updateTime {
	my ($rss) = shift;
	my $tz = Sui::getTZ();
	my $us = substr(timeAsRSS(DateTime->now),0,-5);
	$us .= $tz;
	$rss->channel(pubDate => $us);

}
print ".";

print " OK; ";
1;
