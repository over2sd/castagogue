package PGUIorde;
print "(O";# . __PACKAGE__;

require Exporter;

use FIO qw( config isReal );
use PGK qw( labelBox getGUI sayBox Pdie Pwait Pager Pfresh applyFont VBox HBox labeledRow );
use Common qw( missing infMes );

####### Common GUI functions ###
sub carpWithout { return PGUI::carpWithout(@_); }
sub devHelp { return PGUI::devHelp(@_); }
sub fetchapic { return PGUI::fetchapic(@_); }
sub showapic { return PGUI::showapic(@_); }

=head1 NAME

PGUIorde - A module for Prima GUI elements: Ordering editor panel

=head2 DESCRIPTION

A library of functions used to build and manipulate the program's Prima user interface elements.
This submodule contains the functions used for the ordering of grouped Items into sequences and pools for selection or iteration by the RSS scheduler.

=head3 Functions

=item resetOrdering TARGET

Given a TARGET widget, generates the list widgets needed to perform the Ordering page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

sub resetOrdering {
	my ($args) = @_;
	my $sequence = [];
	my $ordpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	Sui::storeData('context',"Ordering");
	my $bgcol = $$args[1];
	$ordpage->empty(); # start with a blank slate
	my $odir = (FIO::config('Disk','rotatedir') or "lib");
	opendir(DIR,$odir) or die $!;
	my @files = grep {
		/\.grp$/ # only show rotational image group files.
		&& -f "$odir/$_"
		} readdir(DIR);
	closedir(DIR);
	$ordpage->insert( Label => text => "Ordering", pack => { fill => 'x', expand => 0}, );
	my $lister = $ordpage->insert( VBox => name => "Input", pack => {fill => 'both', expand => 1}, backColor => PGK::convertColor($bgcol),  );
	$lister->insert( Label => text => "Choose a group file:");
	my ($selector,$rows,$gtype,$randbut,$timee,$cate);
	my $colors = FIO::config('UI','gradient');
	my $bgcol2 = Common::getColors(5,1,1);
	my $op2 = $ordpage->insert( HBox => name => "Color List");
	my $sides = $ordpage->insert( HBox => name => "panes", pack => { fill => 'both', anchor => 'w', expand => 0, }, );
	my $lpane = $sides->insert( HBox => name => "Input", pack => {fill => 'y', expand => 0, anchor => "w", }, alignment => ta::Left, backColor => PGK::convertColor($bgcol),  );
	my $rpane = $sides->insert( VBox => name => "Output", pack => {fill => 'both', expand => 1, anchor => "nw", }, backColor => PGK::convertColor($bgcol2), );
	foreach my $f (@files) {
		$lister->insert( Button => text => $f, onClick => sub { $lister->destroy();
			$rows = PGUI::tryLoadGroup($rpane,$f,\$selector,$colors,$sequence,(gtype => $gtype,rbut => $randbut, time => $timee, cat => $cate,));
		});
	}
	$gtype = $lpane->insert( XButtons => name => "group type"); # an XButton set to select ordering
	my $llpane = $lpane->insert( VBox => name => "leftish pane" );
# Group will have:
	$gtype->arrange("top"); # vertical
	my @types = (0,"none",1,"striped",2,"grouped",3,"mixed",4,"sequenced"); # defining the buttons
	my $def = 1; # selecting default
	$gtype->build("Group Type:",$def,@types); # show me the buttons
	$gtype->onChange( sub { carpWithout($rows,"set order type","choose a group"); } ); # change the group's order type. Choosing a group makes this button do something
	$randbut = $llpane->insert( Button => text => "Produce Order", onClick => sub { carpWithout($rows,"produce a sequence","choose a group") }, pack => { fill => 'x' }, ); # a randomize button to generate a new sequence. Choosing a group makes this button do something.
	$cate = PGUI::makeCatButtonSet($llpane,\$rows);
	$timee = PGUI::makeTimeButtonSet($llpane,\$rows);

	my $savings = $llpane->insert( HBox => name => "savers" );
	my $saveas;
	my $saver = $savings->insert( Button => text => "Save as...", onClick => sub { carpWithout($rows,"save a sequence","choose a group") or saveSequence($saveas->text(),$sequence); }, ); # a button to save group into a group file.
	$saveas = $savings->insert( InputLine => name => 'seq', text => 'my.seq', ); # an InputLine to hold the sequencing.
	my $savecal = $llpane->insert( VBox => name => "box" );
	my $calent = PGK::insertDateWidget($savecal,undef,{ label => "Start on:", }, ); # a date widget to show the starting date of the ordering (used for sequenced groups)
	my $sl = $savecal->insert( Label => text => "Length of Sequence");
	my $seqlen = $savecal->insert( SpinEdit => name => 'size', max => 365, min => 1, step => 5, value => 10, width => 50);
	my $savedate = $savecal->insert( Button => text => "Save to dated.txt", onClick => sub { carpWithout($rows,"save a sequence","choose a group") or saveDatedSequence($calent->text,$seqlen->value,$sequence); }, );
	$op2->insert( Label => text => "Gradient Order:" );
	my @colora = split(",",$colors);
	foreach my $i (0..$#colora) {
		next if ($i > 24);
		# TODO: Option - show sequence positions; enabling makes bigger buttons but shows number of Item's position in sequence.
		$op2->insert( Button => text => "", width => 9, height => 9, backColor => PGK::convertColor($colora[$i % ($#colora + 1)]));
	}
	my $gui = getGUI();
	my @images = PGUI::loadDatedDays($$gui{status},1);
	my $rcb = $llpane->insert( Button => text => "Recurring Item Library", onClick => sub { PGUI::showRecurLib($ordpage,$bgcol,\@images,$odir); }, pack => { fill => 'x', expand => 0, }, );
}
print ".";

sub saveSequence {
	my @lines = ();
	my $fn = shift;
	my $stat = getGUI('status');
	$stat->push("Writing sequence...");
	foreach my $i (@_) {
		# TODO: Add a counter for non RItems passed to us. x++ here and x-- after check for RItem; then warn at end.
		next unless (ref $i eq "RItem"); # make sure we only use RItems.
		unless (defined $i->link && defined $i->title && defined $i->text) {
			my $es = "Subject RItem  passed to saveSequence does not contain all required data " . Common::lineNo(2);
			print "$es\n";
			$stat->push($es);
			next;
		}
		print "\n " . $i->link() . ": " . $i->text() . " @" . $i->time() . " (" . $i->cat() . ")";
		push(@lines,"image=" . $i->link . ">title=" . $i->title . ">desc=" . $i->text . ">time=" . $i->time . ">cat=" . $i->cat . ">");
	}
	my $odir = (FIO::config('Disk','rotatedir') or "lib");
	$fn =~ s/\..+$//; # remove any existing extension
	$fn = "$odir/$fn.seq";
	$stat->push("Saving sequence to $fn...");
	return FIO::writeLines($fn,\@lines,0);
	$stat->push("Sequence saved.");
}
print ".";

sub saveDatedSequence {
	my @lines = ();
	use DateTime;
	use DateTime::Format::DateParse;
	my $stat = getGUI('status');
	my $datestr = shift;
	if ($datestr eq "0000-00-00") {
		carpWithout(undef,"save a dated sequence","choose a date");
		return -1;
	}
	my $date = DateTime::Format::DateParse->parse_datetime( $datestr );
	my $end = shift;
	my $l = 0;
	$stat->push("Running dates from " . $date->ymd() . " for $end days.");
	my $seq = shift;
	unless (scalar @$seq) {
		carpWithout(undef,"save a dated sequence","generate a sequence");
		$stat->push("Failed to write sequence: No sequence to write!");
		return -2;
	}
	foreach my $i (@$seq) {
		next if ($l++ > $end);
#		print "$l,";
		# TODO: Add a counter for non RItems passed to us. x++ here and x-- after check for RItem; then warn at end.
		next unless (ref $i eq "RItem"); # make sure we only use RItems.
		unless (defined $i->link && defined $i->title && defined $i->text) {
			my $es = "Subject RItem passed to saveDatedSequence does not contain all required data " . Common::lineNo(2);
			print "$es\n";
			$stat->push($es);
			next;
		}
#		print "\ndate=" . $date->ymd() . ">image=" . $i->link . ">desc=" . $i->text . ">time=" . $i->time . ">cat=" . $i->cat . ">";
		push(@lines,"date=" . $date->ymd() . ">image=" . $i->link . ">title=" . $i->title . ">desc=" . $i->text . ">time=" . $i->time . ">cat=" . $i->cat . ">");
		$date += DateTime::Duration->new( days=> 1 );
	}
	my $fn = "schedule/dated.txt";
	$stat->push("Saving sequence to $fn...");
	my $e = FIO::writeLines($fn,\@lines,0);
	$stat->push("Sequence saved.");
	return $e;
}
print ".";

print "ok) ";
1;
