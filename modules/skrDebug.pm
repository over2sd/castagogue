package skrDebug;

$|++; # immediate STDOUT, one would hope.
use Data::Dumper; # used by debug statements that unpack references.
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( Dumper dump );

sub dump {
	my ($ref,$desc,$showref) = @_;
	my $desc2 = (defined $desc ? $desc : "Variable");
	print "$desc2 is a" . (ref($ref) eq "ARRAY" ? "n ARRAY" : " " . ref($ref)) . ".\n" if $showref;
	print "$desc: " if defined $desc;
	print Dumper $ref;
}
print ".";

sub keylist {
	my ($var,$vname) = @_;
	print "\n\tKeys of $vname:\n";
	print join(", ",sort keys %$var);
}
print ".";

sub PGK::showoff {
	my ($o,$b) = @_;
	my $bgcol = PGK::convertColor(Common::getColors(1,1,1));
 	$o->set( backColor => $bgcol, );
	$bgcol = PGK::convertColor(Common::getColors(2,1,1));
	if ($b) {
		$o->insert( Button => text => "Here am I!", pack => {fill => "both", margin => 10, expand => 1 }, backColor => $bgcol, hint => "This is a hint");
	}
}
print ".";

1;
