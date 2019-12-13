package PGUIpubl;
print "(P";# . __PACKAGE__;

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

PGUIpubl - A module for Prima GUI elements: Publishing panel

=head2 DESCRIPTION

A library of functions used to build and manipulate the program's Prima user interface elements.
This submodule contains the functions used to turn scheduled posts into a published RSS feed.

=head3 Functions

=item resetPublishing TARGET

Given a TARGET widget, generates the list widgets needed to perform the Publishing page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

sub resetPublishing {
	my ($args) = @_;
	my $pubpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	Sui::storeData('context',"Publishing");
	my $bgcol = $$args[1];
	Sui::storeData('background',PGK::convertColor($bgcol));
	my $gui = getGUI();
	$pubpage->empty(); # start with a blank slate
	my $box = $pubpage->insert( VBox => name => "pubpage", backColor =>  PGK::convertColor($bgcol) + 32 );
	my $ofile = labelBox($box,"Output RSS: ",'fileout','H', boxfill => 'none', boxex => 0, labfill => 'x', labex => 0);
	$ofile->set(backColor => PGK::convertColor($bgcol)); # output filename
	my $ofn = $ofile->insert( InputLine => text => "rssnew.xml");
	my $ifile = labelBox($box,"Existing RSS",'filein','H', boxfill => 'none', boxex => 0, labfill => 'x', labex => 0); # RSS template filename
	$ifile->set(backColor => PGK::convertColor($bgcol));
	my $ifn = $ifile->insert( InputLine => text => (FIO::config('Disk','template') or "rss.xml"));
	my $datebox = $box->insert( HBox => name => "dates", backColor =>  PGK::convertColor($bgcol) + 16 );
	my $datefrom = PGK::insertDateWidget($datebox,undef,{ label => "From ", bgcol => $bgcol, }); # start date
	my $dateto = PGK::insertDateWidget($datebox,undef,{label => " to ", bgcol => $bgcol, }); # end date
	my $nextbox = labelBox($box,"Next ID",'nextid','H', boxfill => 'none', boxex => 0, labfill => 'x', labex => 0);
	$nextbox->set(backColor => PGK::convertColor($bgcol));
	my $nextid = $nextbox->insert( SpinEdit => name => 'nextid', max => 9999999, min => 0, step => 20, value => (FIO::config('Main','nextid') or 1)); # a spinner for the next ID
	my ($pbut,$notebox);
	$pbut = $box->insert( Button => text => "Prepare...", onClick => sub { toRSSfromGUI($pubpage,$ifn,$ofn,$datefrom,$dateto,$nextid,$box,$notebox,$bgcol); }, );
	$notebox = $pubpage->insert( Edit => name => "notes", pack => { fill => 'both', expand => 1 }, hint => "This is a good place to store notes about your schedule.", ); # a box for writing notes
	$notebox->{lines} = $$gui{notes}; # allows the object to save its lines over the lines I'm about to load from the array stored therein
	$notebox->text(join('
',@{$$gui{notes}}) ); # Allows us to load the lines from the text file into the editor
}
print ".";

sub toRSSfromGUI {
	my ($target,$inf,$outf,$dfrom,$dto,$nextb,$victim1,$victim2,$bgcol) = @_;
	my $bg = Sui::passData('background');
	my $process = "process an RSS feed";
	my $ifn = $inf->text();
	my $ofn = $outf->text();
	my $start = $dfrom->text();
	my $end = $dto->text();
	FIO::config('Disk','template',$ifn);
	carpWithout($ifn,$process,"specify an input filename") and return;
	carpWithout($ofn,$process,"specify a target filename") and return;
	carpWithout($start,$process,"choose a starting date") and return;
	carpWithout($end,$process,"choose an ending date") and return;
# TODO: Check for valid files
	if ($start eq "0000-00-00") { $start = "today"; }
	if ($end eq "0000-00-00") { $end = "tomorrow"; }
	print "Processing RSS feed out of $ifn into $ofn from $start to $end with ID of " . (defined $nextb and defined $nextb->value() ? $nextb->value() : "" ) . ".\n";
	my $idsuggest = (defined $nextb->value() ? $nextb->value() : FIO::config('Main','nextid'));
	FIO::config('Main','nextid',$idsuggest);
	$victim1->destroy();
	$victim2->destroy();
	my $output = $target->insert( Edit => text => "", pack => { fill => 'both', expand => 1, } );
	my $pbbox = $target->insert( VBox => backColor => $bg, pack => Sui::passData('rowopts'), );
	$pbbox->insert(Label => text => "Preparation");
	my $probar1 = $pbbox->insert( Gauge => relief => gr::Raise, pack => Sui::passData('rowopts'), max => 1);
	$pbbox->insert(Label => text => "Processing");
	my $probar2 = $pbbox->insert( Gauge => relief => gr::Raise, pack => Sui::passData('rowopts'), max => 1);
	$pbbox->insert(Label => text => "Total Progress");
	my $probar3 = $pbbox->insert( Gauge => relief => gr::Raise, pack => Sui::passData('rowopts'), max => 3);
	Pfresh();
	sub Prima::Edit::push {
		my ($self,$text) = @_;
		my $lines = $self->{lines};
		push(@$lines,"
$text");
		Pfresh();
	}
	sub Prima::Edit::append {
		my ($self,$text) = @_;
		my $lines = $self->{lines};
		my $final = $$lines[-1];
		$final = $final . $text;
		$$lines[-1] = $final;
		Pfresh();
	}
	require castRSS;
	Pfresh();
	my $status = getGUI('status');
	Sui::storeData('opo',$output);
	Sui::storeData('progress',$probar1);
	1 and print "Preparing...";
	my $rss = castRSS::prepare($ifn,$output,1);
	my @existing = @{$rss->{items}}; # copy existing
	# update main progress bar
	$probar1->value($probar1->max()); # no matter what, we've left the prepare() function, so we're done with that.
	Pfresh();
	$probar3->max($probar1->max + $probar2->max);
	$probar3->value($probar1->value + $probar2->value);
	Pfresh();
	Sui::storeData('progress',$probar2);
	1 and print "Processing...";
	my $error = castRSS::processRange($rss,$start,$end,$output,1);
	# update main progress bar
	$probar2->value($probar2->max()); # no matter what, we've left processRange(), so we're done with that step.
	$probar3->max($probar1->max + $probar2->max);
	$probar3->value($probar1->value + $probar2->value);
	$output->push("Now contains " . scalar @{$rss->{items}} . " items...");
#print $rss->as_string;
	if (FIO::config('UI','preview')) {
		1 and print "Previewing...";
		$output->push("Loading items for review (see below).");
		Pfresh();
		my $review = $target->insert( VBox => name => 'review', pack => { fill => 'x', expand => 0 });# VBox to hold RItems
		# TODO: make sure this VBox has scrolling capability
		$rss = previewRSS($rss,$review,$pbbox,$output,@existing); # each existing RSS item will be loaded, given a different background color than generated items.
		# save button to write items to RSS
############### MARKER #############
		$target->insert( Button => text => "Save", onClick => sub { $_[0]->destroy(); saveItAsIs($rss,$ofn,$output,$target,$bgcol); $review->destroy(); } );
		select()->flush();
		Pfresh();
	} else {
		Pfresh();
		saveItAsIs($rss,$ofn,$output,$target,$bgcol);
	}
}
print ".";

sub previewRSS {
	my ($rss,$to,$gb,$out,@existing) = @_;
	my $bg = Sui::passData('background');
	my $bg2 = 0;
	my $vs = 32;
	sub makeReviewRow {
		my ($x,$ob,$viewsize,$color,%args) = @_;
		next unless (defined $x and defined $$x{link});
		my $ri = RItem->new( guid => $$x{guid}, title => $$x{title}, text => $$x{description}, link => $$x{link}, cat => $$x{category}, gob => $row, );
		my $date = ($$x{pubDate} or "Undefined");
		$ri->pubDate($date);
		my $row = $ob->insert( HBox => name => "row", backColor => $color, height => $viewsize + 7, );
		PGK::growRow($row);
		my $hits;
		$ri->toReviewRow($row,$ob,$viewsize,$color,%args);
		Pfresh();
	}
	my @ids = (0,);
	my $bgc1 = PGK::getPColors(12); # color
	my $bgc2 = PGK::getPColors(13);
	my $bgc = $bgc2;
	foreach my $i (@existing) {
		push(@ids,$$i{guid}); # store these to recolor existing rows later
	}
	my $ino = 0;
	foreach my $i (@{ $rss->{items}}) {
		unless (Common::findIn($$i{guid},@ids) == -1) { $bgc = $bgc1; }; # check for precendence and recolor
		makeReviewRow($i,$to,$vs,$bgc, rss => $rss, item => $ino );
		$ino++;
		$bgc = $bgc2;
	}
	$gb->destroy(); # kill the gauge box
	return $rss;
}
print ".";

sub saveItAsIs {
	my ($rss,$ofn,$output,$target,$bgcol) = @_;
############# MARKER #############
	my $count = scalar @{ $rss->{items} };
	print "Now contains $count items.";
skrDebug::dump($rss->{delete},"Deletions");
	castRSS::updateTime($rss);
	($rss->save($ofn) ? $output->push("$ofn saved.") : $output->push("$ofn could not be saved."));
	unless (FIO::config('Disk','persistentnext')) { print "nextID was " . FIO::cfgrm('Main','nextid',undef); } # reset nextID if we want to get it from the file each time.
	FIO::saveConf();
	$target->insert( Button => text => "Continue", onClick => sub { resetPublishing([$target,$bgcol]); } );
}





print "ok) ";
1;
