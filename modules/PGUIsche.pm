package PGUIsche;
print "(S";# . __PACKAGE__;

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

PGUIsche - A module for Prima GUI elements: Schedule editor panel

=head2 DESCRIPTION

A library of functions used to build and manipulate the program's Prima user interface elements.
This submodule contains the functions used for the scheduling of ordered or individual Items.

=head3 Functions

=item resetScheduling TARGET

Given a TARGET widget, generates the list widgets needed to perform the Scheduling page's functions.
Returns 0 on completion.
Dies on error opening library directory.

=cut

sub resetScheduling {
	my ($args) = @_;
	my $schpage = $$args[0]; # unpack from dispatcher sending ARRAYREF
	Sui::storeData('context',"Scheduling");
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
	PGUI::refreshDescList($lister,$prev,$tar,$sched);
# Show these: fields for each dated.txt field, calendar for scheduling, time fields, schedule button
# will this tab be used for both individual schedule items and for weekly schedules? Do I need another tab?
	my @images = PGUI::loadDatedDays($$gui{status},1);
	my $op = $schpage->insert( Button => text => "Weekly Schedule", onClick => sub { devHelp($gui,"Setting a weekly schedule"); }, pack => { fill => 'x', expand => 0, }, );
	my $mb = $schpage->insert( Button => text => "Monthly Schedule", onClick => sub { showMonthly($gui,$bgcol,\@images) }, pack => { fill => 'x', expand => 0, }, );
	my $rcb = $schpage->insert( Button => text => "Recurring Item Library", onClick => sub { PGUI::showRecurLib($schpage,$bgcol,\@images, (FIO::config('Disk','rotatedir') or "lib")); }, pack => { fill => 'x', expand => 0, }, );
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
	unless (scalar @categories) {
		@categories = keys %{ $$filarrref[1] }; # we need categories to function!
		unless (scalar @categories) {
			@categories = qw( bible ministry special prayers ); # We need default categories as a last resort.
		}
	}
	my $bbox = $pane->insert( HBox => name => "buttons", pack => Sui::passData('rowopts') );
	my $prev = $win->insert( VBox => name => "Autopick", pack => Sui::passData('rowopts'), ); # create a pane
	my $seqer = $bbox->insert( InputLine => text => $categories[0] . ".seq" );
	#TODO: Make this refresh month, too.
	my $catter = $picker->insert( ComboBox => style => cs::DropDown, height => 35, items => \@categories, text => $categories[0], onChange => sub { $seqer->text($_[0]->text . ".seq"); }, );
	my $monther = $picker->insert( ComboBox => style => cs::DropDownList, height => 35, growMode => gm::GrowLoX | gm::GrowLoY, items => $months, onChange => sub { $date->set(month => $_[0]->focusedItem + 1); showMonth($calhome,$date,$filarrref,$output,$catter->text); }, text => $$months[$date->month() - 1], );
	$picker->insert( SpinEdit => name   => 'Year', min    => 1900, max => 2099, growMode => gm::GrowLoX | gm::GrowLoY, value => $date->year, onChange => sub { $date->set(year => $_[0]->value()); showMonth($calhome,$date,$filarrref,$output,$catter->text); } );
	$picker->insert( Label => text => " at the regular time " );
	my $first = (scalar @categories ? ( keys %{ $sched{$categories[0] } } )[0] : "");
	my %ex = (scalar @categories ? %{ $sched{$categories[0]}{"$first"} } : ());
	my $timer = $picker->insert( InputLine => text => ($ex{time} or "0800" ) );
	showMonth($calhome,$date,$filarrref,$output,$catter->text);
	$bbox->insert( Button => text => "Autofill", onClick => sub {
		my ($r,$c,$w) = (1,0,7);
		my $reg = @{ $filarrref }[1];
		my $cat = $catter->text;
		foreach my $d (@{ $output->{days} }) {
			print "\n" . $d->text . ": " . $sched{$cat}{$d->name}{url} . "..." if exists $sched{$cat}{$d->name}{url};
		}
		# run showmonth with a flag telling it to choose a random item from each day's list of regulars
		$prev->empty();
		my $row = $prev->insert( HBox => name => "Row $r", pack => Sui::passData('rowopts'), );
		my %picks;
		foreach my $day (@{$output->{days}}) { # run through $output->{days}...
			print "\n" . $day->text . ": ";
			if (exists $sched{$cat}{$day->name}{url}) {
		# if an image is already chosen, use that
				print $sched{$cat}{$day->name}{url} . "...";
				my ($us,$x) = ($sched{$cat}{$day->name}{url},0);
				$row->insert( Button => text => $day->text . ": " . $sched{$cat}{$day->name}{title}, onClick => sub { PGK::buttonPic($day,$us,\$x); } );
			} elsif (exists $$reg{$cat}{sprintf("%02d",$day->text)} and Common::isFuture($day->name)) {
		# or choose an image for each day and hash it in the dated DB.
				my %pick = seqPick($day,$cat,$reg,$seqer->text);
				$picks{$day->name} = \%pick; # save for later saving
		# show a label for each image chosen
				$row->insert( Button => text => $day->text . ": " . $pick{title}, onClick => sub { hashAndPic($pick{url},$pick{title},$pick{desc},$cat,$sched{$cat}{$day->name},undef,undef,$day); }, );
			} else {
				$c--; # to prevent huge blank spaces in the output pane.
			}
			$c++;
			if ($c >= $w) {
				$c = 0;
				$r++;
				$row = $prev->insert( HBox => name => "Row $r", pack => Sui::passData('rowopts'), );
			}
		}
		# show a button to save these autopicks to the dated.txt file
		my $scbox = $prev->insert( HBox => name => "SaveCancel" );
		$scbox->insert( Button => text => "Cancel", onClick => sub { $prev->empty(); } );
		$scbox->insert( Button => text => "Save dated", onClick => sub { hashAutoPicks($prev,$calhome,$date,$filarrref,$output,$catter->text,\%picks); } );
	} );
	$bbox->insert( Button => text => "Cancel", onClick => sub {
		my $stat = getGUI('status');
		$stat->push("Aborting monthly schedule.");
		Pfresh();
		$prev->destroy();
		$pane->destroy();
		$note->show();
		} );
	$bbox->insert( Button => text => "Save", onClick => sub {
		my $stat = getGUI('status');
		my $fn = "schedule/dated.txt";
		$prev->destroy();
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
					next if (%fields == ()); # if it's empty, not malformed, don't complain.
					my $es = "Subject hash passed to Save button does not contain all required data " . Common::lineNo(2);
					print "$es\n";
					$stat->push($es);
skrDebug::dump(\%fields,"dated");
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
						next if (%fields == ());
						my $es = "Subject hash in ref within Save button does not contain all required data " . Common::lineNo(2);
						print "$es\n";
						$stat->push($es);
skrDebug::dump(\%fields,"regular");
						next;
					}
					push(@lines,"day=" . $d . ">image=" . $fields{url} . ">title=" . $fields{title} . ">desc=" . $fields{desc} . ">time=" . $timestr . ">cat=" . $c . ">");
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

sub hashAutoPicks {
	my ($par,$ch,$dt,$fr,$op,$cat,$autopicks) = @_;
	$par->empty();
	my $fn = "schedule/dated.txt";
	my $schedcat = @{ $fr }[0]->{$cat};
	foreach my $k (keys %$autopicks) {
		next unless Common::isFuture($k);
		$$schedcat{$k} = $$autopicks{$k};
		main::howVerbose() and print "Picked: " . $$schedcat{$k}{title} . "...";
	}
	showMonth($ch,$dt,$fr,$op,$cat);
}
print ".";

sub showMonth {
	my @days_in_months = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
	my ($target,$date,$far,$out,$cat,%args) = @_;
	#TODO: Leap day handling here
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
		my $ymd = sprintf("%04d-%02d-%02d",$y,$m,$d);
		my $a = $weeks[$w]->insert( Button => width=> $butsize, height => $butsize, name => $ymd, text => "$d", onClick => sub { chooseDayImage($_[0],$weeks[$w],$ymd,$cat,$far,$butsize,0); } );
		push(@{ $out->{days} }, $a); # store for autofill
		$pos++;
		$d = "0$d" if $d < 10;
		my $hr = $$schedh{$cat}{$ymd} if exists $$schedh{$cat}{$ymd}{url}; # might be {}, so we'll check for a url field.
		if (defined $hr) { # if the date has an associated item in the dated.txt file...
			my $url = $$hr{url};
			my $tit = $$hr{title};
			my $des = $$hr{desc};
			my $error = PGK::buttonPic($a,$url,\$hitserver,$out);
			if ($error) { # What went wrong?
				if ($error == -1) {
					warn "The buttonPic function did not receive a URL for $ymd";
				}
			}
		} elsif (exists $args{auto} and $args{auto} == 1) {
#			chooseDayImage($a,$weeks[$w],"$y-$m-$d",$cat,$far,$butsize,1);
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
print ".";

sub seqPick {
	my ($d,$c,$r,$f) = @_;
	my $lib = (FIO::config('Disk','rotatedir') or "lib");
	my $fn = $lib . "/" . $f;
	my $valid = isReal($fn);
	my (@s,$p,$index) = ((),0,0); # sequence position index
	my $dt = sprintf("%02d",$d->text);
	my $a = $$r{$c}{$dt}; # arrayref
	my $x = scalar @{ $a }; # max is length of array
#print "L: $x;";
	$dt =~ m/(\d\d)/;
	if (defined $1) {
		$dt = int($1);
	} else {
		Common::infMes("$dt could not be parsed as a numeric",0,gobj => getGUI('status'),);
		$valid = 0; # if we don't have a parsable day,return a random item.
	}
	unless ($valid) {
		$index = rand(100000); # no valid sequence file =>> random choice
	} else {
		my $target = $dt;
		my $current = 0;
		my @lines = FIO::readFile($fn,getGUI('status'),0);
		$current = ($target < scalar @lines) ? $target : scalar @lines;
		my $ln = $lines[$current];
		# process line
		$ln =~ m/(\d+):(\d+),?+/;
print "Results: $1 - $2 = $3 [ $4 ] $5 : $6 ; $7 < $8 > $9 ?";

		my $in = int($1) + 1;
		$ln =~ s/(\d+):/$in/;
	}
	my $pick = $$a[$index % $x];
#skrDebug::dump($pick,"Pick $index",1);
	return %{ $pick };
}
print ".";

sub chooseDayImage  {
	my ($b,$p,$date,$cat,$ar,$bsz,$auto) = @_;
	Sui::storeData('contextdet',"Monthly");
	my ($sch,$rgh) = @$ar; # pull Sched and Reg from ARef
	my ($w,$h) = (640,580);
	my $bw = $w / 9; # button widths
	my $tl = 16; # text length
	my $n = 0;
	my ($x,$y,$m,$day) = Common::dateConv($date);
	if ($auto) { # skip UI elements
		print "Choosing automatically for $y-$m-$day:$cat...";
		return unless defined $$rgh{$cat}{$day}; 
		my $array_length = scalar @{ $$rgh{$cat}{$day} };
		return 0 unless $array_length > 0;
		my $rpc = int(rand(512)) % $array_length;
		my ($u,$t,$d) = ($$rgh{$cat}{$day}[$rpc]{url},$$rgh{$cat}{$day}[$rpc]{title},$$rgh{$cat}{$day}[$rpc]{desc});
		print "$u.\n";
skrDebug::dump($$rgh{$cat}{$day},"Day of $cat $rpc",1);
		$$sch{$cat} = {} unless exists $$sch{$cat};
		$$sch{$cat}{"$y-$m-$day"} = {} unless exists $$sch{$cat}{"$y-$m-$day"};
		my $s = $$sch{$cat}{"$y-$m-$day"};
		hashAndPic($u,$t,$d,$cat,$s,$rgh,$day,$b,$p); # choose the image selected
	}
	# make a dialog box
	my $box = PGK::quickBox($p,"Choose an image",$w,$h);
	# display the day of the month
	my $dayth = Common::ordinal($day);
	my $lktext = "Images in category '$cat' for the $dayth of the month";
	$box->{mybox}->insert( Label => text => $lktext);
	my $target = $box->{mybox}->insert( HBox => name => "row" );
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
		PGUI::refreshDescList($chooser,$prev,$tar,$sched,$extra);
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

#-=-=-=-=-=-=-=-=-=-=-=-=- Executor start
sub hashAndPic {
	my ($us,$ts,$ds,$cs,$sh,$rh,$date,$tarobj,$parobj) = @_;
	# also, store values in scheduled hash
#	my ($x1,$x2,$x3,$day) = Common::dateConv($date);
	$$sh{url} = $us; $$sh{title} = $ts; $$sh{desc} = $ds;
	$parobj and $parobj->close();
	my $x = 0;
	return PGK::buttonPic($tarobj,$us,\$x);
}
#-=-=-=-=-=-=-=-=-=-=-=-=- Executor end


print "ok) ";
1;
