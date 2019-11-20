package PGUIdesc;
print "(D";# . __PACKAGE__;

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

PGUIdesc - A module for Prima GUI elements: Description editor panel

=head2 DESCRIPTION

A library of functions used to build and manipulate the program's Prima user interface elements.
This submodule contains the functions used to attach descriptions and titles to a list of URLs, so they can be grouped together and used more effectively.

=head3 Functions

=item resetDescribing TARGET

Given a TARGET widget, generates the input boxes and list widgets needed to perform the Describing page's functions.
Returns 0 on completion.
Dies on error opening given directory.

=cut

sub resetDescribing {
	my ($args) = @_;
	my $imgpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	Sui::storeData('context',"Describing");
	my $bgcol = $$args[1];
	$imgpage->empty(); # clear page.
	my @files = FIO::dir2arr("./","txt"); # get list of .txt files
	my ($listbox, $delaybox, $sizer,%images);
	$imgpage->insert( Label => text => "Describing", pack => { fill => 'x', expand => 0}, backColor => PGK::convertColor($bgcol), );
	my $filebox = PGUI::labelBox($imgpage,"Seconds between fetches",'filechoice','H', boxfill => 'none', boxex => 0, labfill => 'x', labex => 0);
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
	$lister->insert( Button => text => "Enter URLS Manually", onClick => sub { $lister->destroy();
		my $error = tryLoadInput($imgpage,"NONE",$delaybox,\%images,$sizer);
	});
	$delaybox->text("7");
	return 0;
}
print ".";

=item tryLoadInput TARGET FILE PAUSEOBJ HASH SIZEOBJ

Given a reset TARGET widget, a FILE name, a PAUSEOBJect containing a delay in the text field, a HASH in which to store 

=cut
my @openfiles = [];

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
	return 0 unless ($fn eq "NONE" || Common::findIn($fn,@openfiles) < 0); # don't try to load if already loaded that file.
	return 0 unless ($fn eq "NONE" || -e $fn && -f _ && -r _); # stop process if contents of text input are not a valid filename for a readable file.
	my $stat = getGUI('status');
	my @them;
	my $buttonheight = (FIO::config('UI','buttonheight') or 18);
	unless ($fn eq "NONE") { # trying to load a real file
		$stat->push("Trying to load $fn...");
		@them = FIO::readFile($fn,$stat);
		if ($#them == 0) {
			$stat->push("Zero lines found in file!");
		} elsif ($#them == 1) {
			$stat->push("One line found in file!");
		}
	}
	my $parms = [$stat,\$hitserver,$hashr,\$orderkey,$buttonheight,$collapsed,$expanded,$moment];
	sub outboxMaker {
		my ($rt,$filen,$vs,$list,$args) = @_;
		my ($sb,$hitsr,$hr,$okeyr,$buthi,$coll,$exp,$mom) = @{$args};
		$hr = {};
		my $moreitems = 0;
		my @them = @{$list};
		my $outbox = labelBox($rt,"Images",'imagebox','V', boxfill => 'both', boxex => 0, labfill => 'none', labex => 0);
		my $hb = $outbox->insert( HBox => name => "$filen", pack => {fill => 'x', expand => 1} ); # Left/right panes
		my $ib = $hb->insert( VBox => name => "Image Port", pack => {fill => 'y', expand => 1, padx => 3, pady => 3,}, width => $vs + 10 ); # Top/bottom pane in left pane
		my $vp; # = $ib->insert( ImageViewer => name => "i$img", zoom => $iz, pack => {fill => 'none', expand => 1, padx => 1, pady => 1,} ); # Image display box
		my $cap = $ib->insert( Label => text => "(Nothing Showing)\nTo load an image, click its button in the list.", autoHeight => 1, pack => {fill => 'x', expand => 0, padx => 1, pady => 1,} ); # caption label
		my $lbox = $hb->insert( VBox => name => "Images", pack => {fill => 'both', expand => 1, padx => 0, pady => 0, minHeight => $vs + 75, } ); # box for image rows
		my $groupsof = (FIO::config('UI','buttonrowmax') or 10);
#	my ($pager,@book) = pagifyGroup($lbox,scalar @them,$groupsof,$viewsize,"VBox");
		my $page = $lbox;
		if (scalar @them > $groupsof) {
			$moreitems = int((scalar @them) / $groupsof);
print "More: $moreitems (${groupsof}::" . scalar @them . ")\n";
#		$page = $book[0];
		} else {
			$groupsof = scalar @them; # make groups of total size if smaller, for use in loops.
		}
		my $pagenumber = 0;
		my $pageitem = 0;
		unless ($filen eq "NONE") { # real file...
			foreach my $ln (0 .. $groupsof) {
				my $line = shift @them;
				placeDescLine($page,$sb,$hitsr,$line,$hr,$okeyr,$vs,$buthi,\$vp,$cap,$ib,$coll,$exp,$mom,\$pageitem,\$pagenumber);
			}
		} else { # manual entry
			$outbox->insert( Button => text => "Add an image", onClick => sub {
				my %ans = PGK::askbox($outbox,"Enter Image Details",{},"url","URL:","title","Title:","desc","Description:");
				return -1 unless (exists $ans{url} and $ans{url} ne '');
				placeDescLine($page,$sb,$hitsr,$ans{url},$hr,$okeyr,$vs,$buthi,\$vp,$cap,$ib,$coll,$exp,$mom,\$pageitem,\$pagenumber,$ans{desc},$ans{title});
			} );
		}
		$moreitems and $outbox->insert( Button => text => "Skip this $groupsof items", pack => { fille => 'x', expand => 0, }, onClick => sub {
			$outbox->destroy();
			$sb->push("Skipping this screen of items.");
			outboxMaker($rt,$filen,$vs,\@them,$args);
		}, );
		my $of = $outbox->insert( InputLine => text => ($filen eq "NONE" ? "manual.dsc" : "prayers.dsc"), pack => { fill => 'x', expand => 0, },);
		$outbox->insert( Button => text => "Save", pack => { fill => 'x', expand => 0, }, onClick => sub {
			my $ofn = $of->text;
			$ofn =~ s/\..+$//;
			$ofn = "$ofn.dsc";
			$outbox->destroy();
			saveDescs($ofn,$hr,0);
			$sb->push("Descriptions written to $ofn.");
			my $cont = $rt->insert( VBox => name => "continuations", pack => {fill => 'both', expand => 1} );
			$cont->insert( Label => text => "Your file has been saved.", pack => {fill => 'both', expand => 1});
			if ($moreitems) {
				$cont->insert( Label => text => "More items were found in this file." );
				$cont->insert( Button => text => "Load page next $groupsof lines", onClick => sub { $cont->destroy(); outboxMaker($rt,$filen,$vs,\@them,$args); }, );
			}
			$cont->insert( Button => text => "Continue to Grouping tab", onClick => sub { getGUI('pager')->switchToPanel("Grouping"); } );
			$cont->insert( Button => text => "Continue to Scheduling tab", onClick => sub { getGUI('pager')->switchToPanel("Scheduling");} );
			$cont->insert( Label => text => scalar %$hr . " images.", pack => {fill => 'both', expand => 1});
		});
	}
	outboxMaker($resettarget,$fn,$viewsize,\@them,$parms);
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
	$verbose and infMes("Saving $n descriptions to $fn... ",1);
	foreach my $ok (sort keys %$hr) {
		next if (missing($$hr{$ok}{url}) || missing($$hr{$ok}{desc}) || missing($$hr{$ok}{title}));
		print "$ok, ";
		push(@lines,"item=$$hr{$ok}{title}");
		push(@lines,"url=$$hr{$ok}{url}");
		push(@lines,"desc=$$hr{$ok}{desc}");
	}
	my $lib = (FIO::config("Disk",'rotatedir') or "lib");
	FIO::writeLines("$lib/$fn",\@lines,$overwrite);
	return 0;
}
print ".";

=item placeDescLine TARGET STATUSBAR HITS LINE HASH ORDER VIEW HEIGHT PORTREF CAPTION BOX COLLAPSED EXPANDED DELAY ITEMN PAGEN DESC TITLE

Given a TARGET object, a STATUSBAR, a reference to the variable indicating
recent server HITS, a URL content LINE, a HASHref, an ORDER-by value, a button
HEIGHT, a viewPORTREFerence, a CAPTION object, an image BOX, a value for
COLLAPSED and EXPANDED heights, a DELAY for recent server hits, a reference
to the ITEMNumber, a reference to the PAGENumber, a DESCription input object,
and a TITLE input object;
Places a Line containing the editing elements for the Description of LINE:
a button to show the picture in the viewPORTREF, a DESCription, and a TITLE,
storing these in their variables passed in.
Returns nothing.

=cut

sub placeDescLine {
	my ($page,$stat,$hitserver,$line,$hashr,$orderkey,$viewsize,$buttonheight,$vp,$cap,$ib,$collapsed,$expanded,$moment,$pageitem,$pagenumber,$dtxt,$title) = @_;
	my ($error,$server,$img,$lfp) = fetchapic($line,$hitserver,$stat,$page);
	return $error if $error;
	$page->set( height => $viewsize + 7 );
	my $row = $page->insert( HBox => name => $img);
	$$orderkey++; # new order key for each image found.
	my $okey = sprintf("%04d",$$orderkey);# Friendly name, in string format for use as hash key for keeping image order
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
			defined $$vp and $$vp->destroy;
			$cap->text($shower->text);
			$$vp = $ib->insert( ImageViewer =>
				name => "i$img", zoom => $iz, width => $viewsize, height => $viewsize,
				pack => {fill => 'none'}, image => $pic); $::application->yield(); });
# put description inputline here.
	} else {
		$row->insert( Label => text => "$img could not be loaded for viewing." );
	}
	my $nt = $row->insert( InputLine => width => 50, name => "t of $line", text => (defined $title ? "$title" : "$okey") );
	$nt->set(onLeave => sub { $$hashr{$okey}{title} = $nt->text; });
	$row->insert( Label => text => ":");
	my $desc = $row->insert( InputLine => width => 350, name => "$line", text => (defined $dtxt ? $dtxt : "") );
	$desc->set(onLeave => sub { $$hashr{$okey}{desc} = $desc->text; });
#	$row->insert( Button => name => 'dummy', text => "Set"); # Clicking button triggers hash store, not by what the button does but by causing the input to lose focus.
#	$row->height($collapsed);
	if ($$hitserver) {
		$stat->push("Waiting...");
		Pwait($moment,$stat,"Waiting...");
		$$hitserver = 0;
	}
	$$pageitem++;
#	if ($$pageitem > $groupsof) { # This will only proc if we have more than 10 items, anyway.
#		$$pageitem -= $groupsof;
#		$$pagenumber++;
#		$page = $book[$$pagenumber];
#	}
	Pfresh();
}
print ".";

sub pagifyGroup {
	my ($target,$count,$pageof,$scale,$obtype,%args) = @_;
	my (@book,@pagelist); # array for the pages
	use POSIX qw( floor ); # to get the int value
	my $pages = floor($count / $pageof); # Divide and discard remainder
	return ($target,@book) unless ($pages); # if not enough for paging, just use the target.
	foreach my $i (0..$pages) {
		push(@pagelist,"page$i");
	}
	my $newtarget = $target->insert( Pager => name => "pager", pack => { fill => 'both', expand => 1, }, minHeight => $scale, minWidth => 200, );
	$newtarget->control("buttons");
	$newtarget->build(@pagelist);
	foreach my $i (0..$pages) {
		my $child = $newtarget->insert_to_page($i,$obtype => name => "page$i", %args);
		push(@book,$child);
	}
	return ($newtarget,@book);
}
print ".";

print "ok) ";
1;
