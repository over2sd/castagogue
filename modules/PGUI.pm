package PGUI;
print __PACKAGE__;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( );

use FIO qw( config );
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

package PGUI;

my @openfiles = [];

=item buildPageOf TARGET COUNT OFFSET EXTRAS LIST

Populates a TARGET container widget with up to COUNT objects from a LIST, starting with the OFFSETth item, if possible.
Expects EXTRAS to be a hashref that contains, at minimum:
*	action => reference of a subroutine that creates specialized objects to insert into the TARGET.
	and generally also:
*	preargs => an arrayref containing commonly applied arguments that go before the iterative argument
*	postargs => an arrayref containing commonly applied arguments that go after the iterative argument

=cut

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

#-=-=-=-=-=-=-=-=-=-=-=-=- Executor start
sub hashAndPic {
	my ($us,$ts,$ds,$cs,$sh,$rh,$date,$tarobj,$parobj) = @_;
	# also, store values in scheduled hash
	my ($x1,$x2,$x3,$day) = Common::dateConv($date);
	$$sh{url} = $us; $$sh{title} = $ts; $$sh{desc} = $ds;
	$parobj->close();
	my $x = 0;
	return PGK::buttonPic($tarobj,$us,\$x);
}
#-=-=-=-=-=-=-=-=-=-=-=-=- Executor end


sub chooseDayImage  {
	my ($b,$p,$date,$cat,$ar,$bsz,$auto) = @_;
	my ($sch,$rgh) = @$ar;
	my ($w,$h) = (640,580);
	my $bw = $w / 9; # button widths
	my $tl = 16; # text length
	my $n = 0;
	my ($x,$y,$m,$day) = Common::dateConv($date);
	if ($auto) { # skip UI elements
		print "Choosing automatically for $y-$m-$day...";
		my $array_length = scalar @{ $$rgh{$cat}{$day} };
		return 0 unless $array_length > 0;
		my $rpc = int(rand(512)) % $array_length;
		my ($u,$t,$d) = ($$rgh{$cat}{day}[$rpc]{url},$$rgh{$cat}{day}[$rpc]{title},$$rgh{$cat}{day}[$rpc]{desc});
		print "$u.\n";
		$$sch{$cat} = {} unless exists $$sch{$cat};
		$$sch{$cat}{"$y-$m-$day"} = {} unless exists $$sch{$cat}{"$y-$m-$day"};
		my $s = $$sch{$cat}{"$y-$m-$day"};
		return hashAndPic($u,$t,$d,$cat,$s,$rgh,$day,$b,$p); # choose the image selected
	}
	# make a dialog box
	my $box = PGK::quickBox($p,"Choose an image",$w,$h);
	# display the day of the month
	my $dayth = Common::ordinal($day);
	my $lktext = "Images in category '$cat' for the $dayth of the month";
	$box->{mybox}->insert( Label => text => $lktext);
	my $target = $box->{mybox}->insert( HBox => name => "row", );
	# first, make a button for adding images to the given day
	$box->{count} = 0;
	#-------------------------------------Callback Start
	sub myCallback {
		my ($target,$parent,$row,$mar,$cat,$date,$l) = @_;
		# When pressed, open an askbox for the url, title, and description (date and category are set by caller of this function)
		my %ans = PGK::askbox($row,"Enter Image Details",{},"url","URL:","title","Title:","desc","Description:");
		return 0 unless (exists $ans{url} and exists $ans{title} and exists $ans{desc} and $ans{url} ne '');
		my ($u,$t,$d) = ($ans{url},$ans{title},$ans{desc});
#print "u: $u t: $t d: $d;...";
		# once information is entered, make a new button for the new image.
		my ($sh,$rh) = @$mar;
		$$rh{$cat} = {} unless exists $$rh{$cat};
		my ($x,$y,$m,$day) = Common::dateConv($date);
		$$rh{$cat}{$day} = [] unless exists $$rh{$cat}{$day};
		my $h = { url => $u, title => $t, desc => $d };
		push(@{ $$rh{$cat}{$day} },$h);
		myButton($parent,$row,$target,$mar,$u,$t,$d,$cat,$date,$l,1);
		return 1;
	}
	#------------------------------------Callback End
	$target->insert( Button => text => "Add an Image", onClick => sub { # add button
			$box->{count} += myCallback($b,$box,$target,$ar,$cat,$x,$tl);
		} );
	$box->{count}++; # library button gets counted.
	#================================== Button Start
	sub myButton {
		my ($parent,$row,$target,$mar,$u,$t,$d,$cat,$date,$l,$newchoice) = @_;
		print Common::lineNo();
		my ($sch,$rgh) = @$mar;
		my ($dt,$y,$m,$day) = Common::dateConv($date);
		$$sch{$cat} = {} unless exists $$sch{$cat};
		$$sch{$cat}{"$y-$m-$day"} = {} unless exists $$sch{$cat}{"$y-$m-$day"};
		my $s = $$sch{$cat}{"$y-$m-$day"};
		$row->insert( Button => text => Common::shorten($t,($l or 20),4), onClick => sub {
			hashAndPic($u,$t,$d,$cat,$s,$rgh,$date,$target,$parent);
		} );
		if ( $newchoice ) {
			$$rgh{$cat} = {} unless exists $$rgh{$cat};
			$$rgh{$cat}{$day} = [] unless exists $$rgh{$cat}{$day};
			my $h = { url => $u, title => $t, desc => $d };
			push(@{ $$rgh{$cat}{$day} },$h);
		}
		$parent->{count}++;
		if ($parent->{count} > 3) {
			$parent->{count} = 0;
			$row = $parent->{mybox}->insert( HBox => name => "row" );
		}
	}
	#===================================== Button End
	$target->insert( Button => text => "Add from library", onClick => sub {
	
### MAKE THIS use Pager with buttons
#devHelp($box,"Adding from the library"); return;
		$box->{mybox}->hide();
		my $stage = $box->insert( HBox => name => "stager", pack => { fill => 'both' }, );
		PGK::grow($stage, boxfill => 'y', boxex => 1, margin => 7);
		$stage->insert( Label => text => "Choosing an image to add as an option for the $dayth of the month." );
		my $chooser = $stage->insert( VBox => name => "chooser");
		PGK::grow($chooser, boxfill => 'y', boxex => 1, margin => 7);
		$chooser->insert( Label => text => "Choose a file of image descriptions:");
		# list DSC files in library
		my $tar = [];
		my $sched = 2;
		my $prev = $stage->insert( VBox => name => "preview", pack => { fill => 'both' }, );
		$stage->insert(Label => text => " ???", pack => { fill => 'both', expand => 1, }, );
		# on click, destroy this box and list images in DSC file
		# on click, destroy that box and add button to $target with myButton
		# make sure this new image gets added to the regular list (calendar.txt)
		my $extra = {
			target => $target,
			parent => $p,
			button => $b,
			date => $date,
			category => $cat,
			ar => $ar,
			size => $bsz,
			cbsub => \&myButton,
			covers => $box->{mybox},
			control => $stage,
			dialog => $box,
			trim => $tl,
			newchoice => 1,
			pagelen => 12,
			nocaption => 1,
		};
		refreshDescList($chooser,$prev,$tar,$sched,$extra);
	} );
	# read regular files for date given
print "Day: $day -=- ";
skrDebug::dump($$rgh{$cat});
	foreach my $i ( @{ $$rgh{$cat}{$day} } ) {
		# display a button for each
		myButton($box,$target,$b,$ar,$$i{url},$$i{title},$$i{desc},$cat,$x,$tl,0);
		# when the button is pressed, select it as the image for the given button and close the dialog
	}
	$box->execute();
}
print ".";

sub showMonth {
	my @days_in_months = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
	my ($target,$date,$far,$out,$cat) = @_;
	$target->empty();
	$out->{days} = []; # clear storage for refresh
	my $stat = getGUI('status');
	$date->set( day => 1); # find first day...
	print "Showing " . $date->ymd . ": $cat...";
	my $firstweekday = $date->dow(); # ...so we can see which day the month starts on
	$firstweekday = 0 if $firstweekday == 7;
	my @weeks = ();
	my $count = 6;
	my $butsize = (FIO::config('UI','caldaysize') or 100);
	my $hitserver = 0;
	my $moment = 7;
	while ($count > 0) {
		$count--;
	my $name = "week $count";
		push(@weeks,$target->insert( HBox => name => $name, width => ($butsize * 7 + 7), height => ($butsize + 2)));
	}
	my $pos = 0;
	my $w = 0;
	while ($pos < $firstweekday) {
		my $row = $weeks[$w];
		$weeks[$w]->insert( Button => width=> $butsize, height => $butsize, text => "", );
		$pos++;
	}
	my ($schedh,$regh) = @$far;
	my ($x1,$y,$m,$x2) = Common::dateConv($date); # DateTime => (datetime,scalar,scalar,scalar)
	foreach my $d (1 .. $days_in_months[$date->month - 1]) {
		my $row = $weeks[$w];
		my $a = $weeks[$w]->insert( Button => width=> $butsize, height => $butsize, name => "$y-$m-$d", text => "$d", onClick => sub { chooseDayImage($_[0],$weeks[$w],"$y-$m-$d",$cat,$far,$butsize,0); } );
		push(@{ $out->{days} }, $a); # store for autofill
		$pos++;
		$d = "0$d" if $d < 10;
		my $hr = $$schedh{$cat}{"$y-$m-$d"};
		if (defined $hr) { # if the date has an associated item in the dated.txt file...
			my $url = $$hr{url};
			my $tit = $$hr{title};
			my $des = $$hr{desc};
			my $error = PGK::buttonPic($a,$url,\$hitserver,$out);
		} else {
			# load placeholder image
		}
		if ($hitserver) {
			$stat->push("Waiting...");
			Pwait($moment);
			$hitserver = 0;
		}
		if ($pos > 6) {
			$pos = 0;
			$w++;
		}
	}
	while ($pos != 0 && $pos < 7) {
		my $row = $weeks[$w];
		$weeks[$w]->insert( Button => width=> $butsize, height => $butsize, text => "X", onClick => sub { print "I'm in " . $row->name . "..."; } );
		$pos++;
	}
}

sub showMonthly {
	my ($gui,$bgcolor,$filarrref) = @_;
	
	my $win = $$gui{mainWin};
	my $note = $$gui{pager};
	$note->hide();
	my $pane = $win->insert( VBox => name => "monthly");
	my $rows = $pane->insert( VBox => name => "rows");
	$pane->backColor(PGK::convertColor($bgcolor));
	my $picker = $rows->insert( HBox => name => "monthpick");
	my $date = DateTime->now;
	my $months = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
	my $calhome = $rows->insert( VBox => name => 'Calendar');
	my $output = $picker->insert( InputLine => text => "");
	$output->{days} = []; # needed for autofill button
	my %sched = %{ $$filarrref[0] };
	my @categories = keys %sched;
	my $catter = $picker->insert( ComboBox => style => cs::DropDown, height => 35, items => \@categories, text => $categories[0] );
	my $monther = $picker->insert( ComboBox => style => cs::DropDownList, height => 35, growMode => gm::GrowLoX | gm::GrowLoY, items => $months, onChange => sub { $date->set(month => $_[0]->focusedItem + 1); showMonth($calhome,$date,$filarrref,$output,$catter->text); }, text => $$months[$date->month() - 1], );
	$picker->insert( SpinEdit => name   => 'Year', min    => 1900, max => 2099, growMode => gm::GrowLoX | gm::GrowLoY, value => $date->year, onChange => sub { $date->set(year => $_[0]->value()); showMonth($calhome,$date,$filarrref,$output,$catter->text); } );
	$picker->insert( Label => text => " at the regular time " );
	my $first = ( keys %{ $sched{$categories[0] } } )[0];
	my %ex = %{ $sched{$categories[0]}{"$first"} };
skrDebug::dump(\%ex);
	my $timer = $picker->insert( InputLine => text => ($ex{time} or "0800" ) );
	showMonth($calhome,$date,$filarrref,$output,$catter->text);
	my $bbox = $pane->insert( HBox => name => "buttons" );
	$bbox->insert( Button => text => "Autofill", onClick => sub {
		foreach my $d (@{ $output->{days} }) {
			print "\n" . $d->text . ": " . $sched{$catter->text}{$d->name}{url} . "..." if exists $sched{$catter->text}{$d->name}{url};
		}
		# run showmonth with a flag telling it to choose a random item from each day's list of regulars
		# run through $output->{days}...
		devHelp($pane,"Autofilling the month");
	} );
	$bbox->insert( Button => text => "Cancel", onClick => sub {
		my $stat = getGUI('status');
		$stat->push("Aborting monthly schedule.");
		Pfresh();
		$pane->destroy();
		$note->show();
		} );
	$bbox->insert( Button => text => "Save", onClick => sub {
		my $stat = getGUI('status');
		my $fn = "schedule/dated.txt";
		$stat->push("Appending post to $fn...");
		$_[0]->text("Saving schedule...");
		$_[0]->set( enabled => 0 );
		Pfresh();
		my @lines = ();
		my %hash = %{ @{ $filarrref }[0] };
		$timer->text =~ /(\d\d\d\d)/;
		my $timestr = $1;
		foreach my $c ( sort keys %hash ) {
			my %dates = %{ $hash{$c} };
			foreach my $d (sort keys %dates ) {
				my %fields = %{ $hash{$c}{$d} };
				unless (defined $fields{url} && defined $fields{title} && defined $fields{desc} ) {
					my $es = "Subject hash does not contain all required data " . Common::lineNo(2);
					print "$es\n";
					$stat->push($es);
					next;
				}
				$fields{desc} =~ s/\s+^//; # trim trailing whitespace
				push(@lines,"date=" . $d . ">image=" . $fields{url} . ">title=" . $fields{title} . ">desc=" . $fields{desc} . ">time=" . $timestr . ">cat=" . $c . ">");
			}
		}
		my $err = FIO::writeLines($fn,\@lines,1);
		$stat->push($err ? "Error when saving: $!" : "Schedule saved.");
		$_[0]->text("Saving calendar...");
		Pfresh();
		@lines = ();
		$fn = "schedule/calendar.txt";
		%hash = %{ @{ $filarrref }[1] };
		foreach my $c ( sort keys %hash ) {
			my %dates = %{ $hash{$c} };
			foreach my $d (sort keys %dates ) {
				foreach my $i ( @{ $hash{$c}{$d} } ) {
					my %fields = %{ $i };
					unless (defined $fields{url} && defined $fields{title} && defined $fields{desc} ) {
						my $es = "Subject hash does not contain all required data " . Common::lineNo(2);
						print "$es\n";
						$stat->push($es);
						next;
					}
					push(@lines,"day=" . $d . ">image=" . $fields{url} . ">title=" . $fields{title} . ">desc=" . $fields{desc} . ">time=" . $timestr . ">cat=" . $c . ">");
print Dumper $filarrref;
				}
			}
		}
		$err = FIO::writeLines($fn,\@lines,1);
		$stat->push($err ? "Error when saving: $!" : "Regular options saved.");
		$_[0]->text("Closing...");
		$_[0]->set( enabled => 0 );
		Pfresh();
		$pane->destroy();
		$note->show();
	} );
}
print ".";

sub saveItAsIs {
	my ($rss,$ofn,$output,$target,$bgcol) = @_;
	($rss->save($ofn) ? $output->push("$ofn saved.") : $output->push("$ofn could not be saved."));
	unless (FIO::config('Disk','persistentnext')) { print "nextID was " . FIO::cfgrm('Main','nextid',undef); } # reset nextID if we want to get it from the file each time.
	FIO::saveConf();
	$target->insert( Button => text => "Continue", onClick => sub { resetPublishing([$target,$bgcol]); } );
}

sub toRSSfromGUI {
	my ($target,$inf,$outf,$dfrom,$dto,$nextb,$victim1,$victim2,$bgcol) = @_;
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
	print "Processing RSS feed out of $ifn into $ofn from $start to $end with ID of " . (defined $nextb and defined $nextb->value() ? $nextb->value() : "" ) . ".\n";
	my $idsuggest = (defined $nextb->value() ? $nextb->value() : FIO::config('Main','nextid'));
	FIO::config('Main','nextid',$idsuggest);
	$victim1->destroy();
	$victim2->destroy();
	my $output = $target->insert( Edit => text => "", pack => { fill => 'both', expand => 1, } );
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
	my $rss = castRSS::prepare($ifn,$output,1);
	if ($start eq "0000-00-00") { $start = "today"; }
	if ($end eq "0000-00-00") { $end = "tomorrow"; }
	Pfresh();
	my $error = castRSS::processRange($rss,$start,$end,$output,1);
	$output->push("Now contains " . $#{$rss->{items}} . " items...");
#print $rss->as_string;
	if (FIO::config('UI','preview')) {
		$output->push("Loading items for review (see below).");
		Pfresh();
		my $review = $target->insert( VBox => name => 'review', pack => { fill => 'both', expand => 1 });# VBox to hold RItems
		$review->insert( Label => text => "Reviewing RSS feed is not yet coded. Sorry." );
# each existing RSS item will be loaded, given a different background color than generated items.
# each RItem row should have a button to remove that item.
# each RItem should have buttons to edit values.
# svae button to write items to RSS
		$target->insert( Button => text => "Save", onClick => sub { $_[0]->destroy(); saveItAsIs($rss,$ofn,$output,$target,$bgcol); } );
		Pfresh();
	} else {
		Pfresh();
		saveItAsIs($rss,$ofn,$output,$target,$bgcol);
	}
}
print ".";

sub schedulePost {
	my ($button,$target,$fields) = @_;
	my $stat = getGUI('status');
	my $fn = "schedule/dated.txt";
	if ($$fields{calent}->text() eq "0000-00-00") { # did you forget to set the date?
		$stat->push("A valid date is required to schedule a post!");
		$$fields{calent}->set( backColor => ColorRow::stringToColor("#F00"), onChange => sub { $$fields{calent}->set( backColor => ColorRow::stringToColor("#FFF"), onChange => sub {}, ); }, );
		return -1;
	}
	if ($$fields{catent}->text() eq "category") { # did you forget to set the category?
		$stat->push("A valid category (even 'general') is required to schedule a post!");
		$$fields{catent}->set( backColor => ColorRow::stringToColor("#F00"), onChange => sub { $$fields{catent}->set( backColor => ColorRow::stringToColor("#FFF"), onChange => sub {}, ); }, );
		return -2;
	}
	$stat->push("Appending post to $fn...");
	$button->text("Saving...");
	$button->set( enabled => 0 );
	Pfresh();
	my @lines = ();
	my $description = $$fields{desced}->text();
	$description =~ s/\s+^//; # trim trailing whitespace
	push(@lines,"date=" . $$fields{calent}->text() . ">image=" . $$fields{image}->text() . ">title=" . $$fields{titlent}->text() . ">desc=" . $description . ">time=" . $$fields{timent}->text() . ">cat=" . $$fields{catent}->text() . ">");
	my $err = FIO::writeLines($fn,\@lines,0);
	$stat->push($err ? "Error when saving: $!" : "Post saved.");
	delete $$fields{image};
	$target->empty();
	my $titlestring = $$fields{titlent}->text();
	$target->insert(Label => text => "Saved $titlestring to $fn.", backColor => ColorRow::stringToColor("#1f2"), pack => {fill => 'x', expand => 0, }, );
	$target->insert(Label => text => " ", pack => { fill => 'y', expand => 1, }, );
	$button->text("Schedule");
	$button->set( enabled => 1 );
	Pfresh();
	return $err;
}
print ".";


=item resetScheduling TARGET

Given a TARGET widget, generates the list widgets needed to perform the Scheduling page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

sub resetScheduling {
	my ($args) = @_;
	my $schpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	my $bgcol = $$args[1];
	my $gui = getGUI();
	$schpage->empty(); # start with a blank slate
	my $panes = $schpage->insert( HBox => name => 'splitter',  pack => Sui::passData('paneopts'), );
	my $lister = $panes->insert( VBox => name => "Input", pack => Sui::passData('listopts'), backColor => PGK::convertColor($bgcol),  );
	$lister->insert( Label => text => "Choose a file of image descriptions:");
	my $tar = [];
	my $sched = 1;
	my $stage = $panes->insert( VBox => name => "stager", pack => { fill => 'both' }, );
	my $prev = $stage->insert( VBox => name => "preview", pack => { fill => 'both' }, );
	$stage->insert(Label => text => " ", pack => { fill => 'both', expand => 1, }, );
	my ($hb,$hbi) = labeledRow($stage,"Title: ",( name => 'tbox', contents => [ ["InputLine", text => "Change Me; I'm used for indexing", width => 300, pack => { alignment => ta::Left, fill => 'x', },],], boxfill => 'x', boxex => 0, labfill => 'x', labex => 1, ));
	my ($tb,$tbi) = labeledRow($stage,"Content: ",( contents => [[InputLine => text => "This is a wonderful place to put the final description text.", pack => { fill => 'both' }, width => 400,]], boxfill => 'x', boxex => 0, labfill => 'x', labex => 1,));
	my $detbox = $stage->insert( HBox => name => "me" );
	my $calent = $detbox->insert( InputLine => text => '0000-00-00', name => 'imadate' );
	my $calbut = PGK::insertCalButton($detbox,$calent,'calent',"Choose Date");
	my $timent = $detbox->insert( InputLine => text => "0800", hint => "Time to publish post" );
	my $catent = $detbox->insert( InputLine => name => "category", hint => "Post category" );
	my %tunnel;
	my $sbut = $detbox->insert( Button => text => "Schedule", onClick => sub { carpWithout($tunnel{image},"schedule a post","choose a post image") or schedulePost($_[0],$prev,\%tunnel); } );
	$tunnel{calent} = $calent;
	$tunnel{timent} = $timent;
	$tunnel{catent} = $catent;
	$tunnel{titlent} = $hbi;
	$tunnel{desced} = $tbi;
	$prev->{tunnel} = \%tunnel;
	my $notebox = $panes->insert( Edit => name => "notes", pack => { fill => 'both', expand => 1 }, hint => "This is a good place to store notes about your schedule.", ); # a box for writing notes
	$notebox->{lines} = $$gui{notes}; # allows the object to save its lines over the lines I'm about to load from the array stored therein
	$notebox->text(join('
',@{$$gui{notes}}) ); # Allows us to load the lines from the text file into the editor
	refreshDescList($lister,$prev,$tar,$sched);
# Show these: fields for each dated.txt field, calendar for scheduling, time fields, schedule button
# will this tab be used for both individual schedule items and for weekly schedules? Do I need another tab?
	my @images = loadDatedDays($$gui{status},1);
	my $op = $schpage->insert( Button => text => "Weekly Schedule", onClick => sub { devHelp($gui,"Setting a weekly schedule"); }, pack => { fill => 'x', expand => 0, }, );
	my $mb = $schpage->insert( Button => text => "Monthly Schedule", onClick => sub { showMonthly($gui,$bgcol,\@images) }, pack => { fill => 'x', expand => 0, }, );
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

sub saveSequence {
	my @lines = ();
	my $fn = shift;
	my $stat = getGUI('status');
	$stat->push("Writing sequence...");
	foreach my $i (@_) {
		next unless (ref $i eq "RItem"); # make sure we only use RItems.
		unless (defined $i->link && defined $i->title && defined $i->text) {
			my $es = "Subject RItem does not contain all required data " . Common::lineNo(2);
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
		unless (defined $i->link && defined $i->title && defined $i->text) {
			my $es = "Subject RItem does not contain all required data " . Common::lineNo(2);
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

sub loadDatedDays {
	my ($stat,$clobber,$wildcard) = @_;
	my %scheduled = ();
	my %regular = ();
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
	infMes("File $fn loading...",1);
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
		main::howVerbose() and infMes("Order is now $order",1); # say the group's order type.
		generateSequence($group,$sel,$sar); # show the effect immediately.
	} );
	$randbut->set( onClick => sub { generateSequence($group,$sel,$sar); }, ); # set button to generate a new sequence without changing order type.
	my $typical = $group->item(0,0); # just grab an item for values; the user will probably change them anyway.
	$timefield->text($typical->time);
	$catfield->text($typical->category);
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
		makeDescButton($g,$f,$resettarget,$target,$tar,$sched,$ex);
	}
	$stat->push(Common::shorten($text,50,3) . "Done. Pick a file.");
	return 0;
}
print ".";

=item tryLoadDesc TARGET FILE HASH

Given a reset TARGET widget, a FILE name, and a HASH in which to store data, loads the items from the file and displays them for inclusion input

=cut

sub tryLoadDesc {
	my ($resettarget,$fn,$target,$ar,$sched,$extra) = @_;
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
						if ($sched == 2 && defined $extra) {
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
print "::";
	$lister->insert( Button => text => $f, onClick => sub { $lister->destroy();
	#							left pane; filename; preview pane; t? array ref; schedule page?
print ";;";
		my $error = tryLoadDesc($lpane,$f,$preview,$tar,$sched,$extra);
		$error && getGUI('status')->push("An error occurred loading $f!"); }, height => $buttonheight, );
print "??";
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

sub fetchapic { # fetches an image from the cache, or from the server if it's not there.
	my ($line,$hitserver,$stat,$target) = @_;
	$line =~ /(https?:\/\/)?([\w-]+\.[\w-]+\.\w+\/|[\w-]+\.\w+\/)(.*\/)*(\w+\.?\w{3})/;
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
		$stat->push("Trying to fetch $line ($img)");
		Pfresh();
		print("Trying to fetch $line ($img) to $lfp");
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
	my $outbox = labelBox($resettarget,"Images",'imagebox','V', boxfill => 'both', boxex => 0, labfill => 'none', labex => 0);
	my $hb = $outbox->insert( HBox => name => "$fn", pack => {fill => 'x', expand => 1} ); # Left/right panes
	my $ib = $hb->insert( VBox => name => "Image Port", pack => {fill => 'y', expand => 1, padx => 3, pady => 3,}, width => $viewsize + 10 ); # Top/bottom pane in left pane
	my $vp; # = $ib->insert( ImageViewer => name => "i$img", zoom => $iz, pack => {fill => 'none', expand => 1, padx => 1, pady => 1,} ); # Image display box
	my $cap = $ib->insert( Label => text => "(Nothing Showing)\nTo load an image, click its button in the list.", autoHeight => 1, pack => {fill => 'x', expand => 0, padx => 1, pady => 1,} ); # caption label
	my $lbox = $hb->insert( VBox => name => "Images", pack => {fill => 'both', expand => 1, padx => 0, pady => 0, minHeight => $viewsize + 75, } ); # box for image rows
	my $groupsof = 10;
#	my ($pager,@book) = pagifyGroup($lbox,scalar @them,$groupsof,$viewsize,"VBox");
	my $page = $lbox;
	if (scalar @them > $groupsof) {
#		$page = $book[0];
	}
	my $pagenumber = 0;
	my $pageitem = 0;
	unless ($fn eq "NONE") { # real file...
		foreach my $line (@them) {
			placeDescLine($page,$stat,\$hitserver,$line,$hashr,\$orderkey,$viewsize,$buttonheight,\$vp,$cap,$ib,$collapsed,$expanded,$moment,\$pageitem,\$pagenumber);
		}
	} else { # manual entry
		$outbox->insert( Button => text => "Add an image", onClick => sub {
			my %ans = PGK::askbox($outbox,"Enter Image Details",{},"url","URL:","title","Title:","desc","Description:");
			return -1 unless (exists $ans{url} and $ans{url} ne '');
			placeDescLine($page,$stat,\$hitserver,$ans{url},$hashr,\$orderkey,$viewsize,$buttonheight,\$vp,$cap,$ib,$collapsed,$expanded,$moment,\$pageitem,\$pagenumber,$ans{desc},$ans{title});
		} );
	}
	my $of = $outbox->insert( InputLine => text => ($fn eq "NONE" ? "manual.dsc" : "prayers.dsc"), pack => { fill => 'x', expand => 0, },);
	$outbox->insert( Button => text => "Save", pack => { fill => 'x', expand => 0, }, onClick => sub { my $ofn = $of->text; $ofn =~ s/\..+$//; $ofn = "$ofn.dsc"; $outbox->destroy(); saveDescs($ofn,$hashr,0); $stat->push("Descriptions written to $ofn."); $resettarget->insert( Label => text => "Your file has been saved.", pack => {fill => 'both', expand => 1}); $resettarget->insert( Button => text => "Continue to Grouping tab", onClick => sub { getGUI('pager')->switchToPanel("Grouping"); } ); $resettarget->insert( Button => text => "Continue to Scheduling tab", onClick => sub { getGUI('pager')->switchToPanel("Scheduling"); } ); $resettarget->insert( Label => text => scalar %$hashr . " images.", pack => {fill => 'both', expand => 1}); });
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
	$lister->insert( Button => text => "Enter URLS Manually", onClick => sub { $lister->destroy();
		my $error = tryLoadInput($imgpage,"NONE",$delaybox,\%images,$sizer);
	});
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
