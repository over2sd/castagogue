package RItem; # RSS Items
print __PACKAGE__;
=head2 RItem

RSS Item. Stores information for an item to be published to an RSS feed object.

=head3 Usage

  my $item = RItem->new(title => "Item Title", text => "Item description", link => "http://www.url.com/", cat => "news", time => "1600", date => "Mon, 06 Sep 2010");

=cut
sub new {
	my ($class,%profile) = @_;
	my $self = {
# 	dexmod nat deflect notff nottch miscmod speed conscore maxhp init );

		title => ($profile{title} or "Unnamed"),
		text => ($profile{text} or "Description Missing"),
		link => ($profile{link} or "about:blank"),
		cat => ($profile{cat} or "general"),
		time => ($profile{time} or "1200"),
		date => ($profile{date} or "Mon, 01 Jan 2018"),
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
	my ($self,$text) = @_;
	defined $text or return $self->get('text');
	return $self->set('text',Common::RSSclean($text));
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

sub time {
	my ($self,$text) = @_;
	defined $text or return $self->get('time');
	return $self->set('time',$text);
}


sub date {
	my ($self,$text) = @_;
	defined $text or return $self->get('date');
	return $self->set('date',$text);
}
print ".";

1;