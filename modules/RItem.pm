package RItem; # RSS Items
print __PACKAGE__;

use PGK qw( getGUI getPColors labelBox applyFont );
use Common qw( infMes );
=head2 RItem

RSS Item. Stores information for an item to be published to an RSS feed object.

=head3 Usage

  my $item = RItem->new(title => "Item Title", text => "Item description", link => "http://www.url.com/", cat => "news", time => "1600", date => "Mon, 06 Sep 2010");

=cut
sub new {
	my ($class,%profile) = @_;
	my $self = {
		title => ($profile{title} or "Unnamed"),
		text => ($profile{text} or $profile{description} or "Description Missing"),
		link => ($profile{link} or "about:blank"),
		cat => ($profile{cat} or $profile{category} or "general"),
		time => ($profile{time} or "1200"),
		date => ($profile{date} or "2018-01-01"),
		guid => ($profile{guid} or "Generic"),
		gob => ($profile{guiobject} or undef),
		dob => ($profile{dataobject} or undef),
	};
	bless $self, $class;
	return $self;
}

sub get {
	my ($self,$key) = @_;
	defined $key or return undef;
	return $self->{$key};
}

sub set {
	my ($self,$key,$value) = @_;
	defined $value and defined $key or return undef;
	$self->{$key} = $value;
	return $self->{$key};
}

sub text {
	my ($self,$text,$zealous) = @_;
	defined $text or return $self->get('text');
	return $self->set('text',Common::RSSclean($text,$zealous));
}

sub name {
	my ($self,$text) = @_;
	defined $text or return $self->get('title');
	return $self->set('title',Common::RSSclean($text));
}

sub title {
	my ($self,$text) = @_;
	defined $text or return $self->get('title');
	return $self->set('title',Common::RSSclean($text));
}

sub link {
	my ($self,$text) = @_;
	defined $text or return $self->get('link');
	return $self->set('link',$text);
}

sub cat {
	my ($self,$text) = @_;
	defined $text or return $self->get('cat');
	return $self->set('cat',Common::RSSclean($text));
}

sub category {
	my ($self,$text) = @_;
	defined $text or return $self->get('cat');
	return $self->set('cat',Common::RSSclean($text));
}

sub guid {
	my ($self,$text) = @_;
	defined $text or return $self->get('guid');
	return $self->set('guid',Common::RSSclean($text));
}

sub time {
	my ($self,$text) = @_;
	defined $text or return $self->get('time');
	$text =~ /(\d\d)(\d\d)/ or return $self->get('time'); # don't accept an improper time
	return $self->set('time',$text);
}


sub date {
	my ($self,$text,$form) = @_;
	defined $form and $form == 1 and return DateTime::Format::DateParse->parse_datetime($self->get('date'))->ymd();
	defined $text or return $self->get('date');
	return $self->set('date',$text);
}

my %months = ( "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6, "Jul" => 7, "Aug" => 8, "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12, );
sub pubDate {
	my ($self,$text) = @_;
	return -1 unless (defined $text and $text ne ""); # Mon, 06 Sep 2010 00:01:00 -0500
	$text =~ /\w{3}, (\d\d) (\w\w\w) (\d{4}) (\d\d:\d\d):\d\d [+-]\d{4}/; # RSS time format for US-EN, at least
	0 and print "Extracted $4 on $2 $1, $3...\n";
	return -2 unless (defined $4);
	my ($d,$m,$y,$t) = ($1,$2,$3,$4);
	$t =~ s/://; # remove colon from time.
	$self->time($t);
	my $m = $months{$m} or 01;
	my $d = sprintf("%04s-%02s-%02s",$y,$m,$d);
	$self->date($d);
	return 0;
}

sub timestamp { # just a getter
	my $self = shift;
	$self->time =~ /(\d\d)(\d\d)/;
	(!defined $1 || !defined $2) && die "RItem found to have an improper time value (expected #### and got $self->time).";
	my $time = $self->date . " $1:$2:00 " . Sui::getTZ();
	return $time;
}

sub widget {
	my ($self,$set) = @_;
	defined $set or return $self->get('gob');
	return $self->set('gob',$set);
}

sub toReviewRow {
	my ($self,$row,$output,$viewsize,$color,%extra) = @_;
	PGK::growRow($row);
	$row->{object} = $self;
	my $gos = {};
	my $spacing = 3;
	my $title = ($self->title() eq "Unnamed" ? ($self->text() eq "Description Missing" ? $self->link() : $self->text()) : $self->title);
if ($self->title() eq "Unnamed") { print "Unnamed: " . (defined $self->get('meta') ? $self->get('meta') : "oops" ) . "\n"; }
	$$gos{time} = $row->insert( Label => text => $self->timestamp() . "  ", backColor => $color, );
	$$gos{cat} = $row->insert( Label => text => $self->category() . "  ", backColor => $color, );
	$$gos{title} = $row->insert( Label => text => Common::shorten($title,21) . "  ", backColor => $color, );
	PGK::growRow($$gos{title});
#	my $date = qq{$$x{'pubDate'}};
#	my $start = DateTime::Format::DateParse->parse_datetime( $date );
	$row->{dt} = $self->timestamp();
	my $button = $row->insert( Button => text => "", height => $viewsize + 2, width => $viewsize + 2 );
	$row->insert( Label => text => "", width => $spacing, );
	my $stat = getGUI('status');
	my ($error,$server,$img,$lfp) = PGUI::fetchapic($self->link(),$extra{hitserver} or {},$stat,$output,1);
	if ($error) {
		infMes($error,0,(gobj => $stat));
	} elsif (-r $lfp . $img ) {
		my ($pic,$iz) = PGUI::showapic($lfp,$img,$viewsize);
		$button->image($pic);
	}
	$row->insert( Button => text => "X", onClick => sub { $row->destroy(); (defined $self->{dataobject}) and $self->{dataobject} = undef; (defined $extra{rss} and defined $extra{item}) and castRSS::remove($extra{rss},$extra{item}); $self = undef; }, width =>  $viewsize, pack => { fill => 'none', expand => 0, }, ); # each RItem row should have a button to remove that item.
	$row->insert( Label => text => "", width => $spacing, );
	$row->insert( Button => text => "Edit", onClick => sub { $self->itemEditor($gos); }, pack => { fill => 'none', expand => 0, }, );# each RItem should have buttons to edit values.
}
print ".";

sub itemEditor {
	my ($self,$obs) = @_;
	my $optbox = Prima::Dialog->create( centered => 1, borderStyle => bs::Sizeable, onTop => 1, width => 300, height => 300, owner => getGUI('mainWin'), text => "Edit " . $self->title(), valignment => ta::Middle, alignment => ta::Left,);
	my $bhigh = 18;
	my $extras = { height => $bhigh, };
	my $buttons = mb::Ok;
	my $context = Sui::passData('context');
	my $vbox = $optbox->insert( VBox => autowidth => 1, pack => { fill => 'both', expand => 1, anchor => "nw", }, alignment => ta::Left, );
	my $nb = labelBox($vbox,"Name",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $lb = labelBox($vbox,"Link",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $tb = labelBox($vbox,"Text",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $cb = labelBox($vbox,"Category",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $ub = labelBox($vbox,"Time",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $gb = labelBox($vbox,"GUID",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
	my $ne = $nb->insert( InputLine => name => 'input', text => $self->title() );
	my $le = $lb->insert( InputLine => name => 'input', text => $self->link() );
	my $te = $tb->insert( InputLine => name => 'input', text => $self->text() );
	my $ce = $cb->insert( InputLine => name => 'input', text => $self->cat() );
	my $ue = $ub->insert( InputLine => name => 'input', text => $self->time() );
	my $ge = $gb->insert( InputLine => name => 'input', text => $self->guid() );
	$nb->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $self->title($ne->text); $$obs{title} and $$obs{title}->text($ne->text); });
	$lb->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $self->link($le->text); $$obs{link} and $$obs{link}->text($le->text);});
	$tb->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $self->text($te->text); $$obs{text} and $$obs{text}->text($te->text);});
	$cb->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $self->cat($ce->text); $$obs{cat} and $$obs{cat}->text($ce->text);});
	$ub->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $self->time($ue->text); $$obs{time} and $$obs{time}->text($ue->text);});
	$gb->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $self->guid($ge->text); $$obs{guid} and $$obs{guid}->text($ge->text);});
	my $spacer = $vbox->insert( Label => text => " ", pack => { fill => 'both', expand => 1 }, );
	if ($context eq 'library') {
		my $rb = labelBox($vbox,"Recurrence",'r','H', boxfill => 'y', boxex => 1, labfill => 'x', labex => 1);
		my $re = $rb->insert( InputLine => name => 'input', text => $self->get('recur') );
		$rb->insert( Button => text => "Commit", height => $bhigh, onClick => sub { $self->set('recur',$re->text); });
	}
	my $fresh = Prima::MsgBox::insert_buttons( $optbox, $buttons, $extras); # not reinventing wheel
	$fresh->set( font => applyFont('button'), );
	$optbox->execute;
}
print ".";

print " OK;";
1;
