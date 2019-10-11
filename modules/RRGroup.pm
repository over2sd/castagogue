package RRGroup; # Groups for random rotation
# A monthly rotation may be achieved with an RRGroup of 30/31/61 rows
=head2 RRGroup

A group for storing randomizeable lists containing names and descriptions in rows for easy manipulation.
	
=head3 Usage

 my $group = RRGroup->new(order => "striped");
 my ($index,$length) = $group->add(0,{name => "Tom Swift", age => 32},{name => "Harry Houdini", age => 27},{name => "John Smith", address => "1 Any St."});

=head3 Methods

=cut
sub new {
	my ($class,%profile) = @_;
	my $order = RRGroup->order($profile{order},1); # given value might need conversion.
	my $self = {
		order => $order,
		rows => ( $profile{rows} || []),
		names => ( $profile{names} || []),
	};
	bless $self,$class;
	return $self;
}

sub add { # add hashes to a row.
	my ($self,$rownum,@items) = @_;
	my $r = $self->{rows}; # grab our list of rows
	my $max = ($#$r < 0 ? 0 : $#$r); # find the highest available row
#	if ($rownum < 0) { $rownum = $max; }
	while ($max < $rownum) { # if higher than existing:
		my $newrow = []; # add a new row, as user indicated desire for a higher row
		push(@$r,$newrow); # push the new row into the list of rows
		$max = $#$r; # update max, since we're about to use it
	}
	unless (defined $$r[$rownum]) { $$r[$rownum] = []; } # failsafe
	$r = $$r[$rownum]; # row established. Use this row.
	$max = ($#$r < 0 ? 0 : $#$r); # find the highest available column
	my $length = 0;
	for (my $i = 0; $i <= $#items; $i++) {
		unless (ref $items[$i] eq "RItem") { # regular hash
			my %tr;
			foreach my $k (keys %{$items[$i]}) {
				$tr{$k} = ${$items[$i]}{$k};
			}
			$length++;
			push(@$r,\%tr);
		} else { # item is an RItem object.
			$length++;
			push(@$r,$items[$i]); # store RItems as-is.
		}
	}
	return ($max,$length); # first column used, items added
}

sub item {
	my ($self,$rownum,$item) = @_;
	return {error => -1} unless (defined $rownum && $rownum >= 0 && $rownum <= $self->rows()); # choke if not given a valid row.
	return {error => -2} unless (defined $item && $item >= 0 && $item <= $self->items($rownum)); # choke if not given a valid item.
	my @r = $self->row($rownum);
	return $r[$item]; # return the hashref
}

sub items { # gets the number of items in a row
	my ($self,$rownum) = @_;
	return scalar($self->row($rownum));
}

sub maxr {
	return $_[0]->rows() - 1;
}

sub name {
	my ($self,$row) = @_;
	defined $row or $row = $self->maxr(); # gives name of highest row if no row number given!
	my @names = @{$self->{names}};
	return $names[$row];
}

sub names {
	my ($self,$first,$last) = @_;
	defined $first or $first = 0;
	defined $last or $last = $self->maxr();
	my @names = @{$self->{names}};
	splice(@names,$first,$last - $first);
	return @names;
}

=item order ORDERTYPE INFONLY

Gets or sets the group's sequencing order. ORDERTYPE is the index (int) or name (string) of the ordering style. A 1 passed as INFONLY will return the requested value without storing the ordering style in the record.
Example usages:

 $group->order("striped",1);  # returns 1 (value of striped)
 $group->order(3,1); 		  # returns 3
 $group->order(-1);			  # returns the RRGroup's order as a name
 $group->order();			  # returns the RRGroup's order as a value
 $group->order("mixed");	  # sets the RRGroup's order to 3 and returns 3
 $group->order(2);	  		  # sets the RRGroup's order to 2 and returns 2

=cut

sub order { # get or set the order
	my ($self,$order,$nostore) = @_;
	defined $order || return $self->{order}; # called as a getter.
	my %orders = ( "none" => 0, "striped" => 1, "grouped" => 2, "mixed" => 3,"sequenced" => 4,);
	unless ($order =~ m/-?\d+/) {
		$order = ($orders{$order} or $order);
	}
	unless ($order == -1) { # only do this if not querying for order name
		return $order if ($nostore); # send back the order (probably translated from name to value) if $nostore is true.
		$self->{order} = int($order) if (defined $order); # otherwise, store the value in our order field.
	} else {
		foreach my $k (keys %orders) {
			return $k if $orders{$k} == $self->{order}; # if given "-1", try to return the name of the order instead of its code value.
		}
	}
	return $self->{order};
}

sub row {
	my ($self,$rownum) = @_;
	my $r = $self->{rows}; # grab our list of rows
	my $max = ($#$r < 0 ? 0 : $#$r); # find the highest available row
	if ($max < $rownum) { # if higher than existing:
		main::howVerbose() and warn "\n[W] RRGroup asked to return row $rownum of $max. This should be avoided";
		return []; # Just return an empty array. The user is responsible for not looping infinitely.
	}
	$r = $$r[$rownum]; # row established. Use this row.
	return @{$r}; # if found, return the array of hashes.
}

sub rowloop {
	my ($self,$rownum) = @_;
	my $lr = $self->items($rownum) - 1;
	return (0 .. $lr);
}

sub rowname {
	my ($self,$rownum,$rowname) = @_;
	return undef unless defined $rownum; # row number is not optional!
	my $max = $self->maxr(); # What's our highest row?
	if ($rownum > $max) { # row number too high...
		unless ($max + 1 <= $rownum && defined $rowname) { # we'll generate a new row, if it's one above max; otherwise...
			main::howVerbose() and warn "\n[W] Tried to identify row $rownum of $max. This should be avoided"; # maybe carp about it.
			return undef;
		}
		my $rows = $self->{rows}; # get our rows
		$$rows[$rownum] = []; # make an empty row for this name
	}
	my $rna = $self->{names}; # get list of names
	if ($rownum < 0) {
		return "Invalid subscript $rownum";
	}
	defined $rowname and ($$rna[$rownum] = $rowname); # rename given row
	return $$rna[$rownum]; # pass name back to caller.
}

sub rows {
	my $self = shift;
	my $r = $self->{rows}; # grab our list of rows
	return scalar(@{$r}); # number of rows.
}

sub sequence {
	my ($self,$count) = @_;
	my @list;
	foreach my $r (0..$self->maxr()) {
		my @row = $self->row($r);
		push(@list,\@row);
	}
	return Common::sequenceAoA(\@list,$self->order(),-1); # pass back a copy of the sequence
}
print ".";

print "OK; ";
1;
