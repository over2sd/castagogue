package skrDebug;

$|++; # immediate STDOUT, one would hope.
use Data::Dumper; # used by debug statements that unpack references.
#$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 1;
#$Data::Dumper::Useqq = 1;
#$Data::Dumper::Deparse = 1;
#$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Sortkeys = 1;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( Dumper dump );

sub dump {
	my ($ref,$desc,$showref) = @_;
	my $desc2 = (defined $desc ? $desc : "Variable");
	print "$desc2 is a" . (ref($ref) eq "ARRAY" ? "n ARRAY" : " " . ref($ref)) . ".\n" if $showref;
	return if $showreff == 2;
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

sub checkRepeats {
	my ($args,@list) = @_;
	my $minired = ($$args{min} or 100);
	my $miniyel = ($$args{min2} or 500);
	my $minigre = ($$args{min3} or 1000);
	my $object = ($$args{gui} or undef);
	my $action = ($$args{colorconv} or undef);
	my $verbose = ($$args{verb} or 0);
	my @repeats = ();
	my $target = undef;
	$object and $target = $object->insert( TabbedScrollNotebook =>
			style => tns::Simple,
			tabs => ['Output'],
			name => 'output',
			tabsetProfile => {colored => 0, },
			pack => { fill => 'both', expand => 1, pady => 3, side => "left", }, );
	$object and $target = $target->insert( PGK::Table => backColor => 1279, pack => { fill => 'both', expand => 1, }, );
	my @ilr = ();
	my $cr = 0;
	my ($r,$c,$columns,$goodmargin) = (0,-1,7,10);

	foreach my $i (0 .. $#list) {
		$cr++;
		if (length @repeats > $minigre + $goodmargin) { pop @repeats; } # limit keeping
		my $item = $list[$i];
		my $ir = Common::findIn($item,@repeats);
		unshift(@repeats,$item);
		if ($ir == -1) {
			push(@ilr,$#list);
			next;
		}
		push(@ilr,$ir);
		$c++;
		if ($c >= $columns) {
			$c = 0;
			$r++;
		}
		my $col = "base";
		if ($ir < $minigre) {
			$col = "green";
			if ($ir < $miniyel) {
				$col = "yellow";
				if ($ir < $minired) {
					$col = "red";
				}
			}
		}
		$col = Common::getColorsbyName($col,1);
		$action and $col = &$action($col);
		$target and $target->place_in_table($r,$c, Label => backColor => $col, text => "$i ($ir)" );
		
	}
	my $total = 0;
	foreach my $i (@ilr) { $total += $i; }
	my $listlen = scalar @list;
	my $avgdist = $total / scalar @ilr;
	my $unirat = $avgdist * 1000 / scalar @list;
	my $textout = "$listlen items examined. Average distance between repeats: $avgdist List integrity $unirat%%";
	$object and $object->insert( Label => text => $textout );
	print "$textout\n";
}

1;
