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
	return $text;
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
##		'002' => ['x',"Foreground color: ",'fgcol',"#00000"],
##		'003' => ['x',"Background color: ",'bgcol',"#CCCCCC"],
		'004' => ['c',"Errors are fatal",'fatalerr'],
		
		'030' => ['l',"User Interface",'UI'],
		'032' => ['n',"Shorten names to this length",'namelimit',20,15,100,1,10],
		'039' => ['x',"Header background color code: ",'headerbg',"#CCCCFF"],
		'03a' => ['c',"Show count in section tables",'linenos'],
		'03d' => ['x',"Background for list tables",'listbg',"#EEF"],
		'043' => ['x',"Background for letter buttons",'letterbg',"#CFC"],
		'040' => ['c',"Show a horizontal rule between rows",'rulesep'],
		'041' => ['x',"Rule color: ",'rulecolor',"#003"],
		'042' => ['n',"How many rows per column in file lists?",'filerows',10,3,30,1,5],

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

print "OK; ";
1;
