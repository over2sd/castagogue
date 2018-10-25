package NoGUI;
print __PACKAGE__;


package StatusBar;

sub new {
	my %self = {};
	my $ref = \%self;
	bless $ref, StatusBar;
	return $ref;
}

sub prepare {
	my $self = shift;
#	$self->set(
#		readOnly => 1,
#		selectable => 0,
#		text => ($self->text() or ""),
#		backColor => $self->owner()->backColor(),
#	);
#	$self->pack( fill => 'x', expand => 0, side => "bottom", );
	return $self; # allows StatusBar->new()->prepare() call
}

sub push {
	my ($self,$text) = @_;
	print "$text";
}

sub append {
	my ($self,$text) = @_;
	print "$text";
}
print ".";

package NoGUI;

sub callOptBox {
	my $section = shift;
	my %options = Sui::passData('opts');
	exit(mkOptBox($section,%options));
}
print ".";

sub mkOptBox {
	my ($section, %opts) = @_;
	my $foundit = 0;
	my $verbose = ($section eq "all");
	foreach my $k (sort keys %opts) {
		my $o = $opts{$k};
		if ($$o[0] eq "l") { # label for tab
			return 0 if ($foundit); # set when we find the label. If we've gotten to another label, we're done.
			if (($verbose) || ($section eq $$o[2])) {
				print "\nOptions in sections $$o[1]:";
				$foundit++ unless ($verbose); # mark the section found.
			}
		}elsif ($foundit || $verbose) { # not first option in list
			explainOpts(@$o); # explain this option
		} else {
			warn "First option in hash was not a label! mkOptBox() needs a label for the first tab";
			if (FIO::config('Main','fatalerr')) { die("mkOptBox not given label in first hash set"); }
			return -1;
		}
	}
	print "\nNo section '$section' was found in this program's option set!\n" unless $foundit;
	return 0;
}
print ".";

sub explainOpts {
	my (@a) = @_;
	unless (scalar @a > 2) { print "\n[W] Option array too short: @a - length: ". scalar @a . "."; return; } # malformed option, obviously
	my $item;
	my $t = $a[0];
	my $lab = $a[1];
	my $key = $a[2];
	my $col = ($a[3] or "#FF0000");
	splice @a, 0, 4; # leave 4-n in array
	for ($t) {
		if (/c/) {
			printf("\n  %s: a boolean value representing %s. May be 1 or 0",$key,$lab);
		}elsif (/d/) { # Date row (with calendar button if option enabled)
			printf("\n  %s: a date value representing %s. Format is not determined, as this option type has not been coded.",$key,$lab);
		}elsif (/f/) {
			printf("\n  %s: a font value representing %s. Must be a valid font identifier.",$key,$lab);
		}elsif (/g/) {
			printf("\n  %s: a group representing %s. Takes no value.",$key,$lab);
		}elsif (/m/) {
			printf("\n  %s: a bitmask value representing %s. May be any positive integer. Covers a group of boolean values in a single value.",$key,$lab);
		}elsif (/n/) {
			$col = undef if $col eq "#FF0000";
			printf("\n  %s: a numeric value representing %s. May be any integer between %s and %s (Default %s).",$key,$lab,($col or "*"),($a[0] or "*"),($a[3] or "--"));
		}elsif (/r/) {
			printf("\n  %s: a radiobutton group value representing %s. May be among these set values: %s",$key,$lab,join(@a,","));
		}elsif (/s/) {
			my $val = (FIO::config($s,$key) or "");
			printf("\n  %s: a string value representing %s. Must be one of these: %s. Currently %s",$key,$lab,join(@a,","),$val);
		}elsif (/t/) {
			printf("\n  %s: a string value representing %s. May be any string.",$key,$lab);
		}elsif (/x/) {
			printf("\n  %s: a color value representing %s. Must be in hexadecimal format, like #2468ac",$key,$lab);
		} else {
			warn "Ignoring bad option $a[0].\n";
			return;
		}
	}
}
print ".";

print "OK; ";