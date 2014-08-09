package ML::Static;

use Exporter ();
@ISA = qw(Exporter);
@EXPORT =
qw(
);
use strict;

=head1 NAME

ML::Static - Static data

=head1 SYNOPSIS

    use ML::Static;

=head1 DESCRIPTION

This package provides an interface to data that is more or less
static.

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

=item new ()

Create an instance of a B<ML::Static> object.

=cut
#
############################################################################
#
sub new
{
        my($class) = shift;
        my($dbprof) = @_;
        my($self) =
        {
        };      
                
        bless($self, $class);   
        return($self);
}       
#
############################################################################
#

=item setMaps ($code)

If $code is set, return the Gatherer name corresponding to that set code.
Otherwise, return a reference to a sorted list of all set codes.

To update this list to support newly released sets, generate a csv export
of cards from the new set. Then, examine the set code used to identify
the set. Look up that set in Gatherer to determine what name is used to
match that set. Add the set code as a key below and the Gatherer name as
the corresponding value.

=cut
#
############################################################################
#       
sub setMaps
{       
	my $self = shift;
        my %map =
	(#	Code	Gatherer name
		'10E'	=> undef,
		'5DN'	=> undef,
		'7E'	=> undef,
		'8ED'	=> undef,
		'9ED'	=> undef,
		'ALA'	=> undef,
		'ALL'	=> undef,
		'AP'	=> undef,
		'ARB'	=> undef,
		'AVR'	=> undef,
		'BNG'	=> undef,
		'BOK'	=> undef,
		'CHK'	=> undef,
		'CMD'	=> undef,
		'CON'	=> undef,
		'CSP'	=> undef,
		'DD2'	=> undef,
		'DDC'	=> undef,
		'DDD'	=> undef,
		'DDF'	=> undef,
		'DDH'	=> undef,
		'DGM'	=> undef,
		'DIS'	=> undef,
		'DKA'	=> undef,
		'DRB'	=> undef,
		'DST'	=> undef,
		'EVE'	=> undef,
		'EVG'	=> undef,
		'EX'	=> undef,
		'FUT'	=> undef,
		'GPT'	=> undef,
		'GTC'	=> undef,
		'H09'	=> undef,
		'ICE'	=> undef,
		'IN'	=> undef,
		'ISD'	=> undef,
		'JOU'	=> undef,
		'JUD'	=> undef,
		'LGN'	=> undef,
		'LRW'	=> undef,
		'M10'	=> undef,
		'M11'	=> undef,
		'M12'	=> undef,
		'M13'	=> undef,
		'M14'	=> undef,
		'M15'	=> undef,
		'MBS'	=> undef,
		'ME2'	=> undef,
		'ME3'	=> undef,
		'ME4'	=> undef,
		'MED'	=> undef,
		'MI'	=> undef,
		'MM'	=> undef,
		'MMA'	=> undef,
		'MOR'	=> undef,
		'MRD'	=> undef,
		'NE'	=> undef,
		'NPH'	=> undef,
		'OD'	=> undef,
		'ONS'	=> undef,
		'PC1'	=> undef,
		'PC2'	=> undef,
		'PLC'	=> undef,
		'PR'	=> undef,
		'PRM'	=> undef,
		'PS'	=> undef,
		'RAV'	=> undef,
		'ROE'	=> undef,
		'RTR'	=> undef,
		'SCG'	=> undef,
		'SHM'	=> undef,
		'SOK'	=> undef,
		'SOM'	=> undef,
		'ST'	=> undef,
		'TD0'	=> undef,
		'TE'	=> undef,
		'THS'	=> undef,
		'TOR'	=> undef,
		'TSB'	=> undef,
		'TSP'	=> undef,
		'UD'	=> undef,
		'UL'	=> undef,
		'UZ'	=> undef,
		'V09'	=> undef,
		'V10'	=> undef,
		'VI'	=> undef,
		'VMA'	=> 'Vintage Masters',
		'WL'	=> undef,
		'WWK'	=> undef,
		'ZEN'	=> undef,
	);
	return([sort(keys(%map))]) if !@_;
	return($map{ $_[0] });
}       
#
############################################################################
#

=back

=head1 AUTHOR

Peter Costantinidis

=cut

1;
