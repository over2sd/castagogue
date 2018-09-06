package PGUI;
print __PACKAGE__;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( );

use FIO qw( config );
use PGK;
use Prima qw( ImageViewer Sliders );
use Common qw( missing );
use Options;
use RRGroup;
use RItem;
use strict;
use warnings;

=head1 NAME

PGUI - A module for Prima GUI elements

=head2 DESCRIPTION

A library of functions used to build and manipulate the program's Prima user interface elements.

=head3 Functions

=cut

package PGUI;

my @openfiles = [];

=item resetScheduling TARGET

Given a TARGET widget, generates the list widgets needed to perform the Scheduling page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

sub resetScheduling {
	my ($args) = @_;
	my $schpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	my $bgcol = $$args[1];
	$schpage->empty(); # start with a blank slate
	my $panes = $schpage->insert( HBox => name => 'splitter',  pack => { fill => 'both', expand => 0 }, );
	my $lister = $panes->insert( VBox => name => "Input", pack => {fill => 'y', expand => 0}, backColor => PGK::convertColor($bgcol),  );
	$lister->insert( Label => text => "Choose a file of image descriptions:");
	my $tar = [];
	my $sched = 1;
	my $stage = $panes->insert( VBox => name => "stager", pack => { fill => 'both' }, );
	my $prev = $stage->insert( VBox => name => "preview", pack => { fill => 'both' }, );
	my $tb = labelBox($stage,"Content: ",'H', boxfill => 'x', boxex => 1, labfill => 'x', labex => 1, );
	my $tbi = $tb->insert( Edit => text => "This is a wonderful place to put the final description text.", pack => { fill => 'both' }, width => 400, height => 80, );
	refreshDescList($lister,$prev,$tar,$sched);

	my $op = labelBox($schpage,"Ordering page not yet coded.",'r','H', boxfill => 'none', boxex => 0, labfill => 'x', labex => 1);
# This page will be for scheduling specific images with specific dates
# buttons to load dsc files
# a pane for dsc files to load into
# when a button from a dsc file is clicked, it goes into a new pane,
#	a date widget sets the date
# This is a special date widget that allows selecting a day of the week, instead.
# a box shows the item's description, with the date applied into its description, if it contains placeholders
# box allows editing of description
# image preview for item
# another pane shows files affected by the date selected, along with the items those files already contain.
# a group of buttons to ***Write the Item into Dated File in Schedule Directory** "Save to <date>.txt" "Save to <weekday>.txt" "Save to [1st2nd3rd4th] Weekday"

}
print ".";

=item resetPublishing TARGET

Given a TARGET widget, generates the list widgets needed to perform the Publishing page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

sub resetPublishing {
	my ($args) = @_;
	my $pubpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	my $bgcol = $$args[1];
	$pubpage->empty(); # start with a blank slate
	my $box = $pubpage->insert( VBox => name => "pubpage", backColor =>  PGK::convertColor($bgcol) + 32 );
	my $ofile = labelBox($box,"Output RSS: ",'fileout','H', boxfill => 'none', boxex => 0, labfill => 'x', labex => 0);
	$ofile->set(backColor => PGK::convertColor($bgcol)); # output filename
	my $ofn = $ofile->insert( InputLine => text => "rssnew.xml");
	my $ifile = labelBox($box,"Existing RSS",'filein','H', boxfill => 'none', boxex => 0, labfill => 'x', labex => 0); # RSS template filename
	$ifile->set(backColor => PGK::convertColor($bgcol));
	my $ifn = $ifile->insert( InputLine => text => "rss.xml");
	my $datebox = $box->insert( HBox => name => "dates", backColor =>  PGK::convertColor($bgcol) + 16 );
	my $datefrom = PGK::insertDateWidget($datebox,undef,{ label => "From ", bgcol => $bgcol, }); # start date
	my $dateto = PGK::insertDateWidget($datebox,undef,{label => " to ", bgcol => $bgcol, }); # end date
	my $nextbox = labelBox($box,"Next ID",'nextid','H', boxfill => 'none', boxex => 0, labfill => 'x', labex => 0);
	$nextbox->set(backColor => PGK::convertColor($bgcol));
	my $nextid = $nextbox->insert( SpinEdit => name => 'nextid', max => 9999999, min => 0, step => 20, value => (FIO::config('Main','nextid') or 1)); # a spinner for the next ID
	$box->insert( Button => text => "Prepare...", onClick => sub { devHelp(getGUI('mainWin'),"Preparing RSS feeds"); }, );
# VBox to hold RItems
# each existing RSS item will be loaded, given a different background color than generated items.
# each RItem row should have a button to remove that item.
# each RItem should have buttons to edit values.
# svae button to write items to RSS

	my $op = labelBox($pubpage,"Publishing page not yet coded.",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
}
print ".";

sub saveSequence {
	my @lines = ();
	my $fn = shift;
	my $stat = getGUI('status');
	$stat->push("Writing sequence...");
	foreach my $i (@_) {
		next unless (ref $i eq "RItem"); # make sure we only use RItems.
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

sub loadSequence { # to load .seq files into this GUI.
	devHelp("Loading sequence files");
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
		next unless (ref $i eq "RItem"); # make sure we only use RItems.
#		print "\ndate=" . $date->ymd() . ">image=" . $i->link . ">desc=" . $i->text . ">time=" . $i->time . ">cat=" . $i->cat . ">";
		push(@lines,"date=" . $date->ymd() . ">image=" . $i->link . ">title=" . $i->title . ">desc=" . $i->text . ">time=" . $i->time . ">cat=" . $i->cat . ">");
	}
	my $fn = "schedule/dated.txt";
	$stat->push("Saving sequence to $fn...");
	return FIO::writeLines($fn,\@lines,0);
	$stat->push("Sequence saved.");
}
print ".";

sub generateSequence {
	my ($group,$container,$aref) = @_;
	my @rows = $container->widgets();
	foreach my $r (@rows) {
		next unless (ref $r eq "HBox"); # rows should be HBoxes
		my @buttons = $r->widgets();
		foreach my $b (@buttons) {
			next unless (ref $b eq "Button"); # buttons should be Buttons
			$b->set( backColor => PGK::convertColor("#FFF"), ); # blank all buttons.
			Pfresh();
		}
	}
	my @list = $group->sequence(); # randomize (or sequence) order of items
	defined $aref and push(@$aref,@list); # copy into array ref
	my $colors = FIO::config('UI','gradient');
	my @colora = split(",",$colors);
	foreach my $i (0..$#list) {
		$list[$i]->widget()->set( backColor => PGK::convertColor($colora[$i % scalar @colora]), );
		Pfresh();
	}
}
print ".";

sub itemEditor {
	my ($ri) = @_;
	my $optbox = Prima::Dialog->create( centered => 1, borderStyle => bs::Sizeable, onTop => 1, width => 300, height => 300, owner => getGUI('mainWin'), text => "Edit " . $ri->title(), valignment => ta::Middle, alignment => ta::Left,);
	my $bhigh = 18;
	my $extras = { height => $bhigh, };
	my $buttons = mb::Ok;
	my $vbox = $optbox->insert( VBox => autowidth => 1, pack => { fill => 'both', expand => 1, anchor => "nw", }, alignment => ta::Left, );
	my $nb = labelBox($vbox,"Name",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $lb = labelBox($vbox,"Link",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $tb = labelBox($vbox,"Text",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $cb = labelBox($vbox,"Category",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $ub = labelBox($vbox,"Time",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $ne = $nb->insert( InputLine => name => 'input', text => $ri->title() );
	my $le = $lb->insert( InputLine => name => 'input', text => $ri->link() );
	my $te = $tb->insert( InputLine => name => 'input', text => $ri->text() );
	my $ce = $cb->insert( InputLine => name => 'input', text => $ri->cat() );
	my $ue = $ub->insert( InputLine => name => 'input', text => $ri->time() );
	$nb->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $ri->title($ne->text); });
	$lb->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $ri->link($le->text); });
	$tb->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $ri->text($te->text); });
	$cb->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $ri->cat($ce->text); });
	$ub->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $ri->time($ue->text); });
	my $spacer = $vbox->insert( Label => text => " ", pack => { fill => 'both', expand => 1 }, );
	my $fresh = Prima::MsgBox::insert_buttons( $optbox, $buttons, $extras); # not reinventing wheel
	$fresh->set( font => applyFont('button'), );
	$optbox->execute;
}
print ".";

sub tryLoadGroup {
	my ($target,$fn,$sel,$cols,$gtype,$randbut,$timefield,$catfield,$sar) = @_;
	my %items;
	my $group = RRGroup->new(order => 1); # same order as order buttons on Ordering page
	my $item;
	my $row = -1;
	my $line = 0;
	my $odir = (FIO::config('Disk','rotatedir') or "lib");
	$fn = "$odir/$fn";
	print "\n[I] File $fn loading...";
	foreach my $l (FIO::readFile($fn,getGUI('status'))) {
		$line++;
		if ($l =~ m/row=(.+)/) {
			main::howVerbose() and print "Row $1\n";
			defined $item and $group->add($row,$item); # store the item if it's been defined.
			$item = undef;
			$row++;
			$group->rowname($row,$1);
		} elsif ($l =~ m/item=(.+)/) {
			main::howVerbose() and print "Item $1\n";
			defined $item and $group->add($row,$item); # store the item if it's been defined.
			$item = RItem->new(title => $1);
		} elsif ($l =~ m/image=(.+)/) {
			$item->link($1) if (ref $item eq "RItem");
			warn "\n[W] Image outside of item at line $line of $fn! " unless (ref $item eq "RItem");
		} elsif ($l =~ m/desc=(.+)/) {
			$item->text($1) if (ref $item eq "RItem");
			warn "\n[W] Image outside of item at line $line of $fn! " unless (ref $item eq "RItem");
		}
	}
	defined $item and $group->add($row,$item); # store the item if it's been defined.
	my $rows = scalar $group->rows();
	$target->insert( Label => text => "$rows rows loaded from $fn.", backColor => PGK::convertColor("#FFF"), );
	$sel = $target->insert( VBox => name => "buttonbox" );
	my $buttonscale = (FIO::config('UI','buts') or 15);
	my $i = 0;
	foreach my $i (0..$group->maxr()) {
		my @r = $group->row($i);
		next unless (scalar @r); # empty row deleted, skip it.
		my $row = $sel->insert( HBox => name => "row $i", pack => { fill => 'x', }, );
		$row->insert( Button => text => $group->rowname($i), height => $buttonscale + 2, pack => { fill => 'x', expand => 1 }, ); # Row name button
		$row->insert( Label => text => " ");
		foreach my $c (@r) {
			next unless (ref $c eq "RItem"); # skip bad items
			$c->widget($row->insert( Button => width => $buttonscale, height => $buttonscale, text => "", hint => $c->text() . " (" . $c->link() . ")", onClick => sub { itemEditor($c); }));
			$c->widget()->set( backColor => PGK::convertColor("#FFF"), );
		}
	}
	$gtype->onChange( sub {
		my $order = $group->order($gtype->value()); # change the group's order type.
		main::howVerbose() and print "\n[I] Order is now $order"; # say the group's order type.
		generateSequence($group,$sel,$sar); # show the effect immediately.
	} );
	$randbut->set( onClick => sub { generateSequence($group,$sel,$sar); }, ); # set button to generate a new sequence without changing order type.
	my $typical = $group->item(0,0); # just grab an item for values; the user will probably change them anyway.
	$timefield->text($typical->time);
	$catfield->text($typical->category);
	return $group;
}
print ".";

sub carpWithout {
	my ($preq,$action,$preqtxt) = @_;
	defined $preq and return 0;
	sayBox(getGUI('mainWin'),"You can't $action until you $preqtxt!");
	return 1;
}

=item resetOrdering TARGET

Given a TARGET widget, generates the list widgets needed to perform the Ordering page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

sub resetOrdering {
	my ($args) = @_;
	my $sequence = [];
	my $ordpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	my $bgcol = $$args[1];
	$ordpage->empty(); # start with a blank slate
	my $odir = (FIO::config('Disk','rotatedir') or "lib");
	opendir(DIR,$odir) or die $!;
	my @files = grep {
		/\.grp$/ # only show rotational image group files.
		&& -f "$odir/$_"
		} readdir(DIR);
	closedir(DIR);
	my $lister = $ordpage->insert( VBox => name => "Input", pack => {fill => 'both', expand => 1}, backColor => PGK::convertColor($bgcol),  );
	$lister->insert( Label => text => "Choose a group file:");
	my ($selector,$rows,$gtype,$randbut,$timee,$cate);
	my $colors = FIO::config('UI','gradient');
	$ordpage->insert( Label => text => "Ordering", pack => { fill => 'x', expand => 0}, );
	my $bgcol2 = Common::getColors(5,1,1);
	my $op2 = $ordpage->insert( HBox => name => "Color List");
	my $sides = $ordpage->insert( HBox => name => "panes", pack => { fill => 'both', anchor => 'w', expand => 0, }, );
	my $lpane = $sides->insert( HBox => name => "Input", pack => {fill => 'y', expand => 0, anchor => "w", }, alignment => ta::Left, backColor => PGK::convertColor($bgcol),  );
	my $rpane = $sides->insert( VBox => name => "Output", pack => {fill => 'both', expand => 1, anchor => "nw", }, backColor => PGK::convertColor($bgcol2), );
	foreach my $f (@files) {
		$lister->insert( Button => text => $f, onClick => sub { $lister->destroy();
			$rows = tryLoadGroup($rpane,$f,$selector,$colors,$gtype,$randbut,$timee,$cate,$sequence);
		});
	}
	$gtype = $lpane->insert( XButtons => name => "group type"); # an XButton set to select ordering
	my $llpane = $lpane->insert( VBox => name => "leftish pane" );
# Group will have:
	$gtype->arrange("top"); # vertical
	 my @types = (0,"none",1,"striped",2,"grouped",3,"mixed",4,"sequenced"); # defining the buttons
	 my $def = 1; # selecting default
	 $gtype->build("Group Type:",$def,@types); # show me the buttons
	$gtype->onChange( sub { carpWithout($rows,"set order type","choose a group"); } ); # change the group's order type.
	$randbut = $llpane->insert( Button => text => "Produce Order", onClick => sub { carpWithout($rows,"produce a sequence","choose a group") }, pack => { fill => 'x' }, ); # a randomize button to generate a new sequence.
	my $cateb = labelBox($llpane,"Category: ",'category','V', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
	$cate = $cateb->insert( InputLine => text => "");
	my $catea = $cateb->insert( Button => text => "Apply to All", onClick => sub {
			unless (carpWithout($rows,"apply a category to all in group","choose a group")) { # don't allow anything to happen before group is loaded!
				my $height = $rows->maxr(); # how many rows in group?
				foreach my $i (0..$height) { # traverse rows
					my $width = $rows->items($i); # how many columns in row?
					foreach my $j (0..$width - 1) { # traverse columns
						my $t = $rows->item($i,$j); # pick each item
						$t->cat($cate->text); # all this to set this item's category to the text box's value.
					}
				}
			}
		});
	my $timeeb = labelBox($llpane,"Publish time\n(24h form HHMM): ",'time','V', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
	$timee = $timeeb->insert( InputLine => text => "");
	my $timeea = $timeeb->insert( Button => text => "Apply to All", onClick => sub {
			unless (carpWithout($rows,"apply a publishing time to all in group","choose a group")) { # don't allow anything to happen before group is loaded!
				my $height = $rows->maxr(); # how many rows in group?
				foreach my $i (0..$height) { # traverse rows
					my $width = $rows->items($i); # how many columns in row?
					foreach my $j (0..$width - 1) { # traverse columns
						my $t = $rows->item($i,$j); # pick each item
						$t->time($timee->text); # all this to set this item's time to the text box's value.
					}
				}
			}
		});
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
		$op2->insert( Button => text => "", width => 9, height => 9, backColor => PGK::convertColor($colora[$i % ($#colora + 1)]));
	}
}
print ".";

=item itemIntoRow


=cut

sub itemIntoRow {
	my ($rows,$index,$iname,$link,$desc,$extra) = @_;
	$index = ($index == -1 ? $#$rows : $index); # -1 means last row
	my $rowob = $$rows[$index] or die "No row object found in rows array!";
	my $ti = $rowob->insert( HBox => backColor => PGK::convertColor(Common::getColors(($index % 2 ? 5 : 6),1,1)), );
	$ti->insert( InputLine => text => Common::shorten("$desc",15,3), pack => { fill => 'none', expand => 0, }  );
	$ti->{inm} = $iname;
	$ti->{link} = $link;
	$ti->{desc} = $desc;
	$ti->{cat} = $extra->{cat} if (defined $extra->{cat});
	$ti->{time} = $extra->timestamp() if (ref $extra eq "RItem");
	PGK::killButton($ti, sub { $ti->destroy(); }); #delete row from page
}
print ".";

sub slurpPane {
	my ($prev,$target,$rows,$index,$items) = @_;
	return unless (ref $prev eq "VBox");
	my @rows = $prev->get_widgets(); # prev is expected to be a VBox. Grab its children.
	foreach my $r (@rows) {
		print "The name is " . $r->name() . "..."; # the row's name will match the item's name...
		my $item;
		foreach my $it (@$items) {
			if ($it->name() eq $r->name()) {
				$item = $it;
				last;
			}
		}
		my @box = $r->get_widgets(); # each row should be an HBox containing a Label and a Button.
		defined $item and print "Seeking " . $box[0]->text() . " => " . $item->link() . "...\n"; # the row's label's text should match the item's text.
		defined $item and itemIntoRow($rows,$index,$item->name,$item->link,$box[0]->text());
	}
	$prev->empty();
}
print ".";

sub slurpButton {
	my ($target,$starget,$rows,$index,$items,$sz,$fill,$expand) = @_;
	$sz = ($sz ? $sz : 24);
	$fill = ($fill ? $fill : 'none');
	$expand = ($expand ? $expand : 0);
	return $target->insert( Button => text => ">>>", onClick => sub { return slurpPane($starget,$target,$rows,$index,$items); }, pack => { fill => $fill, expand => $expand, }, width => $sz, height => $sz );
}
print ".";

sub trySaveGroup {
	my ($target,$rows,$fnwidget,$args) = @_;
	my @lines;
	push(@lines,"next=-1,-1");
	my $fn = $fnwidget->text();
	$target->insert( Label => text => "Preparing to save file...");
	print "\n[I] I'll be saving group info into '$fn'";
	my $i = 0;
	foreach my $r (@$rows) {
		print "Row $i: ";
		foreach my $c ($r->widgets()) {
			for (ref $c) {
				if (/InputLine/) { print $c->text() . "\n";
					push(@lines,"row=" . $c->text());
				}elsif (/HBox/) {
					unless (defined $c->{inm}) {
						print "\n [W] Skipping box with missing item number: $c\n";
						next
					} else {
						push(@lines,"item=" . $c->{inm}) if (defined $c->{inm});
						push(@lines,"image=" . $c->{link}) if (defined $c->{link});
						push(@lines,"desc=" . $c->{desc}) if (defined $c->{desc});
						push(@lines,"cat=" . $c->{cat}) if (defined $c->{cat});
						push(@lines,"time=" . $c->{time}) if (defined $c->{time});
						$c->destroy();
					}
				} else {
					$c->destroy();
				}
			}
		}
		$r->destroy();
		Pfresh();
		$i++;
	}
	print $target->name();
	$target->empty();
	$target->insert( Label => text => "Saving your file as\n$fn...", autoHeight => 1 );
	Pfresh(); # redraw UI
	my $error = FIO::writeLines($fn,\@lines,1); # overwrites file!
	$target->insert( Label => text => "Save complete.\nWrote " . scalar @lines . " lines.", autoHeight => 1);
	$target->insert( Button => text => "Load/Create\nAnother", onClick => sub { $target->empty(); insertGroupLoaders($target,$$args{prev},$$args{tar},$rows,$$args{bgcol},$$args{buth}); });
	$target->insert( Button => text => "Continue to\nOrdering tab", onClick => sub { getGUI('pager')->switchToPanel("Ordering"); } );
	return $error;
}
print ".";

=item tryLoadGrouper TARGET FILE LISTPANE HASHREF HASHREF

Given a reset TARGET widget, a FILE name, a HASHREF of storable values, and a HASHREF in which to store data, loads the rows from a file and displays them for output addition

=cut
#$rpane,$f,$preview,$tar,$rows);
sub tryLoadGrouper {
	my ($target,$fn,$prev,$items,$rows,$args) = @_;
	my $orderkey = 0; # keep URLs in order
	my $odir = (FIO::config('Disk','rotatedir') or "lib");
	$fn = "$odir/$fn";
	if (-e $fn) { # existing file
		return 1 unless (-f $fn && -r _); # stop process if not a valid filename for a readable file.
	} else { # new file?
		(-r $fn) and print "File $fn created!\n";
	}
	my $stat = getGUI('status');
	$stat->push("Trying to read $fn...");
	my $size = -s $fn;
	my $create = (defined $$args{create} ? $$args{create} : 0);
	my @them = FIO::readFile($fn,$stat,$create);
	if ($#them == 0) {
		$stat->push("Zero lines found in file!");
	} elsif ($#them == 1) {
		$stat->push("One line found in file!");
	}
	$stat->push("Processing " . scalar @them . " lines...");
	my ($rowname,$nextpair,$desc,$link,$itemname,$rbox);
	my $count =0;
	my $foundrow = 0;
# rowbox (( rownameinput rowkillbutton items [[ VBoxes moved over from preview? ]] ))

	$fn =~ s/\..+$//; # remove any existing extension
	my $filebox = $target->insert( InputLine => text => "$fn.grp" );
	my $saver = $target->insert( Button => text => "Save");
	my $adder = $target->insert( Button => text => "Add Row", onClick => sub {
		my $row = $target->insert( VBox => name => "rownew", backColor => PGK::convertColor(Common::getColors(($foundrow % 2 ? 5 : 6),1)), );
		$row->insert( InputLine => text => "Unnamed Row ($foundrow)", );
		my $kill = $foundrow; # maintain scope for kill button
		slurpButton($row,$prev,$rows,$kill,$items,undef,'x');
		PGK::killButton($row, sub { splice(@$rows,$kill,1); $row->destroy(); },undef,'x'); #delete row from page and from array
		push(@$rows,$row);
		$foundrow++;
	} );
	foreach my $line (@them) {
		chomp $line;
		$line =~ m/(.*?\=)?(.*)/; # find keywords
		my $k = (defined $1 ? substr($1,0,-1) : "---"); # remove the equals sign from the keyword, or mark the line as a continued text line
		$k =~ s/\s//g; # no whitespace in keywords, please
		return -1 if ($k eq "" || $2 eq ""); # if we couldn't parse this, we won't try to build a row, or even continue.
		my $descact = 0;
		if ($k eq "desc") { # for each keyword, store data in hash
			unless ($foundrow) {
				$stat->push("Malformed file $fn gives an item description outside of a row! Aborting.");
				return -1;
			}
			$descact = 1;
			$desc = $2;
		} elsif ($descact && $k eq "---") { # this is another line of text
			unless ($foundrow) {
				$stat->push("Malformed file $fn gives an item description outside of a row! Aborting.");
				return -1;
			}
			$desc = $desc . "\n$2";
		} elsif ($k eq "image") { # the link/image that goes with the post
			unless ($foundrow) {
				$stat->push("Malformed file $fn gives a link outside of a row! Aborting.");
				return -2;
			}
			$link = $2;
			$descact = 0;
		} elsif ($k eq "row") { # should start the row record.
			itemIntoRow($rows,$foundrow -1,$itemname,$link,$desc) if (defined $link && defined $desc && defined $itemname);
			($link,$desc,$itemname) = (undef,undef,undef); # clear values so I can check for definition
			my $row = $target->insert( VBox => name => "row$foundrow", backColor => PGK::convertColor(Common::getColors(($foundrow % 2 ? 5 : 6),1)), );
			$row->insert( InputLine => text => $2 );
			my $kill = $foundrow; # maintain scope for kill button
			slurpButton($row,$prev,$rows,$kill,$items,undef,'x');
			PGK::killButton($row, sub { splice(@$rows,$kill,1); $row->destroy(); },undef,'x'); #delete row from page and from array
			$foundrow++;
			push(@$rows,$row);
		} elsif ($k eq "item") { # should start the item record.
			unless ($foundrow) {
				$stat->push("Malformed file $fn gives an item outside of a row! Aborting.");
				return -3;
			}
			itemIntoRow($rows,$foundrow -1,$itemname,$link,$desc) if (defined $link && defined $desc && defined $itemname);
			($link,$desc,$itemname) = (undef,undef,undef); # clear values so I can check for definition
			(defined $$args{debug}) and print ":";
			$count++;
			$descact = 0;
			$itemname = $2;
		} elsif ("$k" eq "next") {
			; # probably the end of the file. Do nothing.
		} else { # Oops! Error.
			warn "\n[W] I found unexpected keyword $k with value $2 in $fn" . Common::lineNo();
		}
#defined $$args{debug} and print "\n $k = $2...";
	}
	itemIntoRow($rows,$foundrow -1,$itemname,$link,$desc) if (defined $link && defined $desc && defined $itemname);
	$prev->empty();
	$fn =~ s/\..+$//; # remove any extension
	$$args{prev} = $prev;
	$$args{tar} = $items;
	$saver->set( onClick => sub { $adder->destroy(); $saver->destroy(); $filebox->hide(); trySaveGroup($target,$rows,$filebox,$args) } );
	$stat->push("Done loading $count items.");
	return 0; # success!

}
print ".";

sub refreshDescList {
	my ($resettarget,$target,$ar,$sched) = @_;
	$resettarget->empty(); # clear the box
	print ")RT: " . $resettarget->name . "...";
	my $odir = (FIO::config('Disk','rotatedir') or "lib"); # pick the directory
	my @files = FIO::dir2arr($odir,"dsc"); # get the list
	my $lister = $resettarget->insert( VBox => name => "InputList", pack => {fill => 'both', expand => 1, ipad => 3}, backColor => PGK::convertColor("#66FF99") ); # make new list box
	$lister->insert( Label => text => "Choose a description file:"); # Title the new box
	my $stat = getGUI("status");
	my $text = "building buttons..";
	foreach my $f (@files) {
			makeDescButton($lister,$f,$resettarget,$target,$ar,$sched);
			$text = "$text.";
			$stat->push($text);
	}
	$stat->push("Done. Pick a file.");
	return 0;
}
print ".";

=item tryLoadDesc TARGET FILE HASH

Given a reset TARGET widget, a FILE name, and a HASH in which to store data, loads the items from the file and displays them for inclusion input

=cut

sub tryLoadDesc {
	my ($resettarget,$fn,$target,$ar,$sched,$debug) = @_;
	my $orderkey = 0; # keep URLs in order
	my $odir = (FIO::config('Disk','rotatedir') or "lib");
	$fn = "$odir/$fn";
	return 1 unless (-e $fn && -f _ && -r _); # stop process if contents of text input are not a valid filename for a readable file.
	my $stat = getGUI('status');
	$stat->push("Trying to read $fn...");
	my @them = FIO::readFile($fn,$stat);
	if ($#them == 0) {
		$stat->push("Zero lines found in file!");
	} elsif ($#them == 1) {
		$stat->push("One line found in file!");
	}
	my $count = 0;
	my $buttonheight = (FIO::config('UI','buttonheight') or 18);
	$stat->push("Processing " . scalar @them . " lines...");
	my $ti = RItem->new();
	foreach my $line (@them) {
		chomp $line;
		$line =~ m/(.*?\=)?(.*)/; # find keywords
		my $k = (defined $1 ? substr($1,0,-1) : "---"); # remove the equals sign from the keyword, or mark the line as a continued text line
		$k =~ s/\s//g; # no whitespace in keywords, please
		return -1 if ($k eq "" || $2 eq ""); # if we couldn't parse this, we won't try to build a row, or even continue.
		my $descact = 0;
		my $i = scalar @$ar;
		if ($k eq "desc") { # for each keyword, store data in hash
			$descact = 1;
			$ti->text($2);
		} elsif ($descact && $k eq "---") { # this is another line of text
			$ti->text($ti->text() . "\n$2");
		} elsif ($k eq "url") { # the link/image that goes with the post
			$ti->link($2);
			$descact = 0;
		} elsif ($k eq "item") { # should start the item record.
			(defined $debug) and print ":";
			$count++;
			$descact = 0;
			my $pi = RItem->new( title => $ti->{title}, text => $ti->{text}, link => $ti->{link}, ); # separate the item from this loop
			$resettarget->insert( Button => # place button for adding...
				text => "Add " . Common::shorten($pi->text(),24,10),
				height => $buttonheight,
				onClick => sub {
					my $pr;
					if ($sched) {
						my $fill = 0; # filler variable
						my ($error,$server,$img,$lfp) = fetchapic($pi->link,$fill,$stat);
						return $error if $error;
						my $viewsize = 100;
						my $pic = Prima::Image->new;
						my $lfn = "$lfp$img";
						$pic->load($lfn);
						$pr = labelBox($target,$pi->text(),$pi->title(),'V', boxfill => 'both', boxex => 0, labfill => 'x', labex => 1);
						if (-r $lfp . $img ) {
							my ($pic,$iz) = showapic($lfp,$img,$viewsize);
							$pr->insert( ImageViewer =>
								name => $pi->title(), width => $viewsize, height => $viewsize,
								pack => {fill => 'none'}, image => $pic);
							Pfresh();
						}
					} else {
						$pr = labelBox($target,$pi->text(),$pi->title(),'H', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
						$pr->set( pack => { anchor => 'n', valignment => ta::Top } );
						$pr->insert( Button => # which places button for removing...
							text => "Remove",
							onClick => sub { $pr->destroy(); return 0; }, );
					}
				},
			) unless ($pi->title() eq "Unnamed");
			push(@$ar,$pi); # store record
			$ti = RItem->new( title => $2 ); # start new record, in case there are more items in this file
		} else { # Oops! Error.
			warn "\n[W] I found unexpected keyword $k with value $2.\n";
		}
#defined $debug and print "\n $k = $2...";
	}
	$resettarget->insert( Button => # place button for adding... one final button.
		text => "Add " . Common::shorten($ti->text(),24,10),
		height => $buttonheight,
		onClick => sub {
			my $pr;
			if ($sched) {
				my $fill = 0; # filler variable
				my ($error,$server,$img,$lfp) = fetchapic($ti->link,$fill,$stat);
				return $error if $error;
				my $viewsize = 100;
				my $pic = Prima::Image->new;
				my $lfn = "$lfp$img";
				$pic->load($lfn);
				$pr = labelBox($target,$ti->text(),$ti->title(),'V', boxfill => 'both', boxex => 0, labfill => 'x', labex => 1);
				if (-r $lfp . $img ) {
					my ($pic,$iz) = showapic($lfp,$img,$viewsize);
					$pr->insert( ImageViewer =>
						name => $ti->title(), width => $viewsize, height => $viewsize,
						pack => {fill => 'none'}, image => $pic);
					Pfresh();
				}
			} else {
				$pr = labelBox($target,$ti->text(),$ti->title(),'H', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
				$pr->set( pack => { anchor => 'n', valignment => ta::Top } );
				$pr->insert( Button => # which places button for removing...
					text => "Remove",
					onClick => sub { $pr->destroy(); return 0; }, );
			}
		}
	) unless ($ti->title() eq "Unnamed");
	push(@$ar,$ti) unless ($ti->title() eq "Unnamed"); # store record
	$resettarget->insert( Button => text => "Pick different file", onClick => sub { refreshDescList($resettarget,$target,$ar); }, );
	getGUI('status')->push("Done loading $count items.");
	return 0; # success!
}
print ".";

=item makeDescButton TARGET FILE PARENT PREVIEW ARRAYREF
	Makes a button for each FILE, to load its items into a given TARGET with buttons to copy that item into the PREVIEW and the ARRAYREF. Said items have the option of clearing the PARENT.
=cut
sub makeDescButton {
	my ($lister,$f,$lpane,$preview,$tar,$sched) = @_;
	my $buttonheight = (FIO::config('UI','buttonheight') or 18);
	$lister->insert( Button => text => $f, onClick => sub { $lister->destroy();
		my $error = tryLoadDesc($lpane,$f,$preview,$tar,$sched);
		$error && getGUI('status')->push("An error occurred loading $f!"); }, height => $buttonheight, );
}
print ".";

=item resetGrouping TARGET

Given a TARGET widget, generates the list widgets needed to perform the Grouping page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

sub resetGrouping {
	my ($args) = @_;
	my $ordpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	my $bgcol = $$args[1];
	$ordpage->empty(); # start with a blank slate
	my $odir = (FIO::config('Disk','rotatedir') or "lib");
	my @files = FIO::dir2arr($odir);
	my $tar = []; # Target Array Reference
	my $rows = [];
	my $buttonheight = (FIO::config('UI','buttonheight') or 18);
	$ordpage->insert( Label => text => "Grouping", pack => { fill => 'x', expand => 0}, );
	my $paner = $ordpage->insert( HBox => name => "panes", pack => {fill => 'both', expand => 1} );
	my $lpane = $paner->insert( VBox => name => "Input", pack => {fill => 'y', expand => 0} );
	my $lister = $lpane->insert( VBox => name => "InputList", pack => {fill => 'both', expand => 1, ipad => 3}, backColor => PGK::convertColor("#66FF99") );
	my $preview = $paner->insert( VBox => name => "preview", pack => {fill => 'both', expand => 1, ipad => 3, anchor => 'n', side => 'top'} );
	$preview->backColor(PGK::convertColor("#99FF99"));
	my $rpane = $paner->insert( VBox => name => "Output", pack => {fill => 'y', expand => 0} , backColor => PGK::convertColor("#ccFF99") );
	$lister->insert( Label => text => "Choose a description file:");
	foreach my $f (@files) {
		if ($f =~ /\.dsc/) { # description files
			makeDescButton($lister,$f,$lpane,$preview,$tar);
		}
	}
	my $error = insertGroupLoaders($rpane,$preview,$tar,$rows,$bgcol,$buttonheight);
}
print ".";

sub insertGroupLoaders { # we'll be doing this (placing buttons for loading/creating a GRP file) from two places.
	my ($rpane,$preview,$tar,$rows,$bgcol,$buttonheight) = @_;
	my $error = 0;
	my $grouper = $rpane->insert( VBox => name => "grouper", pack => {fill => 'both', expand => 1, ipad => 3}, backColor => PGK::convertColor($bgcol), );
	my $rowbox;
	$grouper->insert( Label => text => "Choose a group file:");
	my $newfile = $grouper->insert( HBox => name => "newbox", backColor => PGK::convertColor($bgcol), );
	my $newil = $newfile->insert( InputLine => text => "unnamed" );
	my $stat = getGUI("status");
	$newfile->insert( Button => text => "Create", onClick => sub {
				my $f = $newil->text;
				$grouper->destroy();
				$f =~ s/\..+$//; # remove any existing extension
				$f = "$f.grp"; # add GRP extension
				$error = tryLoadGrouper($rpane,$f,$preview,$tar,$rows,{bgcol => $bgcol,create => 1,buth => $buttonheight,});
				$error and $stat->push("An error occurred loading $f!"); });
	$error and return $error;
	my $odir = (FIO::config('Disk','rotatedir') or "lib");
	my @files = FIO::dir2arr($odir);
	foreach my $f (@files) {
		if ($f =~ /\.grp/) { # rotating image groups
			$grouper->insert( Button => text => $f, onClick => sub { $grouper->destroy();
				$error = tryLoadGrouper($rpane,$f,$preview,$tar,$rows,{bgcol => $bgcol, buth => $buttonheight,});
				$error and $stat->push("An error occurred loading $f!"); }, height => $buttonheight, );
		}
	}
	return $error;
}
print ".";

sub fetchapic { # fetches an image from the cache, or from the server if it's not there.
	my ($line,$hitserver,$stat,$target) = @_;
	$line =~ /(https?:\/\/)?([\w-]+\.[\w-]+\.\w+\/|[\w-]+\.\w+\/)(.*\/)*(\w+\.?\w{3})/;
	my $server = ($2 or "");
	my $img = ($4 or "");
	$img =~ s/\?.*//; # we won't want ?download=true or whatever in our filenames.
	return -1 if ($server eq "" || $img eq ""); # if we couldn't parse this, we won't even continue.
	my $thumb = (FIO::config('Net','thumbdir') or "itn");
	my $lfp = $thumb . "/";
	unless (-e $lfp . $img && -f _ && -r _) {
		$$hitserver = 1;
		$stat->push("Trying to fetch $line ($img)");
#		print("Trying to fetch $line ($img) to $lfp");
		my $failure = FIO::Webget($line,"$lfp$img");# get image from server here
		$failure and defined $target and $target->insert( Label => name => "$img", text => "$img could not be retrieved from server $2.");
	} else {
		$stat->push("Loading image $img from cache");
	}
	return (0,$server,$img,$lfp);
}
print ".";

sub showapic {
	my ($lfp,$img,$viewsize) = @_;
	my $pic = Prima::Image->new;
	my $lfn = "$lfp$img";
	$pic->load($lfn) or die "Could not load $lfn!";
#	$pic->set(scaling => 7); # ist::Hermite);
	my $iz = 1;
	if ($pic->width > $pic->height) {
		my $w = $pic->width;
		$iz = $viewsize / $pic->width; # get appropriate scale
		$pic->size($pic->height * $iz,$viewsize); # resize the image to fit our viewport
	} else {
		my $h = $pic->height;
		my $iz = $viewsize / $pic->height; # get appropriate scale
		$pic->size($viewsize,$pic->width * $iz); # resize the image to fit our viewport
	}
	return ($pic,$iz);
}
print ".";

=item tryLoadInput TARGET FILE PAUSEOBJ HASH SIZEOBJ

Given a reset TARGET widget, a FILE name, a PAUSEOBJect containing a delay in the text field, a HASH in which to store 

=cut

sub tryLoadInput {
	my ($resettarget,$fn,$pausebox,$hashr,$viewsize) = @_;
	my $collapsed = 24;
	my $expanded = 800;
	my $moment = $pausebox->value;
	my $hitserver = 0;
	my $orderkey = 0; # keep URLs in order
	$viewsize = $viewsize->value; # object to int
	$resettarget->empty(); # clear page.
	Pfresh(); # redraw UI
	$resettarget->insert( Label => text => "Describing", pack => { fill => 'x', expand => 0}, );
	return 0 unless (Common::findIn($fn,@openfiles) < 0); # don't try to load if already loaded that file.
	return 0 unless (-e $fn && -f _ && -r _); # stop process if contents of text input are not a valid filename for a readable file.
	my $stat = getGUI('status');
	my $buttonheight = (FIO::config('UI','buttonheight') or 18);
	$stat->push("Trying to load $fn...");
	my @them = FIO::readFile($fn,$stat);
	if ($#them == 0) {
		$stat->push("Zero lines found in file!");
	} elsif ($#them == 1) {
		$stat->push("One line found in file!");
	}
	my $outbox = labelBox($resettarget,"Images",'imagebox','V', boxfill => 'both', boxex => 1, labfill => 'none', labex => 0);
	my $hb = $outbox->insert( HBox => name => "$fn" ); # Left/right panes
	my $ib = $hb->insert( VBox => name => "Image Port", pack => {fill => 'y', expand => 1, padx => 3, pady => 3,} ); # Top/bottom pane in left pane
	my $vp; # = $ib->insert( ImageViewer => name => "i$img", zoom => $iz, pack => {fill => 'none', expand => 1, padx => 1, pady => 1,} ); # Image display box
	my $cap = $ib->insert( Label => text => "(Nothing Showing)\nTo load an image, click its button in the list.", autoHeight => 1, pack => {fill => 'x', expand => 0, padx => 1, pady => 1,} ); # caption label
	my $lbox = $hb->insert( VBox => name => "Images", pack => {fill => 'both', expand => 1, padx => 0, pady => 0,} ); # box for image rows
	foreach my $line (@them) {
		Pfresh();
		my ($error,$server,$img,$lfp) = fetchapic($line,\$hitserver,$stat,$lbox);
		return $error if $error;
		my $row = $lbox->insert( HBox => name => $img);
		$orderkey++; # new order key for each image found.
		my $okey = sprintf("%04d",$orderkey);# Friendly name, in string format for use as hash key for keeping image order
		$$hashr{$okey} = {}; # make a new empty hash for each image
		$$hashr{$okey}{url} = $line; # Store image url for matching with a description later
		if (-r $lfp . $img ) {
# put both of these in a row object, along with the inputline for the description
			$row->insert( Label => name => "$img", text => "Description for ");
# replace this with an Image object, so we can set the zom factor and resize the image when the user clicks on it to see it so they can describe it.
			my ($pic,$iz) = showapic($lfp,$img,$viewsize);
			my $lfn = "$lfp$img";
			my $shower = $row->insert( Button => name => "$lfn", text => "$img", height => $buttonheight, ); # button for filename
			$shower->set( onClick => sub {
				defined $vp and $vp->destroy;
				$cap->text($shower->text);
				$vp = $ib->insert( ImageViewer =>
					name => "i$img", zoom => $iz, width => $viewsize, height => $viewsize,
					pack => {fill => 'none'}, image => $pic); $::application->yield(); });
# put description inputline here.
		} else {
			$row->insert( Label => text => "$img could not be loaded for viewing." );
		}
		$row->insert( Label => text => ":");
		my $desc = $row->insert( InputLine => width => 350, name => "$line", text => "" );
		$desc->set(onLeave => sub { $$hashr{$okey}{desc} = $desc->text; });
#		$row->insert( Button => name => 'dummy', text => "Set"); # Clicking button triggers hash store, not by what the button does but by causing the input to lose focus.
#		$row->height($collapsed);
		if ($hitserver) {
			$stat->push("Waiting...");
			Pwait($moment);
			$hitserver = 0;
		}
	}
	my $of = $outbox->insert( InputLine => text => "prayers.dsc", pack => { fill => 'x', expand => 1, },);
	$outbox->insert( Button => text => "Save", pack => { fill => 'x', expand => 1, }, onClick => sub { my $ofn = $of->text; $ofn =~ s/\..+$//; $ofn = "$ofn.dsc"; $outbox->destroy(); saveDescs($ofn,$hashr,0); $stat->push("Descriptions written to $ofn."); $resettarget->insert( Label => text => "Your file has been saved.", pack => {fill => 'both', expand => 1}); $resettarget->insert( Button => text => "Continue to Grouping tab", onClick => sub { getGUI('pager')->switchToPanel("Grouping"); } ); $resettarget->insert( Label => text => scalar %$hashr . " images.", pack => {fill => 'both', expand => 1}); });
	$stat->push("Done.");
	return 0; # success!
}
print ".";

=item saveDescs FILE HASH [OVERWRITE]

Given a FILEname and a HASHref to a list of descriptions, converts the list into a format suitable for the group files the Ordering page will read. Optionally you can add a marker to blank the file before writing to it (OVERWRITE).

=cut

sub saveDescs {
	my ($fn,$hr,$overwrite) = @_;
	my $n = length keys %$hr;
	my @lines = ();
	my $verbose = FIO::config('Debug','v');
	$verbose and print "\n[I] Saving $n descriptions to $fn... ";
	foreach my $ok (sort keys %$hr) {
		next if (missing($$hr{$ok}{url}) || missing($$hr{$ok}{desc}));
		print "$ok, ";
		push(@lines,"item=$ok");
		push(@lines,"url=$$hr{$ok}{url}");
		push(@lines,"desc=$$hr{$ok}{desc}");
	}
	my $lib = (FIO::config("Disk",'rotatedir') or "lib");
	FIO::writeLines("$lib/$fn",\@lines,$overwrite);
	return 0;
}
print ".";

=item resetDescribing TARGET

Given a TARGET widget, generates the input boxes and list widgets needed to perform the Describing page's functions.
Returns 0 on completion.
Dies on error opening given directory.

=cut

sub resetDescribing {
	my ($args) = @_;
	my $imgpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	my $bgcol = $$args[1];
	$imgpage->empty(); # clear page.
	my @files = FIO::dir2arr("./","txt"); # get list of .txt files
	my ($listbox, $delaybox, $sizer,%images);
	$imgpage->insert( Label => text => "Describing", pack => { fill => 'x', expand => 0}, backColor => PGK::convertColor($bgcol), );
	my $filebox = labelBox($imgpage,"Seconds between fetches",'filechoice','H', boxfill => 'none', boxex => 0, labfill => 'x', labex => 0);
	$filebox->set(backColor => PGK::convertColor($bgcol));
#	my $fnb = $filebox->insert( InputLine => name => 'thisfile');
#	my $dl = $filebox->insert( Label => text => "Seconds between fetches");
	$delaybox = $filebox->insert( SpinEdit => name => 'cooldown', max => 600, min => 0, step => 5, value => 7);
	my $sl = $filebox->insert( Label => text => "Size of thumbnails");
	$sizer = $filebox->insert( SpinEdit => name => 'size', max => 2048, min => 100, step => 50, value => 200);
	my $lister = $imgpage->insert( VBox => name => "Input", pack => {fill => 'both', expand => 1}, backColor => PGK::convertColor($bgcol), );
	$lister->insert( Label => text => "Choose a file containing URLs:");
	foreach my $f (@files) {
		next if $f =~ /^TODO/; # Not the TODO file
		$lister->insert( Button => text => $f, onClick => sub { $lister->destroy();
			my $error = tryLoadInput($imgpage,$f,$delaybox,\%images,$sizer);
			$error and sayBox(getGUI("mainWin"),"An error occurred trying to load $f.\nPlease check the file to ensure it contains valid URLS, one on each line.");
		});
	}
	$delaybox->text("7");
	return 0;
}
print ".";

=item populateMainWin DBH GUI REFRESH

Given a DBHandle, a GUIset, and a value indicating whether or not to REFRESH the window, generates the objects that fill the main window.
At this time, DBH may be undef.
Returns 0 on successful completion.

=cut

sub populateMainWin {
	my ($dbh,$gui,$refresh) = @_;
	($refresh && (defined $$gui{pager}) && $$gui{pager}->destroy());
	my $win = $$gui{mainWin};
	my @tabs = qw( Describing Grouping Ordering Scheduling Publishing ); # TODO: generate dynamically
	my $pager = $win->insert( Pager => name => 'Pages', pack => { fill => 'both', expand => 1}, );
	$pager->build(@tabs);
	my $i = 1;
	my $color = Common::getColors(13,1,1);
	my $currpage = 0; # placeholder

	# Image tab
	my $imgpage = $pager->insert_to_page($currpage++,VBox =>
		backColor => PGK::convertColor($color),
		pack => { fill => 'both', },
	);
	$pager->setSwitchAction("Describing",\&resetDescribing,$imgpage,$color);

	# Grouping tab
	$color = Common::getColors(6,1,1);
	my $grppage = $pager->insert_to_page($currpage++,VBox =>
		backColor => ColorRow::stringToColor($color),
		pack => { fill => 'both', },
	);
	my $gp = labelBox($grppage,"Grouping page not yet coded.",'g','H', boxfill => 'both', boxex => 1, labfill => 'x', labex => 1);
	$pager->setSwitchAction("Grouping",\&resetGrouping,$grppage,$color);

	# Ordering tab
	$color = Common::getColors(10,1,1);
	my $ordpage = $pager->insert_to_page($currpage++,VBox =>
		backColor => ColorRow::stringToColor($color),
		pack => { fill => 'both', },
	);
	my $op = labelBox($ordpage,"Ordering page not yet coded.",'o','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	$op->set(backColor => PGK::convertColor($color));
	$pager->setSwitchAction("Ordering",\&resetOrdering,$ordpage,$color); # refresh this page whenever we switch to it

	# Scheduling tab
	$color = Common::getColors(7,1,1);
	my $schpage = $pager->insert_to_page($currpage++,VBox =>
		backColor => ColorRow::stringToColor($color),
		pack => { fill => 'both', },
	);
	$pager->setSwitchAction("Scheduling",\&resetScheduling,$schpage,$color); # refresh this page whenever we switch to it
	my $sp = labelBox($schpage,"Scheduling page not yet coded.",'r','H', boxfill => 'x', boxex => 1, labfill => 'x', labex => 1);
	$sp->set(backColor => PGK::convertColor($color));
	$color = Common::getColors(($i++ % 2 ? 0 : 7),1);

	# Publishing tab
	$color = Common::getColors(8,1,1);
	my $pubpage = $pager->insert_to_page($currpage++,VBox =>
		backColor => ColorRow::stringToColor($color),
		pack => { fill => 'both', },
	);
	$pager->setSwitchAction("Publishing",\&resetPublishing,$pubpage,$color); # refresh this page whenever we switch to it

	my $pp = labelBox($pubpage,"Publishing page not yet coded.",'r','H', boxfill => 'both', boxex => 1, labfill => 'x', labex => 1);
	$pp->set(backColor => PGK::convertColor($color));
	$color = Common::getColors(18,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 18", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(2,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 2", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(19,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 19", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(20,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 20", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(5,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 5", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(6,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 6", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(7,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 7", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(8,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 8", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(9,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 9", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(10,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 10", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(21,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 21", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(12,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 12", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(13,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 13", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(14,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 14", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(22,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 22", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(23,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 23", backColor => ColorRow::stringToColor($color));
	$color = Common::getColors(24,1,1);
	$pubpage->insert( Label => text => "Now is the time for all good men... 24", backColor => ColorRow::stringToColor($color));

	$pager->switchToPanel("Describing");
	$$gui{pager} = $pager;
	return 0;
}
print ".";

=item buildMenus GUI

Given a GUIset, generates the menus this program will show on its menubar.
Returns a reference to the menu array that Prima can use to build the menubar. 

=cut

sub buildMenus { #Replaces Gtk2::Menu, Gtk2::MenuBar, Gtk2::MenuItem
	my $gui = shift;
	my $menus = [
		[ '~File' => [
			['~Preferences', sub { return callOptBox($gui); }],
			[],
			['Close', 'Ctrl-W', km::Ctrl | ord('W'), sub { $$gui{mainWin}->close() } ],
		]],
		[ '~Help' => [
			['~About',sub { \&aboutBox, $$gui{mainWin} }],
		]],
	];
	return $menus;
}
print ".";

=item aboutBox TARGET

Given a TARGET parent window, displays information about the program.
Returns the return value of sayBox().

=cut

sub aboutBox {
	my $target = shift;
	return sayBox($target,Sui::aboutMeText());
}

=item callOptBox [GUI]

Given a GUIset, generates an options dialog.
Returns the return value of the option box function.

=cut

sub callOptBox {
	my $gui = shift || getGUI();
	my %options = Sui::passData('opts');
	return Options::mkOptBox($gui,%options);
}
print ".";

=item devHelp PARENT UNFINISHEDTASK

Displays a message that UNFINISHEDTASK is not done but is planned.
TODO: Remove from release.
No return value.

=cut
sub devHelp {
	my ($target,$task) = @_;
	sayBox($target,"$task is on the developer's TODO list.\nIf you'd like to help, check out the project's GitHub repo at http://github.com/over2sd/castagogue.");
}
print ".";


print " OK; ";
1;
