package ML::MTGO;

use strict;
use warnings;

=head1 NAME

ML::MTGO - Interface to MtGO exported data

=head1 SYNOPSIS

    use ML::MTGO;

=head1 DESCRIPTION

This package provides an interface for importing and parsing
MtGO data.

=head1 TODO

=cut

#
############################################################################
#

=head2 General Methods

=over 4
#
############################################################################
#       

=item new ($mcs)

Create an instance of a B<ML::MTGO> object.
$mcs is a Magic Card Static object.

=cut
#
############################################################################
#
sub new
{
        my($class) = shift;
	@_ or die('missing $mcs to ML::MTGO->new()');
        my($self) =
        {
		'MCS'		=> undef,
		'VERBOSE'	=> 0,
        };      
                
        bless($self, $class);   
	$self->mcs(shift);
        return($self);
}       
#
############################################################################
#       

=item inventory ($path)

Load the MTGO export CSV from $path. Data is returned as an XML string.

Returns a hash reference containing the following keys:

	created	- time/date stamp of when the data was parsed
	source	- $path
	unique	- number of unique cards
	cards	- reference to list of hash references describing cards in set
	num_cards- total number of individual cards in inventory

For each card in set, the following data is maintained:

	name	- card name
	quantity- number in inventory
	rarity	- rarity
	set_code- set name abbreviation
	id	- card ID #
	clctr	- collector number
	foil	- set if card is premium

Returns false on error.

As of 2014-08-16, lines that contain non-ASCII characters in card names
(such as AEther) are usually corrupted with a control-M in the line where
a newline is expected. This code checks for such lines and should not
report them as errors.

Attempts to handle lines with various line endings.

=cut
#
############################################################################
#
sub inventory
{
        my($self) = shift;
	my($path) = @_;
	my $xml;

	if (!open(F, $path))
	{
		print STDERR "ERROR: inventory(): can't open: $path ($!)\n";
		return(undef);
	}
	#
	## Check first line ################################################
	#
	my $line = <F>;
	chomp($line);
	$line =~ s/\r$//;
	my(@expected) =
	(
		'Card Name',
		'Quantity',
		'ID #',
		'Rarity',
		'Set',
		'Collector #',
		'Premium',
	);
	my @actual = split(',', $line);
	if (@actual != 7)
	{
		print STDERR "ERROR: inventory(): unexpected number of columns (${\(scalar(@actual))} != 7) in inventory header line:\n\t$line\n";
		return(undef);
	}
	for (my $i = 0; $i < @expected; $i++)
	{
		next if $expected[$i] eq $actual[$i];
		print STDERR "ERROR: inventory(): incorrect column (${\($expected[$i])} != ${\($actual[$i])}) in inventory header line:\n\t$line\n";
		return(undef);
	}
	#
	## Local sub for parsing line ######################################
	#
	# We may need to parse multiple cards per line read...
	#
	my $parseline = sub
	{
		my($line) = @_;
		# Must strip of the initial name because of cards like
		#	"Zuberi, Golden Feather"
		#	Kongming, "Sleeping Dragon"
		my $cname = $line;
		$cname =~ s/^"(.*)",.*/$1/;
		my $l = $line;
		$l =~ s/^".*",//;
		my($cquan, $cid, $cr, $cset, $ccol, $cfoil, $extra) = split(',', $l);
		if ($extra)
		{
			print STDERR "ERROR: inventory(): line $., not 7 columns:\n\t$line\n";
			return(undef);
		}
		$cname =~ s/^"(.*)"$/$1/;
		$cname = $self->mcs->fixCardNames($cname);
		my %card =
		(
			'name' => $cname,
			'quantity' => $cquan,
			'id' => $cid,
			'rarity' => $cr,
			'set_code' => $cset,
			'clctr' => $ccol,
			'foil' => $cfoil,
		);
		return(\%card);
	};
	#
	## Process cards ###################################################
	#
	my @cards;
	my $count = 0;
	while ($line = <F>)
	{
		chomp($line);
		#
		## Check for corruption ####################################
		#
		if ($line =~ m/\r/)
		{
			my @lines = split(m/\r/, $line);
			foreach $line (@lines)
			{
				my $c = &$parseline($line);
				$c or return(undef);
				push(@cards, $c);
				$count += $c->{'quantity'};
			}
			next;
		}
		my $c = &$parseline($line);
		$c or return(undef);
		push(@cards, $c);
		$count += $c->{'quantity'};
	}
	close(F);
	#
	## Finalize data structure #########################################
	#
	my($sec, $min, $hour, $mday, $mon, $year) = (localtime())[0..5];
	my %inven =
	(
		'created' =>	sprintf("%04d%02d%02d-%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec),
		'source' =>	$path,
		'unique' =>	scalar(@cards),
		'cards' =>	\@cards,
		'num_cards' =>	$count,
	);
	return(\%inven);
}       
#
############################################################################
#

=back

=head2 Configurable Settings

These subroutines can be used to fetch or modify the constant values
set in new().

=over 4
#
############################################################################
#

=item mcs ()

Get or set the ML::Static object.

=cut
#
############################################################################
#       
sub mcs
{       
        my($self) = shift;
                
	$self->{'MCS'} = shift if (@_);
	return($self->{'MCS'});
}       
#
############################################################################
#

=item verbose ()

Get or set the verbosity level.

=cut
#
############################################################################
#       
sub verbose
{       
        my($self) = shift;
                
	$self->{'VERBOSE'} = shift if (@_);
	return($self->{'VERBOSE'});
}       
#
############################################################################
#

=back

=head1 AUTHOR

Peter Costantinidis

=cut

1;
