package Sui; # Self - Program-specific data storage
print __PACKAGE__;

=head1 Sui

Keeps common modules as clean as possible by storing program-specific
data needed by those common-module functions in a separate file.

=head2 passData STRING

Passes the data identified by STRING to the caller.
Returns some data block, usually an arrayref or hashref, but possibly
anything. Calling programs should be carefully written to expect what
they're asking for.

=cut

my %data = (
	poswt => 1.584,
	negwt => 1.7,
	disambiguations => {
		tag => ["tag_(context1)","tag_(context2)"],
		othertag => ["othertag_(context1)","othertag_(context2)"]
	},
);

sub passData {
	my $key = shift;
	for ($key) {
		if (/^opts$/) {
			return getOpts();
		} elsif (/^twidths$/) {
			return getTableWidths();
		} else {
			return $data{$key} or undef;
		}
	}
}
print ".";

sub storeData {
	my ($key,$value) = @_;
	defined $key and defined $value or return undef;
	return $data{$key} = $value;
}
print ".";

#new for castagogue
=item expandMe()
	Expand text ($text) with replacements of keywords, using a dateTime ($date).
	Returns altered input.
=cut
sub expandMe {
	my ($text,$date)= @_;
# replace date
	my $dstr = $date->strftime("%B %d, %Y");
	$text =~ s/%date%/$dstr/;
	my $gogue = FIO::config('Main','orgname') or "Missing Name";
	$text =~ s/%name%/$gogue/;
	return $text;
}
print ".";

sub getTZ {
	my $t = FIO::config('Main','tz'); # pull timezone from config
	my $s = ($t<0?"-":"+"); # save the sign
	$t = ($t<0?-100:100) * $t; # convert offset to hours
	return sprintf("%s%04i",$s,$t); # return TZ offset as nice string.
}
print ".";

# Status hashes
sub getStatHash { my $typ = shift; return (wat=>($typ eq 'man' ? "Read" : "Watch") . "ing",onh=>"On-hold",ptw=>"Plan to " . ($typ eq 'man' ? "Read" : "Watch"),com=>"Completed",drp=>"Dropped"); } # could be given i18n
sub getStatOrder { return qw( wat onh ptw com drp ); }
sub getStatIndex { return ( ptw => 0, wat => 1, onh => 2, rew => 3, com => 4, drp => 5 ); }
sub getStatArray {
	my $sa = [];
	my %stats = (getStatHash(shift),rew=>"Re" . ($typ eq 'man' ? "read" : "watch") . "ing");
	foreach (qw( ptw wat onh rew com drp )) {
		push(@$sa,$stats{$_});
	}
	return $sa;
}
print ".";

sub getOpts {
	# First hash key (when sorted) MUST be a label containing a key that corresponds to the INI Section for the options that follow it!
	# EACH Section needs a label conaining the Section name in the INI file where it resides.
	my %opts = (
		'000' => ['l',"General",'Main'],
		'001' => ['c',"Save window positions",'savepos'],
##		'002' => ['x',"Foreground color ",'fgcol',"#00000"],
##		'003' => ['x',"Background color ",'bgcol',"#CCCCCC"],
		'004' => ['c',"Errors are fatal",'fatalerr'],
		'005' => ['t',"Name of organization",'orgname'],
		'006' => ['n',"Time Zone Offset (from GMT)",'tz'],
		
		'030' => ['l',"User Interface",'UI'],
		'032' => ['n',"Shorten names to this length",'namelimit',20,15,100,1,10],
		'039' => ['x',"Header background color code: ",'headerbg',"#CCCCFF"],
		'03a' => ['c',"Show count in section tables",'linenos'],
		'03d' => ['x',"Background for list tables",'listbg',"#EEF"],
		'043' => ['x',"Background for letter buttons",'letterbg',"#CFC"],
		'040' => ['c',"Show a horizontal rule between rows",'rulesep'],
		'041' => ['x',"Rule color: ",'rulecolor',"#003"],
		'042' => ['n',"How many rows per column in file lists?",'filerows',10,3,30,1,5],

		'100' => ['l',"Network",'Net'],
		'101' => ['c',"Save bandwidth by saving iamge thumbnails",'savethumbs'],
		'102' => ['t',"Thumbnail Directory",'thumbdir'],

		'750' => ['l',"Fonts",'Font'],
		'754' => ['f',"Tab font/size: ",'label'],
		'751' => ['f',"General font/size: ",'body'],
		'755' => ['f',"Special font/size: ",'special'], # for lack of a better term
		'752' => ['f',"Progress font/size: ",'progress'],
		'753' => ['f',"Progress Button font/size: ",'progbut'],
		'754' => ['f',"Major heading font/size: ",'bighead'],
		'755' => ['f',"Heading font/size: ",'head'],
		'756' => ['f',"Sole-entry font/size: ",'bigent'],

		'870' => ['l',"Custom Text",'Custom'],
		'876' => ['t',"Options dialog",'options'],

		'877' => ['l',"Table",'Table'],
		'878' => ['c',"Statistics summary",'statsummary'],
		'879' => ['c',"Stats include median score",'withmedian'],
		'87f' => ['g',"Column Widths",'label'],
		'88a' => ['g',"Rows:",'label'],
		'88b' => ['n',"Height",'t1rowheight',60,0,600,1,10],

		'ff0' => ['l',"Debug Options",'Debug'],
		'ff1' => ['c',"Colored terminal output",'termcolors'],
	);
	return %opts;
}
print ".";

sub getTableWidths {
	my @list = ((FIO::config('Table','t1c0') or 20));
	push(@list,(FIO::config('Table','t1c1') or 140));
	push(@list,(FIO::config('Table','t1c2') or 100));
	return @list;
}
print ".";

sub getDefaults {
	return (
		['Main','nextid',1],
		['Main','savepos',1],
		['UI','notabs',1],
		['Font','bigent',"Verdana 24"],
		['Main','orgname',"The Unnamed Congregation"],
		['Main','tz',-6],
		['Net','savethumbs',1],
		['Net','thumbdir',"itn"],
	);
}
print ".";

my %outputstore = (
	'facprice' => [],
);

sub registerOutputs {
	my ($key,$object) = @_;
	unless (exists $outputstore{$key}) {
		$outputstore{$key} = [];
	}
	push(@{ $outputstore{$key} },$object);
}
print ".";

sub getOutputs {
	my ($key) = @_;
	return ($outputstore{$key} or []);
}
print ".";

sub poll {
	my ($key,$object) = @_;
	my $input = passData($key);
	$object->poll($input);
}
print ".";

package RRGroup; # Groups for random rotation
# A monthly rotation may be achieved with an RRGroup of 30/31/61 rows
=head2 RRGroup

A group for storing randomizeable lists containing names and descriptions in rows for easy manipulation.
	
=head3 Usage

 my $group = RRGroup->new(order => "striped");
 my ($index,$length) = $group->add(0,{name => "Tom Swift", age => 32},{name => "Harry Houdini", age => 27},{name => "John Smith", address => "1 Any St."});

=head3 Methods

=cut
sub new {
	my ($class,%profile) = @_;
	my $order = ${RRGroup->order(-2)}{$profile{order}}; # given value might need conversion.
	my $self = {
		order => ($order or 0),
		rows => ( $profile{rows} || []),
	};
	bless $self,$class;
	return $self;
}

sub add { # add hashes to a row.
	my ($self,$rownum,@rows) = @_;
	my $r = $self->{rows}; # grab our list of rows
	my $max = ($#$r < 0 ? 0 : $#$r); # find the highest available row
	while ($max < $rownum) { # if higher than existing:
		my $newrow = []; # add a new row, as user indicated desire for a higher row
		push(@$r,$newrow); # push the new row into the list of rows
		$max = $#$r; # update max, since we're about to use it
	}
	unless (defined $$r[$rownum]) { $$r[$rownum] = []; } # failsafe
	$r = $$r[$rownum]; # row established. Use this row.
	$max = ($#$r < 0 ? 0 : $#$r); # find the highest available row
	my $length = 0;
	for (my $i = 0; $i <= $#rows; $i++) {
		my %tr;
		foreach my $k (keys %{$rows[$i]}) {
			$tr{$k} = ${$rows[$i]}{$k};
		}
		$length++;
		push(@$r,\%tr);
	}
	return ($max,$length);
}

sub item {
	my ($self,$rownum,$item) = @_;
	return {error => -1} unless (defined $rownum && $rownum >= 0 && $rownum <= $self->rows()); # choke if not given a valid row.
	return {error => -2} unless (defined $item && $item >= 0 && $item <= $self->items($rownum)); # choke if not given a valid item.
	my @r = $self->row($rownum);
	return %{$r[$item]}; # return the hash
}

sub items { # gets the number of items in a row
	my ($self,$rownum) = @_;
	return scalar($self->row($rownum));
}

sub order { # get or set the order
	my ($self,$order) = @_;
	my %values = ( "none" => 0, "striped" => 1, "grouped" => 2, "mixed" => 3,);
	$order = ($values{$order} or $order);
	return \%values if ($order == -2);
	if ($order == -1) {
		foreach my $k (keys %values) {
			return $k if $values{$k} == $self{order}; # if given "-1", try to return the name of the order instead of its code value.
		}
		return "ERROR"; # prevent the order from being overwritten with -1 in case of invalid value.
	}
	$self{order} = int($order) if (defined $order);
	return $self{order};
}

sub rows {
	my $self = shift;
	my $r = $self->{rows}; # grab our list of rows
	return scalar(@{$r}); # number of rows.
}

sub row {
	my ($self,$rownum) = @_;
	my $r = $self->{rows}; # grab our list of rows
	my $max = ($#$r < 0 ? 0 : $#$r); # find the highest available row
	if ($max < $rownum) { # if higher than existing:
		return []; # Just return an empty array. The user is responsible for not looping infinitely.
	}
	$r = $$r[$rownum]; # row established. Use this row.
	return @{$r}; # if found, return the array of hashes.
}
print ".";

print "OK; ";
1;
