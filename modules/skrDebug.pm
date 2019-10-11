package skrDebug;

$|++; # immediate STDOUT, one would hope.
use Data::Dumper; # used by debug statements that unpack references.
use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( Dumper dump );

sub dump {
	my ($var,$vname) = @_;
	print "\n\tExamining $vname:\n";
	print Dumper $var;
}

sub keylist {
	my ($var,$vname) = @_;
	print "\n\tKeys of $vname:\n";
	print join(", ",sort keys %$var);
}

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