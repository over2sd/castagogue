package PGUIgrou;
print "(G";# . __PACKAGE__;

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

PGUIgrou - A module for Prima GUI elements: Grouping editor panel

=head2 DESCRIPTION

A library of functions used to build and manipulate the program's Prima user interface elements.
This submodule contains the functions used for grouping description Items into groups that can become a pool of Items or a series of Items.

=head3 Functions

=item resetGrouping TARGET

Given a TARGET widget, generates the list widgets needed to perform the Grouping page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

sub resetGrouping {
	my ($args) = @_;
	my $ordpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	Sui::storeData('context',"Grouping");
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
			PGUI::makeDescButton($lister,$f,$lpane,$preview,$tar);
		}
	}
#	PGUI::refreshDescList($lpane,$preview,$tar,0);
	my $error = insertGroupLoaders($rpane,$preview,$tar,$rows,$bgcol,$buttonheight);
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
			PGUI::itemIntoRow($rows,$foundrow -1,$itemname,$link,$desc) if (defined $link && defined $desc && defined $itemname);
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
			PGUI::itemIntoRow($rows,$foundrow -1,$itemname,$link,$desc) if (defined $link && defined $desc && defined $itemname);
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
	PGUI::itemIntoRow($rows,$foundrow -1,$itemname,$link,$desc) if (defined $link && defined $desc && defined $itemname);
	$prev->empty();
	$fn =~ s/\..+$//; # remove any extension
	$$args{prev} = $prev;
	$$args{tar} = $items;
	$saver->set( onClick => sub { $adder->destroy(); $saver->destroy(); $filebox->hide(); trySaveGroup($target,$rows,$filebox,$args) } );
	$stat->push("Done loading $count items.");
	return 0; # success!

}
print ".";

sub trySaveGroup {
	my ($target,$rows,$fnwidget,$args) = @_;
	my @lines;
	push(@lines,"next=-1,-1");
	my $fn = $fnwidget->text();
	$target->insert( Label => text => "Preparing to save file...");
	infMes("I'll be saving group info into '$fn'",1);
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
	$target->insert( Label => text => "Save complete.
Wrote " . scalar @lines . " lines.", autoHeight => 1);
	$target->insert( Button => text => "Load/Create \nAnother", onClick => sub { $target->empty(); insertGroupLoaders($target,$$args{prev},$$args{tar},$rows,$$args{bgcol},$$args{buth}); });
	$target->insert( Button => text => "Continue to \nOrdering tab", onClick => sub { getGUI('pager')->switchToPanel("Ordering"); } );
	return $error;
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
		defined $item and PGUI::itemIntoRow($rows,$index,$item->name,$item->link,$box[0]->text());
	}
	$prev->empty();
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

print "ok) ";
1;
