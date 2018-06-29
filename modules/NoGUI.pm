package NoGUI;
print __PACKAGE__;


package StatusBar;

sub new {
	my %self = {};
	my $ref = \%self;
	bless $ref, StatusBar;
	return $ref;
}

sub prepare {
	my $self = shift;
#	$self->set(
#		readOnly => 1,
#		selectable => 0,
#		text => ($self->text() or ""),
#		backColor => $self->owner()->backColor(),
#	);
#	$self->pack( fill => 'x', expand => 0, side => "bottom", );
	return $self; # allows StatusBar->new()->prepare() call
}

sub push {
	my ($self,$text) = @_;
	print "$text\n"
}
print ".";


package NoGUI;

print "OK; ";