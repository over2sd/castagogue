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
	objectionablecontent => [],
);

sub passData {
	my $key = shift;
	for ($key) {
		if (/^opts$/) {
			return getOpts();
		} elsif (/^twidths$/) {
			return getTableWidths();
		} elsif (/^prereqs$/) {
			return qw(WWW::Mechanize DateTime::Format::DateParse DateTime::Format::Duration DateTime Config::IniFiles XML::LibXML::Reader XML::RSS Unknown::Module);
		} else {
			return ($data{$key} or undef);
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
	$dstr = $date->strftime("%A");
	$text =~ s/%weekday%/$dstr/;
	my $gogue = (FIO::config('Main','orgname') or "Missing Name");
	$text =~ s/%name%/$gogue/;
# if $text =~ m/%group=/ ... run group parser ### TODO ###
	$text=~ s/#x26;//g; # the XML output parser is going to expand the ampersand even if a valid entity follows it. *facepalm*
	return $text;
}
print ".";

=item expandGroup()
	Expand text pulled from a group ($groupid) with replacements of keywords, using a dateTime ($date) and put them in an RItem ($item).
	Returns altered input.
=cut
sub expandGroup{
	my ($groupid,$d,$item) = @_;
	my $parsed = expandMe($raw,$d);
	die "expandGroup is on the developer's TODO list.\nIf you'd like to help, check out the project's GitHub repo at http://github.com/over2sd/castagogue.";
}
print ".";

sub getTZ {
	my $t = FIO::config('Main','tz'); # pull timezone from config
	return $t unless ($t + 1 eq 1 + $t); # pass it back as-is if it doesn't work in arithmetic calculations; it's probably a string.
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
		'006' => ['n',"Time Zone Offset (from GMT)",'tz',-12,12,1,6],
		'007' => ['n',"By default, how many days ahead to post",'eventlead'],
		'008' => ['c',"Automatically tag post with its RSS category",'autotag'],

		'020' => ['l',"File",'Disk'],
		'021' => ['t',"Rotational Image Group files live here",'rotatedir'],
		'022' => ['c',"Keep nextID across sessions",'persistentnext'],
		'025' => ['c',"Purge old RSS items when loading",'purgeRSS'],
		
		'030' => ['l',"User Interface",'UI'],
		'032' => ['n',"Shorten names to this length",'namelimit',20,15,100,1,10],
		'039' => ['x',"Header background color code: ",'headerbg',"#CCCCFF"],
		'03a' => ['c',"Show count in section tables",'linenos'],
		'03d' => ['x',"Background for list tables",'listbg',"#EEF"],
		'043' => ['x',"Background for letter buttons",'letterbg',"#CFC"],
		'040' => ['c',"Show a horizontal rule between rows",'rulesep'],
		'041' => ['x',"Rule color: ",'rulecolor',"#003"],
		'042' => ['n',"How many rows per column in file lists?",'filerows',10,3,30,1,5],
		'043' => ['t',"Color codes for gradient (comma separated)",'gradient'],
		'044' => ['c',"Preview RSS feed before saving",'preview'],
		'045' => ['n',"Size of calendar buttons",'caldaysize',100,20,500,1,10],

		'100' => ['l',"Network",'Net'],
		'101' => ['c',"Save bandwidth by saving image thumbnails",'savethumbs'],
		'102' => ['t',"Thumbnail Directory",'thumbdir'],
		'103' => ['n',"File argument Style",'wierdRL'], # 0 = xxx.png, 1 = xxx.png?dl=1, 2 = view?asset=xxxx, 3 = view.png?asset=xxxx

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
		['UI','gradient',"#F00,#F30,#F60,#F90,#FC0,#FF0,#CF0,#9F0,#6F0,#3F0,#0F0,#0F3,#0F6,#0F9,#0FC,#0FF,#0CF,#09F,#06F,#03F,#00F,#30F,#60F,#90F,#C0F,#F0F,#F0C,#F09,#F06,#F03,#EEF,#DDE,#CCD,#BBC,#AAB,#99A,#889,#778,#667,#556,#445,#334,#223,#112,#001"],
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

sub aboutMeText {
	return "$PROGRAMNAME $version\nThis program exists to allow you to preview images in a list of URLs, type your own descriptions of them, and save the description of each file with its URL in a library castagogue can use to populate randomized lists.\nI hope you enjoy it.";
}
print ".";

print "OK; ";
1;
