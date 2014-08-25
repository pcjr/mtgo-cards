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

=item fixCardNames ($cardname)

Examine $cardname for special characters and convert them to our standard
ascii equivalents.

=cut
#
############################################################################
#       
sub fixCardNames
{       
        my $self = shift;
	my $cardname = shift;

	$cardname =~ s/^\303\206/AE/g;	# Fix cards like: AEther
	$cardname =~ s/^\303\241/u/g;	# Fix cards like: Juzam
	$cardname =~ s/^\303\242/u/g;	# Fix cards like: Dandan
	$cardname =~ s/^\303\255/u/g;	# Fix cards like: Ifh-Biff
	$cardname =~ s/^\303\266/u/g;	# Fix cards like: Jotun
	$cardname =~ s/^\303\273/u/g;	# Fix cards like: Lim-Dul
	return($cardname);
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
		'10E'	=> 'Tenth Edition',
		'5DN'	=> 'Fifth Dawn',
		'7E'	=> 'Seventh Edition',
		'8ED'	=> 'Eighth Edition',
		'9ED'	=> 'Ninth Edition',
		'ALA'	=> undef,
		'ALL'	=> undef,
		'AP'	=> undef,
		'ARB'	=> 'Alara Reborn',
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
		'DGM'	=> "Dragon's Maze",
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
		'M10'	=> 'Magic 2010',
		'M11'	=> 'Magic 2011',
		'M12'	=> 'Magic 2012',
		'M13'	=> 'Magic 2013',
		'M14'	=> 'Magic 2014 Core Set',
		'M15'	=> 'Magic 2015 Core Set',
		'MBS'	=> undef,
		'ME2'	=> 'Masters Edition II',
		'ME3'	=> 'Masters Edition III',
		'ME4'	=> 'Masters Edition IV',
		'MED'	=> 'Masters Edition',
		'MI'	=> 'Mirage',
		'MM'	=> 'Mercadian Masques',
		'MMA'	=> 'Modern Masters',
		'MOR'	=> 'Morningtide',
		'MRD'	=> 'Mirrodin',
		'NE'	=> 'Nemesis',
		'NPH'	=> 'Nemesis',
		'OD'	=> 'Odyssey',
		'ONS'	=> 'Onslaught',
		'PC1'	=> undef,
		'PC2'	=> undef,
		'PLC'	=> 'Planar Chaos',
		'PR'	=> undef,
		'PRM'	=> undef,
		'PS'	=> undef,
		'RAV'	=> 'Ravnica: City of Guilds',
		'ROE'	=> 'Rise of the Eldrazi',
		'RTR'	=> 'Return to Ravnica',
		'SCG'	=> 'Scourge',
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
