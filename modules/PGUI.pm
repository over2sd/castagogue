package PGUI;
print __PACKAGE__;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( );

use FIO qw( config );
use PGK;
use Prima qw( ImageViewer Sliders );

=head1 NAME

PGUI - A module for Prima GUI elements

=head2 DESCRIPTION

A library of functions used to build and manipulate the program's Prima user interface elements.

=cut

package PGUI;

my @openfiles = [];

sub tryLoadInput {
	my ($resettarget,$fn,$pausebox,$hashr,$viewsize) = @_;
	my $collapsed = 24;
	my $expanded = 800;
	my $moment = $pausebox->value;
	my $hitserver = 0;
	$viewsize = $viewsize->value; # object to int
	return 0 unless (Common::findIn($fn,@openfiles) < 0); # don't try to load if already loaded that file.
	return 0 unless (-e $fn && -f _ && -r _); # stop process if contents of text input are not a valid filename for a readable file.
	my $thumb = FIO::config('Net','thumbdir') or "itn";
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
	my $cap = $ib->insert( Label => text => "Nothing Showing", pack => {fill => 'x', expand => 0, padx => 1, pady => 1,} ); # caption label
	my $lbox = $hb->insert( VBox => name => "Images", pack => {fill => 'both', expand => 1, padx => 0, pady => 0,} ); # box for image rows
	foreach my $line (@them) {
		$line =~ /(https?:\/\/)?([\w-]+\.[\w-]+\.\w+\/|[\w-]+\.\w+\/)(.*\/)*(\w+\.?\w{3})/;
		my $server = $2 or "";
		my $img = $4 or "";
		my $row = $lbox->insert( HBox => name => $img);
		return -1 if ($server eq "" || $img eq "");
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
			$row->insert( Label => name => "$img", text => "$img", onClick => sub { $row->height($expanded); });
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
		$row->insert( Label => text => "Description of image:");
		my $desc = $row->insert( InputLine => width => 100, name => "$line", text => "?" );
		$desc->set(onLeave => sub { $$hashr{$desc->name} = $desc->text; });
		$row->insert( Button => name => 'dummy', text => "Set"); # Clicking button triggers hash store
#		$row->height($collapsed);
		if ($hitserver) {
			$stat->push("Waiting...");
			Pwait($moment);
			$hitserver = 0;
		}
	}
	my $of = $outbox->insert( InputLine => text => "prayers.txt", pack => { fill => 'x', expand => 1, },);
	$outbox->insert( Button => text => "Save", pack => { fill => 'x', expand => 1, }, onClick => sub { my $ofn = $of->text; $outbox->destroy(); saveDescs($ofn,$hashr); });
	$stat->push("Done.");
}
print ".";

sub saveDescs {
	my ($fn,$hr) = @_;
	use Data::Dumper;
	print "If this were finished, I'd save the following data to lib/$fn...";
	print Dumper $hr;
	return 0;
}
print ".";

sub resetDescribing {
	my ($imgpage) = @_;
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
			tryLoadInput($imgpage,$f,$delaybox,\%images,$sizer);
		});
	}
	$delaybox->text("7");
}

sub populateMainWin {
	my ($dbh,$gui,$refresh) = @_;
	($refresh && (defined $$gui{pager}) && $$gui{pager}->destroy());
	my $win = $$gui{mainWin};
	my @tabs = qw( Describing Ordering); # TODO: generate dynamically
	my $pager = $win->insert( Pager => name => 'Pages', pack => { fill => 'both', expand => 1}, );
	$pager->build(@tabs);
	my $i = 1;
	my $color = Common::getColors(11,1);
	my $currpage; # placeholder
	# Image tab
	my $imgpage = $pager->insert_to_page(0,VBox =>
		backColor => ColorRow::stringToColor($color),
		pack => { fill => 'both', },
	);
	resetDescribing($imgpage);

	my $ranpage = $pager->insert_to_page(0,VBox =>
		backColor => ColorRow::stringToColor($color),
		pack => { fill => 'both', },
	);
	$$gui{pager} = $pager;
}
print ".";

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

sub aboutBox {
	my $target = shift;
	sayBox($target,"$PROGRAMNAME $version\nThis program exists to allow you to preview images in a list of URLs, type your own descriptions of them, and save the description of each file with its URL in a library castagogue can use to populate randomized lists.\nI hope you enjoy it.");
}

sub sayBox {
	my ($parent,$text) = @_;
	Prima::MsgBox::message($text,owner=>$parent);
}
print ".";

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
