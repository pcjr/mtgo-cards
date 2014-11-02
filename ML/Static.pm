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
		'ALA'	=> "Alara Reborn",
		'ALL'	=> "Alliances",
		'AP'	=> "Apocalypse",
		'ARB'	=> 'Alara Reborn',
		'AVR'	=> "Avacyn Restored",
		'BNG'	=> "Born of the Gods",
		'BOK'	=> "Betrayers of Kamigawa",
		'CHK'	=> "Champions of Kamigawa",
		# Commander
		#Commander 2013 Edition
		#Commander's Arsenal
		'CMD'	=> 'Magic: The Gathering-Commander',
		'CON'	=> "Conflux",
		'CSP'	=> "Coldsnap",
		# Duel Decks
		#Duel Decks: Ajani vs. Nicol Bolas
		#Duel Decks: Divine vs. Demonic
		#Duel Decks: Elspeth vs. Tezzeret
		#Duel Decks: Elves vs. Goblins
		#Duel Decks: Garruk vs. Liliana
		#Duel Decks: Heroes vs. Monsters
		#Duel Decks: Izzet vs. Golgari
		#Duel Decks: Jace vs. Chandra
		#Duel Decks: Jace vs. Vraska
		#Duel Decks: Knights vs. Dragons
		#Duel Decks: Phyrexia vs. the Coalition
		#Duel Decks: Sorin vs. Tibalt
		#Duel Decks: Speed vs. Cunning
		#Duel Decks: Venser vs. Koth
		'DD2'	=> 'Duel Decks: Jace vs. Chandra',
		'DDC'	=> 'Duel Decks: Divine vs. Demonic',
		'DDD'	=> 'Duel Decks: Garruk vs. Liliana',
		'DDF'	=> 'Duel Decks: Elspeth vs. Tezzeret',
		'DDH'	=> 'Duel Decks: Ajani vs. Nicol Bolas',
		'DGM'	=> "Dragon's Maze",
		'DIS'	=> "Dissension",
		'DKA'	=> "Dark Ascension",
		'DRB'	=> 'From the Vault: Dragons',
		'DST'	=> "Darksteel",
		'EVE'	=> 'Eventide',
		'EVG'	=> 'Duel Decks: Elves vs. Goblins',
		'EX'	=> 'Exodus',
		'FUT'	=> 'Future Sight',
		'GPT'	=> 'Guildpact',
		'GTC'	=> 'Gatecrash',
		'H09'	=> 'Premium Deck Series: Slivers',
		'ICE'	=> 'Ice Age',
		'IN'	=> 'Invasion',
		'ISD'	=> 'Innistrad',
		'JOU'	=> 'Journey into Nyx',
		'JUD'	=> 'Judgment',
		'LGN'	=> 'Legions',
		'LRW'	=> 'Lorwyn',
		'M10'	=> 'Magic 2010',
		'M11'	=> 'Magic 2011',
		'M12'	=> 'Magic 2012',
		'M13'	=> 'Magic 2013',
		'M14'	=> 'Magic 2014 Core Set',
		'M15'	=> 'Magic 2015 Core Set',
		'MBS'	=> 'Mirrodin Besieged',
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
		'PC1'	=> 'Planechase',
		'PC2'	=> 'Planechase 2012 Edition',
		'PLC'	=> 'Planar Chaos',
		'PR'	=> 'Prophecy',
		#'PRM'	=> undef,
		'PS'	=> 'Planeshift',
		'RAV'	=> 'Ravnica: City of Guilds',
		'ROE'	=> 'Rise of the Eldrazi',
		'RTR'	=> 'Return to Ravnica',
		'SCG'	=> 'Scourge',
		'SHM'	=> 'Shadowmoor',
		'SOK'	=> 'Saviors of Kamigawa',
		'SOM'	=> 'Scars of Mirrodin',
		'ST'	=> 'Stronghold',
		#'TD0'	=> undef,
		'TE'	=> 'Tempest',
		'THS'	=> 'Theros',
		'TOR'	=> 'Torment',
		'TSB'	=> 'Time Spiral "Timeshifted"',
		'TSP'	=> 'Time Spiral',
		'UD'	=> "Urza's Destiny",
		'UL'	=> "Urza's Legacy",
		'UZ'	=> "Urza's Saga",
		'V09'	=> 'From the Vault: Exiled',
		'V10'	=> 'From the Vault: Relics',
		'VI'	=> 'Visions',
		'VMA'	=> 'Vintage Masters',
		'WL'	=> 'Weatherlight',
		'WWK'	=> 'Worldwake',
		'ZEN'	=> 'Zendikar',
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
