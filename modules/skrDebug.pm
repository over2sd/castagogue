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
1;
