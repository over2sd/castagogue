package FIO;

use Config::IniFiles;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( config saveConf loadConf );
print __PACKAGE__;
require Common;

my $cfg = Config::IniFiles->new();
my $cfgread = 0;
my $emptywarned = 0;

Common::registerErrors('FIO::config',"\n[W] Using empty configuration!");
=item config SECTION KEY VALUE

Given an Ini SECTION and a KEY, returns the value of that key, if it is
in the Ini, or undef. Given a VALUE also, sets the KEY in the SECTION
to that VALUE.

=cut
sub config {
	my ($section,$key,$value) = @_;
	unless (defined $value) {
		unless ($cfgread or $emptywarned) {
			$emptywarned++;
			Common::errorOut('FIO::config',1,fatal => 0,trace => 0, depth => 1 ); }
		if (defined $cfg->val($section,$key,undef)) {
			return $cfg->val($section,$key);
		} else {
			return undef;
		}
	} else {
		if (defined $cfg->val($section,$key,undef)) {
			return $cfg->setval($section,$key,$value);
		} else {
			return $cfg->newval($section,$key,$value);
		}
	}
}
print ".";

sub cfgrm {
	my ($section,$key) = @_;
		if (defined $cfg->val($section,$key,undef)) {
			my $rv = $cfg->val($section,$key,undef);
			$cfg->setval($section,$key,undef);
			return $rv; # return the old value instead of success/failure
		} else {
			return undef;
		}
}
print ".";

sub validateConfig { # sets config values for missing required defaults
	my %defaults = (
		"width" => 480,
		"height" => 480,
		"savepos" => 0
		);
	foreach (keys %defaults) {
		unless (config('Main',$_)) {
			config('Main',$_,$defaults{$_});
		}
	}
	unless (config('Font','bighead')) {
		config('Font','bighead',"Arial 24");
	}
}
print ".";

sub saveConf {
	my $debug = $cfg->val('Debug','v',undef); # store the value of debug verbosity level
	my $flex = $cfg->val('DB','FlexSQLisloaded',undef); # and DB module
	$cfg->setval('Debug','v',undef); # don't output the command-line option for verbosity
	$cfg->setval('DB','FlexSQLisloaded',undef); # don't output option saying we've loaded FlexSQL module
	$cfg->RewriteConfig();
	$cfg->setval('Debug','v',$debug); # put the option back, in case program is still running
	$cfg->setval('DB','FlexSQLisloaded',$flex); # this one, too
	$cfgread = 1; # If we're writing, I'll assume we have some values to use
}
print ".";

sub loadConf {
	my $configfilename = shift || "config.ini";
	$cfg->SetFileName($configfilename);
	Common::infMes("Seeking configuration file...",1);
	if ( -s $configfilename ) {
		print "found. Loading...";
		$cfg->ReadConfig();
		$cfgread = 1;
	}
	validateConfig();
}
print ".";

sub gz_decom {
	my ($ifn,$ofn,$guiref) = @_;
	my $window = $$guiref{mainWin};
	use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
	sub gzfail { 
		PGK::sayBox(@_);
		return 0;
		}
#TODO: Make sure the failure return value passes through.
	gunzip($ifn => $ofn, Autoclose => 1)
		or gzfail($window,$GunzipError);
	return 1;
}
# TODO: Check this function more thoroughly to see if it does what is expected.
print ".";

sub getFileName {
	my ($caller,$parent,$guir,$title,$action,$oktext,$filter) = @_;
	unless (defined $parent) { $parent = $$guir{mainWin}; }
	$$guir{status}->push("Choosing file...");
	my $filebox = ($action eq 'open' ? Prima::OpenDialog->new(
		filter => $filter,
		fileMustExist => 1
	) : Prima::SaveDialog->new(
		filter => $filter,
		multiSelect => 0,
		noReadOnly => 1,
	));
	my $filename = undef;
	if ($filebox->execute()) {
		$filename = $filebox->fileName;
	} else {
		$$guir{status}->text("$oktext cancelled.");
	}
	$filebox->destroy();
	return $filename;
}
print ".";

sub readFile {
	my $fh;
	my ($fn,$stat,$create) = @_;
	unless (open($fh,"<$fn")) { # open file
		$create and return ();
		$stat and $stat->push("\n[E] Error opening file '$fn': $!" );
		config('Main','fatalerr') && die "I am slain by unopenable file $fn because $!";
		return ();
	} else {
		$stat and $stat->push("Loaded $fn...");
		chomp (my @lines = <$fh>);
		close($fh);
		return @lines;
	}
}
print ".";


sub openOutfile {
	my ($fn,$mode) = @_;
	my $fail = 0;
	my $outputfilehandle;
	if ($fn eq '-') { return *STDOUT; }
	if ($mode) { # overwrite
		open ($outputfilehandle, ">$fn") || ($fail = 1);
	} else { # append
		open ($outputfilehandle, ">>$fn") || ($fail = 1);
	}
	if ($fail) { print "\n[E] Dying of file error trying to open $fn for writing: $! Woe, I am slain!"; exit(-1); }
	return $outputfilehandle;
}

sub writeLines {
	my ($fn,$aref,$overwrite) = @_;
	my $fh = openOutfile($fn,$overwrite);
	die "FIO::writeLines was not given an ARRAYREF" unless $aref =~ /^ARRAY/;
	foreach my $l (0 .. $#$aref) {
		my $line = @{$aref}[$l];
		print $fh "$line\n";
	}
	return 0;
}

sub Webget {
	my ($uri,$lfn,$out) = @_;
	require WWW::Mechanize;
	my $getter = WWW::Mechanize->new;
	$getter->get($uri);
	if ($getter->success()) {
		$out and $out->push("Saving $lfn...");
		$getter->save_content($lfn);
		return 0;
	} else {
		$out and $out->push("$lfn could not be retrieved.");
		return 1;
	}
}
print ".";

sub dir2arr {
	my ($odir,$ext) = @_;
	opendir(DIR,$odir) or die $!;
	my @files;
#print "Looking for " . ($ext ? $ext : "all") . " files in $odir...";
	if (defined $ext and "$ext" =~ /\w+/) {
		@files = grep {
			/\.\Q$ext\E$/ && # only show files with this extension.
			-f "$odir/$_"
		} readdir(DIR);
	} else {
		@files = grep { -f "$odir/$_" } readdir(DIR); # show all files.
	}
	closedir(DIR);
#print scalar @files . " files found.";
	return @files; # return array of file names.
}
print ".";

print " OK; ";
1;
