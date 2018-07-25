package PGUI;
print __PACKAGE__;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( );

use FIO qw( config );
use PGK;
use Prima qw( ImageViewer Sliders );
use Common qw( missing );
use RItem;

=head1 NAME

PGUI - A module for Prima GUI elements

=head2 DESCRIPTION

A library of functions used to build and manipulate the program's Prima user interface elements.

=head3 Functions

=cut

package PGUI;

my @openfiles = [];

=item resetOrdering TARGET

Given a TARGET widget, generates the list widgets needed to perform the Ordering page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

sub resetOrdering {
	my ($args) = @_;
	my $ordpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	$ordpage->empty(); # start with a blank slate
	my $odir = (FIO::config('Disk','rotatedir') or "lib");
	opendir(DIR,$odir) or die $!;
	my @files = grep {
		/\.rig$/ # only show rotational image group files.
		&& -f "$odir/$_"
		} readdir(DIR);
	closedir(DIR);
	my $lister = $ordpage->insert( VBox => name => "Input", pack => {fill => 'both', expand => 1} );
	$lister->insert( Label => text => "Choose a file containing URLs:");
	foreach my $f (@files) {
		$lister->insert( Button => text => $f, onClick => sub { $lister->destroy();
#			tryLoadGroup($ordpage,$f);
		});
	}
	my $op = labelBox($ordpage,"Ordering page not yet coded.",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
}
print ".";

sub itemIntoRow {
	my ($rows,$index,$iname,$link,$desc) = @_;
}
print ".";

=item tryLoadGrouper TARGET FILE LISTPANE HASHREF HASHREF

Given a reset TARGET widget, a FILE name, a HASHREF of storable values, and a HASHREF in which to store data, loads the rows from a file and displays them for output addition

=cut
#$rpane,$f,$preview,$tar,$rows);
sub tryLoadGrouper {

use Data::Dumper;
	my ($target,$fn,$prev,$items,$rows) = @_;
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
	my @them = FIO::readFile($fn,$stat);
	if ($#them == 0) {
		$stat->push("Zero lines found in file!");
	} elsif ($#them == 1) {
		$stat->push("One line found in file!");
	}
	$stat->push("Processing " . scalar @them . " lines...");
	my ($rowname,$nextpair,$desc,$link,$itemname,$rbox);
	my $rows = 0;
	my $foundrow = 0;
# rowbox (( rownameinput rowkillbutton items [[ VBoxes moved over from preview? ]] ))

	devHelp(getGUI('mainWin'),"Loading group files");
return 404;
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
			my $row = $target->insert( VBox => backColor => PGK::convertColor(Common::getColors(($foundrow % 2 ? 5 : 6),1)), );
			$row->insert( InputLine => text => $2 );
			my $kill = $foundrow; # maintain scope for kill button
			$row->insert( Button => text => "X", onClick => sub { splice(@$rows,$kill,1); $row->destroy(); } ); #delete row from page and from array
			$foundrow++;
			push(@$rows,$row);
		} elsif ($k eq "item") { # should start the item record.
			unless ($foundrow) {
				$stat->push("Malformed file $fn gives an item outside of a row! Aborting.");
				return -3;
			}
			itemIntoRow($rows,$foundrow -1,$itemname,$link,$desc) if (defined $link && defined $desc && defined $itemname);
			($link,$desc,$itemname) = (undef,undef,undef); # clear values so I can check for definition
			defined $debug and print ":";
			$count++;
			$descact = 0;
		} else { # Oops! Error.
			warn "\n[W] I found unexpected keyword $k with value $2.\n";
		}
#defined $debug and print "\n $k = $2...";
	}
	$resettarget->insert( Button => # place button for adding...
		text => "Add " . $ti->text(),
		onClick => sub {
			my $pr = labelBox($target,$ti->text(),$ti->title(),'H', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
			$pr->insert( Button => # which places button for removing...
				text => "Remove",
				onClick => sub { $pr->destroy(); return 0; },
			);
		}
	) unless ($ti->title() eq "Unnamed");
	$stat->push("Done loading $count items.");
	return 0; # success!

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
	}
}

=item tryLoadDesc TARGET FILE HASH

Given a reset TARGET widget, a FILE name, and a HASH in which to store data, loads the items from the file and displays them for inclusion input

=cut

sub tryLoadDesc {
	my ($resettarget,$fn,$target,$ar) = @_;
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
			defined $debug and print ":";
			$count++;
			$descact = 0;
			my $pi = RItem->new( title => $ti->{title}, text => $ti->{text}, link => $ti->{link}, ); # separate the item from this loop
			$resettarget->insert( Button => # place button for adding...
				text => "Add " . $pi->text(),
				onClick => sub {
					my $pr = labelBox($target,$pi->text(),$pi->title(),'H', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
					$pr->set( pack => { anchor => 'n', valignment => ta::Top } );
					$pr->insert( Button => # which places button for removing...
						text => "Remove",
						onClick => sub { $pr->destroy(); return 0; },
					);
				}
			) unless ($pi->title() eq "Unnamed");
			push(@$ar,$pi); # store record
			$ti = RItem->new( title => $2 ); # start new record, in case there are more items in this file
		} else { # Oops! Error.
			warn "\n[W] I found unexpected keyword $k with value $2.\n";
		}
#defined $debug and print "\n $k = $2...";
	}
	$resettarget->insert( Button => # place button for adding...
		text => "Add " . $ti->text(),
		onClick => sub {
			my $pr = labelBox($target,$ti->text(),$ti->title(),'H', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
			$pr->insert( Button => # which places button for removing...
				text => "Remove",
				onClick => sub { $pr->destroy(); return 0; },
			);
		}
	) unless ($ti->title() eq "Unnamed");
	$stat->push("Done loading $count items.");
	return 0; # success!
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
	$ordpage->empty(); # start with a blank slate
	my $odir = (FIO::config('Disk','rotatedir') or "lib");
	opendir(DIR,$odir) or die $!;
	my @files = grep {
#		/\.dsc$/ && # only show description files.
			-f "$odir/$_"
		} readdir(DIR);
	closedir(DIR);
	my $tar = []; # Target Array Reference
	my $rows = [];
	my $paner = $ordpage->insert( HBox => name => "panes", pack => {fill => 'both', expand => 1} );
	my $lpane = $paner->insert( VBox => name => "Input", pack => {fill => 'y', expand => 0} );
	my $lister = $lpane->insert( VBox => name => "InputList", pack => {fill => 'both', expand => 1, ipad => 3}, backColor => PGK::convertColor("#66FF99") );
	my $preview = $paner->insert( VBox => name => "preview", pack => {fill => 'both', expand => 1, ipad => 3, anchor => 'n', side => 'top'} );
	$preview->backColor(PGK::convertColor("#99FF99"));
	my $rpane = $paner->insert( VBox => name => "Output", pack => {fill => 'y', expand => 0} , backColor => PGK::convertColor("#ccFF99") );
	my $grouper = $rpane->insert( VBox => name => "grouper", pack => {fill => 'both', expand => 1, ipad => 3} );
	my $rowbox;
	$lister->insert( Label => text => "Choose a description file:");
	$grouper->insert( Label => text => "Choose a group file:");
	my $newfile = $grouper->insert( HBox => name => "newbox", );
	my $newil = $newfile->insert( InputLine => text => "unnamed" );
	$newfile->insert( Button => text => "Create", onClick => sub {
				my $f = $newil->text;
				$grouper->destroy();
				$f =~ s/\..+$//; # remove any existing extension
				$f = "$f.rig"; # add RIG extension
				my $error = tryLoadGrouper($rpane,$f,$preview,$tar,$rows);
				$error && $stat->push("An error occurred loading $f!"); });
	my $stat = getGUI("status");
	foreach my $f (@files) {
		if ($f =~ /\.dsc/) { # description files
			$lister->insert( Button => text => $f, onClick => sub { $lister->destroy();
				my $error = tryLoadDesc($lpane,$f,$preview,$tar);
				$error && $stat->push("An error occurred loading $f!"); });
		} elsif ($f =~ /\.rig/) { # rotating image groups
			$grouper->insert( Button => text => $f, onClick => sub { $grouper->destroy();
				my $error = tryLoadGrouper($rpane,$f,$preview,$tar,$rows);
				$error && $stat->push("An error occurred loading $f!"); });
		}
	}
	my $op = labelBox($ordpage,"Ordering page not yet coded.",'r','H', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
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
	return 0 unless (Common::findIn($fn,@openfiles) < 0); # don't try to load if already loaded that file.
	return 0 unless (-e $fn && -f _ && -r _); # stop process if contents of text input are not a valid filename for a readable file.
	my $thumb = (FIO::config('Net','thumbdir') or "itn");
	my $stat = getGUI('status');
	$stat->push("Trying to load $fn...");
	my @them = FIO::readFile($fn,$stat);
	if ($#them == 0) {
		$stat->push("Zero lines found in file!");
	} elsif ($#them == 1) {
		$stat->push("One line found in file!");
	}
	$outbox = labelBox($resettarget,"Images",'imagebox','V', boxfill => 'both', boxex => 1, labfill => 'none', labex => 0);
	my $hb = $outbox->insert( HBox => name => "$fn" ); # Left/right panes
	my $ib = $hb->insert( VBox => name => "Image Port", pack => {fill => 'y', expand => 1, padx => 3, pady => 3,} ); # Top/bottom pane in left pane
	my $vp; # = $ib->insert( ImageViewer => name => "i$img", zoom => $iz, pack => {fill => 'none', expand => 1, padx => 1, pady => 1,} ); # Image display box
	my $cap = $ib->insert( Label => text => "(Nothing Showing)\nTo load an image, click its button in the list.", autoHeight => 1, pack => {fill => 'x', expand => 0, padx => 1, pady => 1,} ); # caption label
	my $lbox = $hb->insert( VBox => name => "Images", pack => {fill => 'both', expand => 1, padx => 0, pady => 0,} ); # box for image rows
	foreach my $line (@them) {
		$line =~ /(https?:\/\/)?([\w-]+\.[\w-]+\.\w+\/|[\w-]+\.\w+\/)(.*\/)*(\w+\.?\w{3})/;
		my $server = $2 or "";
		my $img = $4 or "";
		my $row = $lbox->insert( HBox => name => $img);
		return -1 if ($server eq "" || $img eq ""); # if we couldn't parse this, we won't try to build a row, or even continue.
		$orderkey++; # new order key for each image found.
		my $okey = sprintf("%04d",$orderkey);# Friendly name, in string format for use as hash key for keeping image order
		$$hashr{$okey} = {}; # make a new empty hash for each image
		$$hashr{$okey}{url} = $line; # Store image url for matching with a description later
		$img =~ s/\?.*//; # we won't want ?download=true or whatever in our filenames.
		my $lfp = $thumb . "/";
		unless (-e $lfp . $img && -f _ && -r _) {
			$hitserver = 1;
			$stat->push("Trying to fetch $line ($img)");
#			print("Trying to fetch $line ($img) to $lfp");
			my $failure = FIO::Webget($line,"$lfp$img");# get image from server here
			$failure and $row->insert( Label => name => "$img", text => "$img could not be retrieved from server $2.");
		} else {
			$stat->push("Loading image $img from cache");
		}
		if (-r $lfp . $img ) {
# put both of these in a row object, along with the inputline for the description
			$row->insert( Label => name => "$img", text => "Description for ");
# replace this with an Image object, so we can set the zom factor and resize the image when the user clicks on it to see it so they can describe it.
			my $pic = Prima::Image->new;
			my $lfn = "$lfp$img";
			$pic->load($lfn);
#			$pic->set(scaling => 7); # ist::Hermite);
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
			my $shower = $row->insert( Button => name => "$lfn", text => "$img",); # button for filename
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
		my $desc = $row->insert( InputLine => width => 100, name => "$line", text => "" );
		$desc->set(onLeave => sub { $$hashr{$okey}{desc} = $desc->text; });
		$row->insert( Button => name => 'dummy', text => "Set"); # Clicking button triggers hash store, not by what the button does but by causing the input to lose focus.
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
	$imgpage->empty(); # clear page.
	opendir(DIR,"./") or die "Bad ./: $!";
	my ($listbox, $delaybox, $sizer);
	my $filebox = labelBox($imgpage,"Seconds between fetches",'filechoice','H', boxfill => 'none', boxex => 0, labfill => 'x', labex => 0);
#	my $fnb = $filebox->insert( InputLine => name => 'thisfile');
#	my $dl = $filebox->insert( Label => text => "Seconds between fetches");
	$delaybox = $filebox->insert( SpinEdit => name => 'cooldown', max => 600, min => 0, step => 5, value => 7);
	my $sl = $filebox->insert( Label => text => "Size of thumbnails");
	$sizer = $filebox->insert( SpinEdit => name => 'size', max => 2048, min => 100, step => 50, value => 200);
	my $lister = $imgpage->insert( VBox => name => "Input", pack => {fill => 'both', expand => 1} );
	$lister->insert( Label => text => "Choose a file containing URLs:");
	my @files = grep {
		!/^TODO/ && # Not the TODO file
		/\.txt$/ # all text files
	} readdir(DIR);
	closedir(DIR);
	foreach my $f (@files) {
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
	my @tabs = qw( Describing Grouping Ordering Publishing Scheduling ); # TODO: generate dynamically
	my $pager = $win->insert( Pager => name => 'Pages', pack => { fill => 'both', expand => 1}, );
	$pager->build(@tabs);
	my $i = 1;
	my $color = Common::getColors(5,1);
	my $currpage = 0; # placeholder

	# Image tab
	my $imgpage = $pager->insert_to_page($currpage++,VBox =>
		backColor => PGK::convertColor($color),
		pack => { fill => 'both', },
	);
	$pager->setSwitchAction("Describing",\&resetDescribing,$imgpage);

	# Grouping tab
	$color = Common::getColors(6,1);
	my $grppage = $pager->insert_to_page($currpage++,VBox =>
		backColor => ColorRow::stringToColor($color),
		pack => { fill => 'both', },
	);
	my $gp = labelBox($grppage,"Grouping page not yet coded.",'g','H', boxfill => 'both', boxex => 1, labfill => 'x', labex => 1);
	$pager->setSwitchAction("Grouping",\&resetGrouping,$grppage);

	# Ordering tab
	$color = Common::getColors(10,1);
	my $ordpage = $pager->insert_to_page($currpage++,VBox =>
		backColor => ColorRow::stringToColor($color),
		pack => { fill => 'both', },
	);
	my $op = labelBox($ordpage,"Ordering page not yet coded.",'o','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	$pager->setSwitchAction("Ordering",\&resetOrdering,$ordpage); # reload the description buttons whenever we switch to this page, in case the user made a new dsc file on the Describing tab.

	# Publishing tab
	$color = Common::getColors(9,1);
	my $pubpage = $pager->insert_to_page($currpage++,VBox =>
		backColor => ColorRow::stringToColor($color),
		pack => { fill => 'both', },
	);
	my $pp = labelBox($pubpage,"Publishing page not yet coded.",'r','H', boxfill => 'both', boxex => 1, labfill => 'x', labex => 1);

	# Scheduling tab
	$color = Common::getColors(8,1);
	my $schpage = $pager->insert_to_page($currpage++,VBox =>
		backColor => ColorRow::stringToColor($color),
		pack => { fill => 'both', },
	);
	my $sp = labelBox($schpage,"Scheduling page not yet coded.",'r','H', boxfill => 'x', boxex => 1, labfill => 'x', labex => 1);
	$color = Common::getColors(($i++ % 2 ? 0 : 7),1);
	
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

=item sayBox PARENT TEXT

Given a PARENT window and a TEXT to display, generates a simple message box to show the text to the user.
Returns 0.

=cut

sub sayBox {
	my ($parent,$text) = @_;
	Prima::MsgBox::message($text,owner=>$parent);
	return 0;
}
print ".";

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
