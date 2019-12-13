package PGUI;
print __PACKAGE__;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( );

use FIO qw( config isReal );
use PGK qw( labelBox getGUI sayBox Pdie Pwait Pager Pfresh applyFont VBox HBox labeledRow );
use Prima qw( ImageViewer Sliders Calendar );
use Common qw( missing infMes );
use Options;
use RRGroup;
use RItem;
use strict;
use warnings;
use DateTime;

=head1 NAME

PGUI - A module for Prima GUI elements

=head2 DESCRIPTION

A library of functions used to build and manipulate the program's Prima user interface elements.

=head3 Functions

=cut

my @openfiles = [];

=item buildPageOf TARGET COUNT OFFSET EXTRAS LIST

Populates a TARGET container widget with up to COUNT objects from a LIST, starting with the OFFSETth item, if possible.
Expects EXTRAS to be a hashref that contains, at minimum:
*	action => reference of a subroutine that creates specialized objects to insert into the TARGET.
	and generally also:
*	preargs => an arrayref containing commonly applied arguments that go before the iterative argument
*	postargs => an arrayref containing commonly applied arguments that go after the iterative argument

=cut

#TODO: Move this into Pager package.
sub buildPageOf { # start of button populator. I need to have a generic version of this for the Pager class.
	my ($target,$count,$offset,$extras,@list) = @_;
	my $length = scalar @list -1;
	unless ($length >= $count + $offset) { # prevent making items beyond what has been given
		unless ($length < $offset) {
			$count = scalar @list - $offset;
		} else {
			$count = 0;
		}
	}
	foreach my $i ($offset..$offset + $count) {
		$target->insert(Button => text => $list[$i] );
	}
}

sub autoShelve { # A librarian shelves; this is going in a calendar library.
	my ($rows,$fn,$ow,$oo) = @_;
	my @output = ();
	unless (carpWithout($$rows,"add all in group to the library","choose a group")) { # don't allow anything to happen before group is loaded!
		my $height = $$rows->maxr(); # how many rows in group?
		foreach my $i (0..$height) { # traverse rows
			my $width = $$rows->items($i); # how many columns in row?
			foreach my $j (0..$width - 1) { # traverse columns
				my $t = $$rows->item($i,$j); # pick each item
				push(@output,$t->get('recur')); # all this to get this item's recurrent string to the text variable.
			}
		}
	}
	FIO::writeLines($fn,\@output,$ow);
	$oo->insert( Label => text => "Lines written." );
	$oo->insert( Button => text => "Continue to Scheduling page", onClick => sub { getGUI('pager')->switchToPanel("Scheduling"); } );
}
print ".";

sub showRecurLib {
	my ($note,$bgcol,$filarrref,$odir) = @_;
	$note->empty();
	my $tar = [];
	my $panes = $note->insert( HBox => name => 'splitter',  pack => { fill => 'both', expand => 1	 }, );
	#skrDebug::showoff($panes);
	my $lister = $panes->insert( VBox => name => "Input", pack => {fill => 'y', expand => 0}, backColor => PGK::convertColor($bgcol),  );
	my $sched = 1;
	my $prot = 0;
	my ($selector,$rows) = (undef,RRGroup->new(order => 1));
	my $stage = $panes->insert( VBox => name => "stager", pack => { fill => 'both' }, );
	my $colors = FIO::config('UI','gradient');
	my $sdir = (FIO::config('Disk','scheddir') or 'schedule');
	my $prev = $stage->insert( VBox => name => "preview", pack => { fill => 'both' }, );
	my $saver = $panes->insert( VBox => name => "Saver", pack => { fill => 'y', expand => 0}, backColor => PGK::convertColor($bgcol), );
	my $outbox = $stage->insert( TabbedScrollNotebook => style => tns::Simple, tabs => ["Lines"], name => 'output', tabsetProfile => {colored => 0, }, pack => { fill => 'both', expand => 1, pady => 3, side => "left", }, width => 500, autoHScroll => 1, vScroll => 1, );
	my $output = $outbox->insert( VBox => name => "output", pack => { fill => 'both', expand => 1 }, );
	my $autobut;
# Show a category box
	my $cate = makeCatButtonSet($saver,\$rows,(adder => \$autobut,edit => $output,prot => $prot));
# show autoupdate time box
	my $timee = makeTimeButtonSet($saver,\$rows,(adder => \$autobut,edit => $output,prot => $prot));
	my $ow = 0;
	$saver->insert( CheckBox => text => "clear calendar", checked => $ow, onClick => sub { my $checked = $_[0]->checked; $ow = $checked;} );
	$autobut = $saver->insert( Button => text => "Add to Library", enabled => 0, onClick => sub { autoShelve(\$rows,"$sdir/calendar.txt",$ow,$stage); getGUI('status')->push($rows->rows() . " rows saved to $sdir/calendar.txt\n"); } );

#	$stage->insert(Label => text => " ", pack => { fill => 'both', expand => 1, }, );
	opendir(DIR,$odir) or die $!;
	my @files = grep {
		/\.grp$/ # only show rotational image group files.
		&& -f "$odir/$_"
		} readdir(DIR);
	closedir(DIR);
	$lister->insert( Label => text => "Choose a group file:");
# Show file list
	foreach my $f (@files) {
		$lister->insert( Button => text => $f, onClick => sub { $lister->destroy();
			$rows = tryLoadGroup($prev,$f,\$selector,$colors,undef,(time => $timee, cat => $cate, editrowname => 1, maxrows => 7));
#skrDebug::dump($rows,"Rows",1);
# Choose file: run test...
			checkauto(\$autobut,$rows,$output,$prot); # 0 = two-digit date
		});
	}

	$lister->insert( Label => text => "In Progress" );

#	Display options:
#		Can file be organized automatically into days?
#			Allow that
#	Show lines that could be saved
# Save file with day format in schedule/calendar.txt

	#$note->show();
}
print ".";

sub loadSequence { # to load .seq files into this GUI.
	devHelp("Loading sequence files");
}
print ".";

sub loadDatedDays {
	my ($stat,$clobber,$wildcard) = @_;
	my %scheduled = ();
	my %regular = ();
	#TODO: Make a function to streamline these two very similar processes.
	# load lines from dated.txt
	my @lines = FIO::readFile("schedule/dated.txt",$stat,0);
	foreach my $line (@lines) {
	# for each line, parse:
		$line =~ m/date=(\d\d\d\d-\d\d-\d\d)>/;
		my $day = $1;
		$line =~ m/image=(.*?)>/;
		my $url = $1;
		$line =~ m/desc=(.*?)>/;
		my $desc = $1;
		$line =~ m/cat=(.*?)>/;
		my $cat = $1;
		$line =~ m/title=(.*?)>/;
		my $title = $1;
		$line =~ m/time=(.*?)>/;
		my $time = $1;
#		print "I found $title on $day at $url, described as a $cat defined by $desc...\n";
	# save each line as a hashref: { title => $title, desc => $desc, url => $url }
		my $h = { title => $title, desc => $desc, url => $url, time => $time };
		if( not defined $scheduled{$cat}{$day} or $clobber ) {
			$scheduled{$cat}{$day} = $h;
			$wildcard and $scheduled{'all'}{$day} = $h;
		}
	}
	# load lines from dated.txt
	@lines = FIO::readFile("schedule/calendar.txt",$stat,0);
	foreach my $line (@lines) {
	# for each line, parse:
		$line =~ m/day=(\d\d)>/;
		my $day = $1;
		$line =~ m/image=(.*?)>/;
		my $url = $1;
		$line =~ m/desc=(.*?)>/;
		my $desc = $1;
		$line =~ m/cat=(.*?)>/;
		my $cat = $1;
		$line =~ m/title=(.*?)>/;
		my $title = $1;
#		print "I found $title on $day at $url, described as a $cat defined by $desc...\n";
	# save each line as a hashref: { title => $title, desc => $desc, url => $url }
		my $h = { title => $title, desc => $desc, url => $url };
	# push the hashref to an array in a hash: $items{$cat}{$day}[n]
		if( not defined $regular{$cat}{$day} ) { $regular{$cat}{$day} = []; }
		push(@{ $regular{$cat}{$day} },$h);
		$wildcard && push(@{ $regular{'all'}{$day} },$h);
	}
	# return the hashes of arrays
	return (\%scheduled,\%regular);
}
print ".";

sub generateSequence {
	my ($group,$container,$aref) = @_;
	#FIXME: unblessed reference here sometimes?
	#TODO: Have this change the text of each button to its sequence value
	my @rows = $$container->widgets();
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

sub rownameEditor {
	my ($b,$g,$i) = @_;
	my $optbox = Prima::Dialog->create( centered => 1, borderStyle => bs::Sizeable, onTop => 1, width => 300, height => 100, owner => getGUI('mainWin'), text => "Edit Row Name for " . $b->text(), valignment => ta::Middle, alignment => ta::Left,);
	my $bhigh = 18;
	my $extras = { height => $bhigh, };
	my $buttons = mb::Ok;
	my $vbox = $optbox->insert( VBox => autowidth => 1, pack => { fill => 'both', expand => 1, anchor => "nw", }, alignment => ta::Left, );
	my $nb = labelBox($vbox,"Name",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $ne = $nb->insert( InputLine => name => 'input', text => $g->rowname($i) );
	$nb->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $b->text($ne->text); $g->rowname($i,$ne->text); $optbox->close(); });
	my $spacer = $vbox->insert( Label => text => " ", pack => { fill => 'both', expand => 1 }, );
	my $fresh = Prima::MsgBox::insert_buttons( $optbox, $buttons, $extras); # not reinventing wheel
	$fresh->set( font => applyFont('button'), );
	$optbox->execute;
}
print ".";

sub checkauto {
	my ($autobut,$g,$lt,$parm) = @_;
	unless (defined $g and (ref($g) eq "RRGroup") and defined $autobut and (ref($$autobut) eq "Prima::Button")) {
		carpWithout($$autobut,"modify the button","a button");
		carpWithout($g,"check a group","defining a group");
		return 0;
	}
	$lt->{lines} = [];
	$lt->empty();
	$$autobut->enabled(0);
	my @days = qw( U u M m T t W w R r F f A a Sa Sh Su sa sh su Sun Mon Tue Wed Thu Fri Sat 00 01 02 03 04 05 06 07 Sunday Monday Tuesday Wednesday Thursday Friday Saturday Shabbat ); # possible day names
	my $datepat = qr/[0123][0-9]/; # Simplistic date validation. 00 and 32-39 are the users' responsibility.
	my $rows = $g->rows() -1;
	foreach my $n (0 .. $rows) {
		$n = $g->rowname($n);
		if ($parm == 0) {
			#print "Seeking dates...";
			$n =~ /($datepat)/;
			#print "$n :> $1\n";
			return 0 unless (defined $1);
		} elsif ($parm == 1) {
			#print "Seeking days...";
			(Common::findIn($n,@days) == -1) and return 0;			
		} else {
			print "Unknown parm $parm...";
			$$autobut->enabled(0);
			return 0;
		}
	}
	foreach my $n (0 .. $rows) {
		my $d = $g->rowname($n);
		my @rowloop = $g->rowloop($n);
		if ($parm == 0) {
			#	Does file contain numbered rows?
			$d =~ /($datepat)/;
			$d = $1;
			foreach my $i (@rowloop) {
				my $ri = $g->item($n,$i);
				my ($url,$title,$desc,$time,$cat);
				$url = $ri->link;
				$title = $ri->title;
				$desc = $ri->text;
				$time = $ri->time;
				$cat = $ri->cat;
				#	Does file contain enough info to make images?
				next unless (defined $url and defined $title and defined $desc and defined $time and defined $cat); # skip invalid items.
				my $line = sprintf("day=%02d>image=%s>title=%s>desc=%s>time=%04d>cat=%s>",$d,$url,$title,$desc,$time,$cat);
				#print $line;
				$ri->set('recur',"$line");
				push(@{$lt->{lines}},$line);
				$lt->insert(Label => text => $line, pack => {fill => 'x'},);
			}
		} elsif ($parm == 1) {
			die "Uncoded!";
		}
	}
#	print "Success!";
	$$autobut->enabled(1);
	return 1; # Success!
}
print ".";

sub tryLoadGroup {
	my ($target,$fn,$sel,$cols,$sar,%extra) = @_;
	my $timefield = (exists $extra{time} ? $extra{time} : undef);
	my $catfield = (exists $extra{cat} ? $extra{cat} : undef);
	my $gtype = (exists $extra{gtype} ? $extra{gtype} : undef);
	my $randbut = (exists $extra{rbut} ? $extra{rbut} : undef);
	my $maxrows = (exists $extra{maxrows} ? $extra{maxrows} : undef);
	my $bact = ($extra{editrowname} or 0);
	my %items;
	my $group = RRGroup->new(order => 1); # same order as order buttons on Ordering page
	my $item;
	my $row = -1;
	my $line = 0;
	my $odir = (FIO::config('Disk','rotatedir') or "lib");
	$fn = "$odir/$fn";
	infMes("File $fn loading...",1);
	foreach my $l (FIO::readFile($fn,getGUI('status'))) {
		$line++;
		if ($l =~ m/row=(.+)/) {
			main::howVerbose() and print "Row $1\n";
			defined $item and $group->add($row,$item); # store the item if it's been defined.
			$item = undef;
			$group->items($row) or ($row <= 0) or $row--; # delete empty row by decrementing so it gets overwritten.
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
	$$sel = $target->insert( HBox => name => "buttonbox" );
	my $column = $$sel->insert( VBox => name => "buttoncol0" );
	my $buttonscale = (FIO::config('UI','buts') or 15);
	my $i = 0;
	foreach my $i (0..$group->maxr()) {
		my @r = $group->row($i);
		next unless (scalar @r); # empty row deleted, skip it.
		my $row = $column->insert( HBox => name => "row $i", pack => { fill => 'none', }, );
		$row->insert( Button => text => $group->rowname($i), height => $buttonscale + 1, pack => { fill => 'x', expand => 0 }, onClick => ($bact ? sub { rownameEditor($row,$group,$i); $_[0]->text($group->rowname($i)); } : sub { main::howVerbose() > 3 and print $_[0]->text . " pressed!\n"; })); # Row name button
		$row->insert( Label => text => " ");
		foreach my $c (@r) {
			next unless (ref $c eq "RItem"); # skip bad items
			$c->widget($row->insert( Button => width => $buttonscale, height => $buttonscale, text => "", hint => $c->text() . " (" . $c->link() . ")", onClick => sub { $c->itemEditor(); }));
			$c->widget()->set( backColor => PGK::convertColor("#FFF"), );
		}
		unless ($i % ($maxrows or FIO::config('UI','buttonrowmax') or 15) or $i == 0) {
			$column = $$sel->insert( VBox => name => "buttoncol$i" );
		}
	}
	(defined $gtype) and $gtype->onChange( sub {
		my $order = $group->order($gtype->value()); # change the group's order type.
		main::howVerbose() and infMes("Order is now $order",1); # say the group's order type.
		(defined $sar) and generateSequence($group,$sel,$sar); # show the effect immediately.
	} );
	(defined $randbut) and $randbut->set( onClick => sub { generateSequence($group,$sel,$sar); }, ); # set button to generate a new sequence without changing order type.
	my $typical = $group->item(0,0); # just grab an item for values; the user will probably change them anyway.
	(defined $timefield) and $timefield->text($typical->time);
	(defined $catfield) and $catfield->text($typical->category);
	return $group;
}
print ".";

=item carpWithout PREQ ACTIONTEXT PREQTEXT using a sayBox

IF PREQ is undefined, complain that ACTIONTEXT can't be done without PREQTEXT
Returns 0 if PREQ is defined.
Returns 1 if message was triggered.

=cut

sub carpWithout {
	my ($preq,$action,$preqtxt) = @_;
	defined $preq and return 0;
	sayBox(getGUI('mainWin'),"You can't $action until you $preqtxt!");
	return 1;
}

sub makeCatButtonSet {
	my ($llpane,$rows,%extra) = @_;
	my $cateb = labelBox($llpane,"Category: ",'category','V', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
	my $cate = $cateb->insert( InputLine => text => "");
	my $catea = $cateb->insert( Button => text => "Apply to All", onClick => sub {
			unless (carpWithout($$rows,"apply a category to all in group","choose a group")) { # don't allow anything to happen before group is loaded!
				my $height = $$rows->maxr(); # how many rows in group?
				foreach my $i (0..$height) { # traverse rows
					my $width = $$rows->items($i); # how many columns in row?
					foreach my $j (0..$width - 1) { # traverse columns
						my $t = $$rows->item($i,$j); # pick each item
						$t->cat($cate->text); # all this to set this item's category to the text box's value.
					}
				}
# TODO: check context
				return $cate unless defined $extra{edit};
				my ($eb,$ab,$prot) = ($extra{edit},$extra{adder},$extra{prot});
				checkauto($ab,$$rows,$eb,$prot);
#print join(',',@{$eb->{lines}});
			}
		});
	return $cate;
}
print ".";

sub makeTimeButtonSet {
	my ($llpane,$rows,%extra) = @_;
	my $timeeb = labelBox($llpane,"Publish time\n(24h form HHMM): ",'time','V', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
	my $timee = $timeeb->insert( InputLine => text => "");
	my $timeea = $timeeb->insert( Button => text => "Apply to All", onClick => sub {
			unless (carpWithout($$rows,"apply a publishing time to all in group","choose a group")) { # don't allow anything to happen before group is loaded!
				my $height = $$rows->maxr(); # how many rows in group?
				foreach my $i (0..$height) { # traverse rows
					my $width = $$rows->items($i); # how many columns in row?
					foreach my $j (0..$width - 1) { # traverse columns
						my $t = $$rows->item($i,$j); # pick each item
						$t->time($timee->text); # all this to set this item's time to the text box's value.
					}
				}
# TODO: Check context
				return $timee unless defined $extra{edit};
				my ($eb,$ab,$prot) = ($extra{edit},$extra{adder},$extra{prot});
				checkauto($ab,$$rows,$eb,$prot);
			}
		});
	return $timee;
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

sub refreshDescList {
	my ($resettarget,$target,$ar,$sched,$extra) = @_;
	$resettarget->empty(); # clear the box
	PGK::growList($resettarget, margin => 1);
#	print ")RT: " . $resettarget->name . "...";
	my $fb = $resettarget->insert( FilePager => name => 'descriptionFileList',);
	PGK::growList($fb, margin => 7);
	my $odir = (FIO::config('Disk','rotatedir') or "lib"); # pick the directory
	my $pagelen = (FIO::config('UI','filecount') or $$extra{pagelen} or 15); # How many lines of files to display
#	my @files = FIO::dir2arr($odir,"dsc"); # get the list
#	my $lister = $resettarget->insert( VBox => name => "InputList", pack => {fill => 'both', expand => 1, ipad => 3}, backColor => PGK::convertColor("#66FF99") ); # make new list box
	$resettarget->insert( Label => text => "Choose a description file:") unless $$extra{nocaption}; # Title the new box
	my $stat = getGUI("status");
	my $text = "Building buttons..";
	$$extra{rtarget} = $resettarget;
	$$extra{target} = $target;
	$$extra{tar} = $ar;
	$$extra{sched} = $sched;
	$$extra{stat} = $stat;
	$$extra{obj} = $fb;
	$$extra{pagelen} = $pagelen;
	$fb->build(control => 'buttons', mask => 'dsc', dir => $odir, action => sub { my ($f,$o) = @_; makeButton($f,$extra); }, pagelen => $pagelen,);
	sub makeButton {
		my ($f,$ex) = @_;
		my ($resettarget,$target,$tar,$sched,$g) = ($$ex{rtarget},$$ex{target},$$ex{tar},$$ex{sched},$$ex{obj});
		makeDescButton($g,$f,$resettarget,$target,$tar,$ex);
#		my ($f,$ex) = @_;
#		my ($g,$f,$lpane,$preview,$tar,$sched,$extra) = @_;
#		my $error = tryLoadDesc($lpane,$f,$preview,$tar,$extra);
#		$error && getGUI('status')->push("An error occurred loading $f!");
### TODO: Convert to Pager function
#	foreach my $f (@files) {
#			$stat->push($text);
#		makeDescButton($g,$f,$lpane,$preview,$tar,$sched,$extra);
#			$text = "$text.";
	}
	$stat->push(Common::shorten($text,50,3) . "Done. Pick a file.");
	return 0;
}
print ".";

=item tryLoadDesc TARGET FILE HASH

Given a reset TARGET widget, a FILE name, and a HASH in which to store data, loads the items from the file and displays them for inclusion input

=cut

sub tryLoadDesc {
	my ($resettarget,$fn,$target,$ar,$extra) = @_;
	my $orderkey = 0; # keep URLs in order
skrDebug::keylist($extra,"\$extra");
	my ($u1,$u2,$u3,$day) = (defined $$extra{date} ? Common::dateConv($$extra{date}) : (0,0,0,0));
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
#	my $count = processDesc($ar,$resettarget,$sched,$extra,$target,$stat,@them);
### TODO: Add code here to make columns if too many images in file
### TODO: Convert to Pager function
#sub processDesc {
#	my ($ar,$resettarget,$sched,$extra,$target,$stat,@them) = @_;
	my $sched = ("Scheduling" eq Sui::passData('context'));
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
			(main::howVerbose()) and print ":";
			$count++;
			$descact = 0;
			my $pi = RItem->new( title => $ti->{title}, text => $ti->{text}, link => $ti->{link}, ); # separate the item from this loop
			my $z = $resettarget->insert( Button => # place button for adding...
				text => ($sched ? "Use " : "Add ") . Common::shorten($pi->title(),24,10),
				height => $buttonheight,
				onMouseEnter=> sub {
					my $pr;
					my $fill = 0; # filler variable
					return unless ($sched > 1 && defined $extra);
					$target->empty();
					my ($error,$server,$img,$lfp) = fetchapic($pi->link,\$fill,$stat);
					return $error if $error;
					my $viewsize = 325;
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
					
				},
				onClick => sub {
					my $pr;
					if ($sched) { # on the schedule page
						my $fill = 0; # filler variable
						if (("Monthly" eq Sui::passData('contextdet')) && defined $extra) {
							my $description = $pi->text();
							$description =~ s/\s+^//; # trim trailing whitespace
							$$extra{cbsub}->($$extra{dialog},$$extra{target},$$extra{button},$$extra{ar},$pi->link,$pi->title,$description,$$extra{category},$$extra{date},$$extra{trim},$$extra{newchoice});
							$$extra{control}->destroy(); # kill the chooser
							$$extra{covers}->show(); # reshow the list
### TODO: Remove this in favor of using callback to do it
#							my ($sh,$rh) = @{ $$extra{ar} };
#							$$rh{$$extra{category}} = {} unless exists $$rh{$$extra{category}};
#							$$rh{$$extra{category}}{$day} = [] unless exists $$rh{$$extra{category}}{$day};
#							my $h = { url => $pi->link, title => $pi->title, desc => $description };
#							push(@{ $$rh{$$extra{category}}{$day} },$h);
							return $count;
						}
						$target->empty();
						my ($error,$server,$img,$lfp) = fetchapic($pi->link,\$fill,$stat);
						return $error if $error;
						my $viewsize = 325;
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
						my $description = $pi->text();
						$description =~ s/\s+^//; # trim trailing whitespace
						defined $pi->text() and defined $target->{tunnel}{desced} and $target->{tunnel}{desced}->text($description); # set description text
						defined $pi->title() and defined $target->{tunnel}{titlent} and $target->{tunnel}{titlent}->text($pi->title()); # set image title
						my $urlent = $target->insert( InputLine => editable => 0, text => "", width => 300, pack => {fill => 'none', expand => 0 }, );
						defined $pi->link() and $urlent->text($pi->link());
						$target->{tunnel}{image} = $urlent;
						defined $target->{tunnel}{button} and $target->{tunnel}{button}->set(enabled => 1); # ungrey the button so we know we'reusable.
					} else { # not on the schedule page
						$pr = labelBox($target,$pi->text(),$pi->title(),'H', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
						$pr->set( pack => { anchor => 'n', valignment => ta::Top } );
						$pr->insert( Button => # which places button for removing...
							text => "Remove",
							onClick => sub { $pr->destroy(); return 0; }, );
					}
				},
				pack => { fill => 'x', expand => 0, },
			) unless ($pi->title() eq "Unnamed");
			push(@$ar,$pi); # store record
			$ti = RItem->new( title => $2 ); # start new record, in case there are more items in this file
		} else { # Oops! Error.
			warn "\n[W] I found unexpected keyword $k with value $2.\n";
		}
#defined $debug and print "\n $k = $2...";
	}
# return $count;
#}
#### End of subroutine segment?
	$resettarget->insert( Button => # place button for adding... one final button.
		text => ($sched ? "Use " : "Add ") . Common::shorten($ti->title(),24,10),
		height => $buttonheight,
		onMouseEnter=> sub {
			my $pr;
			my $fill = 0; # filler variable
			return unless ($sched > 1 && defined $extra);
			$target->empty();
			my ($error,$server,$img,$lfp) = fetchapic($ti->link,\$fill,$stat);
			return $error if $error;
			my $viewsize = 325;
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
			
		},
		onClick => sub {
			my $pr;
			if ($sched) {
				my $fill = 0; # filler variable
				if ($sched == 2 && defined $extra) {
					print "Success!";
					my $x = $extra;
					my $description = $ti->text();
					$description =~ s/\s+^//; # trim trailing whitespace
					$$extra{cbsub}->($$extra{dialog},$$extra{target},$$extra{button},$$extra{ar},$ti->link,$ti->title,$description,$$extra{category},$$extra{date},$$extra{trim});
					$$extra{control}->destroy(); # kill the chooser
					$$extra{covers}->show(); # reshow the list
					my ($sh,$rh) = @{ $$extra{ar} };
					$$rh{$$extra{category}} = {} unless exists $$rh{$$extra{category}};
					$$rh{$$extra{category}}{$day} = [] unless exists $$rh{$$extra{category}}{$day};
					my $h = { url => $ti->link, title => $ti->title, desc => $description };
					push(@{ $$rh{$$extra{category}}{$day} },$h);
					return;
				}
				$target->empty();
				my ($error,$server,$img,$lfp) = fetchapic($ti->link,\$fill,$stat);
				return $error if $error;
				my $viewsize = 325;
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
				my $description = $ti->text();
				$description =~ s/\s+^//; # trim trailing whitespace
				defined $ti->text() and defined $target->{tunnel}{desced} and $target->{tunnel}{desced}->text($description); # set description text
				defined $ti->title() and defined $target->{tunnel}{titlent} and $target->{tunnel}{titlent}->text($ti->title()); # set image title
				my $urlent = $target->insert( InputLine => editable => 0, text => "", width => 300, pack => {fill => 'none', expand => 0 }, );
				defined $ti->link() and $urlent->text($ti->link());
				$target->{tunnel}{image} = $urlent;
				defined $target->{tunnel}{button} and $target->{tunnel}{button}->set(enabled => 1); # ungrey the button so we know we'reusable.
			} else {
				$pr = labelBox($target,$ti->text(),$ti->title(),'H', boxfill => 'x', boxex => 0, labfill => 'x', labex => 1);
				$pr->set( pack => { anchor => 'n', valignment => ta::Top } );
				$pr->insert( Button => # which places button for removing...
					text => "Remove",
					onClick => sub { $pr->destroy(); return 0; }, );
			}
		},
		pack => { fill => 'x', expand => 0, },
	) unless ($ti->title() eq "Unnamed");
	push(@$ar,$ti) unless ($ti->title() eq "Unnamed"); # store record
	$resettarget->insert( Button => text => "Pick different file", onClick => sub { refreshDescList($resettarget,$target,$ar,$sched); }, );
	getGUI('status')->push("Done loading $count items.");
	return 0; # success!
}
print ".";

=item makeDescButton TARGET FILE PARENT PREVIEW ARRAYREF
	Makes a button for each FILE, to load its items into a given TARGET with buttons to copy that item into the PREVIEW and the ARRAYREF. Said items have the option of clearing the PARENT.
=cut
sub makeDescButton {
	my ($lister,$f,$lpane,$preview,$tar,$sched,$extra) = @_;
	my $buttonheight = (FIO::config('UI','buttonheight') or 18);
	$lister->insert( Button => text => $f, onClick => sub { $lister->destroy();
	#							left pane; filename; preview pane; t? array ref; schedule page?
		my $error = tryLoadDesc($lpane,$f,$preview,$tar,$extra);
		$error && getGUI('status')->push("An error occurred loading $f!"); }, height => $buttonheight, );
}
print ".";

sub fetchapic { # fetches an image from the cache, or from the server if it's not there.
	my ($line,$hitserver,$stat,$target,$nofetch) = @_;
	unless ($line) {
		warn "\nUndefined line passed to fetchapic.\n";
		Common::traceMe(3);
		return (0,"","","");
	}
	$line =~ /(https?:\/\/)?([\w-]+\.[\w-]+\.\w+\/|[\w-]+\.\w+\/)(.*\/)*(\w+\-*\w+\.?\w{3})/;
	my $server = ($2 or "");
	my $img = ($4 or "");
	$img =~ s/\?.*//; # we won't want ?download=true or whatever in our filenames.
	my $serv = "";
	unless (defined $3) {
		$server =~ /[\w-]+\.([\w-]+)\.\w+\/|([\w-]+)\.\w+\//; # try to grab the domain name...
		$serv = ($1 or $2 or "unkn");
	}
	my $dir = ($3 or substr($serv,-4,4)); # try to get the directory, or else the last four characters of the server domain.
	length($img) > 7 or ($img = substr($dir,-(7-length($img))-1,(7-length($img))) . "_" . $img); # for cases of 1.png, etc.
	return -1 if ($server eq "" || $img eq ""); # if we couldn't parse this, we won't even continue.
	my $thumb = (FIO::config('Net','thumbdir') or "itn");
	my $lfp = $thumb . "/";
	unless (-e $lfp . $img && -f _ && -r _) {
		$$hitserver = 1;
		return -2 if $nofetch;
		$stat->push("Trying to fetch $line ($img)");
		Pfresh();
		print("Trying to fetch $line ($img) to $lfp\n");
		my $failure = FIO::Webget($line,"$lfp$img");# get image from server here
		$failure and defined $target and $target->insert( Label => name => "$img", text => "$img could not be retrieved from server $2.");
	} else {
		$stat->push("Loading image $img from cache");
		Pfresh();
	}
	return (0,$server,$img,$lfp);
}
print ".";

sub showapic {
	my ($lfp,$img,$viewsize) = @_;
	my $pic = Prima::Image->new;
	my $lfn = "$lfp$img";
#	$pic->load($lfn) or die "Could not load $lfn!";
	(-e $lfn && -f _ && -r _) and $pic->load($lfn) or warn "Could not load $lfn!";
#	$pic->set(scaling => 7); # ist::Hermite);
	my $iz = 1;
	if ($pic->width > $pic->height) {
		my $w = $pic->width + 1;
		$iz = $viewsize / $w; # get appropriate scale
		$pic->size($pic->height * $iz,$viewsize); # resize the image to fit our viewport
	} else {
		my $h = $pic->height + 1;
		my $iz = $viewsize / $h; # get appropriate scale
		$pic->size($viewsize,$pic->width * $iz); # resize the image to fit our viewport
	}
	return ($pic,$iz);
}
print ".";

=item resetDescribing TARGET

Given a TARGET widget, generates the input boxes and list widgets needed to perform the Describing page's functions.
Returns 0 on completion.
Dies on error opening given directory.

=cut

require PGUIdesc;
sub resetDescribing {
	return PGUIdesc::resetDescribing(@_);
}

=item resetGrouping TARGET

Given a TARGET widget, generates the list widgets needed to perform the Grouping page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

require PGUIgrou;
sub resetGrouping {
	return PGUIgrou::resetGrouping(@_);
}

=item resetOrdering TARGET

Given a TARGET widget, generates the list widgets needed to perform the Ordering page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

require PGUIorde;
sub resetOrdering {
	return PGUIorde::resetOrdering(@_);
}

=item resetPublishing TARGET

Given a TARGET widget, generates the list widgets needed to perform the Publishing page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

require PGUIpubl;
sub resetPublishing {
	return PGUIpubl::resetPublishing(@_);
}

=item resetScheduling TARGET

Given a TARGET widget, generates the list widgets needed to perform the Scheduling page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

require PGUIsche;
sub resetScheduling {
	return PGUIsche::resetScheduling(@_);
}

=item populateMainWin DBH GUI REFRESH

Given a DBHandle, a GUIset, and a value indicating whether or not to REFRESH the window, generates the objects that fill the main window.
At this time, DBH may be undef.
Returns 0 on successful completion.

=cut

sub populateMainWin {
	my ($dbh,$gui,$refresh) = @_;
	($refresh && (defined $$gui{pager}) && $$gui{pager}->destroy());
	my $win = $$gui{mainWin};
	Sui::storeData('context',"MainWin");
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
