#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use ML::Gatherer;
use ML::Static;
use ML::Storage;
use ML::MTGO;
#
## TODO ####################################################################
#
# Consider what, if anything, to do about the cookie file before we exit
#
## Argument handling #######################################################
#
my $me = "revccrc";
my @saveargs = @ARGV;
my @optdescs =
(
	"debug",
	"db=s",
	"force",
	"help",
	"man",
	"quiet",
	"verbose",
);
my %opts = ();
$Getopt::Long::autoabbrev  = 1;
$Getopt::Long::ignorecase = 0;
if (!GetOptions(\%opts, @optdescs))
{
	print STDERR "$me: error: usage error\n";
	exit(2);
}
pod2usage(0) if $opts{'help'};
pod2usage('-exitstatus' => 0, '-verbose' => 2) if $opts{'man'};
my $d = $opts{'debug'};
my $v = $opts{'verbose'};
my $q = $opts{'quiet'};
my $datadir = $opts{'db'} || 'mcdata';
#
## Sanity checks ###########################################################
#
my %commands =
(	# future planned commands are listed with value of undef
	'check' => 1,
	'compile' => 1,
	'flipcards' => 1,
	'inventory' => 1,
	'list' => 1,
	'needed' => 1,
	'noop' => 1,
	'setlists' => 1,
	'splitcards' => 1,
	'setup' => 1,
);
@ARGV or die("error: missing sub-command");
my $command = shift;
exists($commands{$command}) or die("error: unrecognized sub-command: $command");
$commands{$command} or die("error: unimplemented sub-command: $command");
#
## Startup initialization ################################################
#
my $db = ML::Storage->new($datadir);
my $mcs = ML::Static->new();
#
## Run command ###########################################################
#
my $status = eval("mc_$command");
defined($status) or
	die("ERROR: $@");
print "** exiting\n" if $v;
exit($status ? 0 : 1);
#
## Sub-commands ##########################################################
#
#
## mc_compile() ##########################################################
#
# Take all of the set lists and generate a new data structure that uses a
# cardname as the key. Associated with this are all the setcodes in which
# this card appears.
#
sub mc_compile
{
	my $errors = 0;
	my %cards;
	my $codes = $mcs->setMaps;

	# Get list of sets
	# Get cards from set
	foreach my $code (@$codes)
	{
		print "** Loading card set: $code\n" if $v;
		my $set = $db->set($code);
		$set or die("error: could not access set data for: $code");
		foreach my $card (keys(%{ $set->{'cards'} }))
		{
			my $name = $set->{'cards'}->{$card}->{'name'};
			$cards{ $name }->{'sets'}->{$set}++;
		}
	}
	my $xml = $db->cards(\%cards);
	return($errors ? 0 : 1);
}
#
## mc_needed() ###########################################################
#
# TODO:
#	Need to check if there's a different version of each missing card
#	that we prefer.
# If so, report ignore the card if we have all of the preferred versions.
# If we do not have all of the preferred versions, report how many of the
# preferred versions we actually need. Also note if we have a total of four
# across all sets.
#	
#
sub mc_needed
{
	my $errors = 0;
	my @sets = @ARGV;

	@sets or die("error: unimplemented functionality: must specify set name for needed");
	print "** needed'ing ${\(scalar(@sets))} set(s)\n" if $v;
	foreach my $set (@sets)
	{
		print "** needed'ing: $set\n" if $v;
		#
		## Scan inventory ########################################
		#
		print "** Loading cards from inventory\n" if $v;
		my $inv = $db->invCards($set);
		$inv or die("error: could not access inventory data for: $set");
		my %names;
		foreach my $card (@$inv)
		{
			next if $card->{'foil'};
			$names{ $card->{'name'} } = $card;
		}
		#
		## Compare card set to inventory #########################
		#
		print "** Loading card set: $set\n" if $v;
		my $set = $db->set($set);
		$set or die("error: could not access set data for: $set");
		my %needed;
		foreach my $card (keys(%{ $set->{'cards'} }))
		{
			my $name = $set->{'cards'}->{$card}->{'name'};
			if (!exists($names{ $name }))
			{
				$needed{ $name } =
				{
					'name' => $name,
					'rarity' => $set->{'cards'}->{$card}->{'rarity'},
					'quantity' => 0,
				};
				next;
			}
			next if $names{ $name }->{'quantity'} >= 4;
			$needed{ $name } = $names{ $name };
		}
		#
		## Report findings #######################################
		#
		foreach my $card (sort(keys(%needed)))
		{
			print sprintf("%d %s %s\n",
				(4 - $needed{$card}->{'quantity'}),
				$needed{$card}->{'rarity'},
				$needed{$card}->{'name'}
			);
		}
	}
	return($errors ? 0 : 1);
}
#
## mc_check() ############################################################
#
sub mc_check
{
	my $errors = 0;

	my $inv = $db->inv;
	$inv or die("error: can not load inventory");
	print "** check'ing: ${\(scalar(@{ $inv->{'sets'} }))} inventory sets\n" if $v;
	foreach my $set (@{ $inv->{'sets'} })
	{
		print "** check'ing: $set\n" if $v;
		if (!$mcs->setMaps($set))
		{
			print STDERR "CHECK: missing from set map: $set\n";
			$errors++;
			next;
		}
		my $path = $db->setPath($set);
		if (! -e $path)
		{
			print STDERR "CHECK: no inventory data for set: $set\n";
			$errors++;
			next;
		}
		my $data = $db->set($set);
		if (!$data)
		{
			print STDERR "CHECK: can not load inventory for set: $set\n";
			$errors++;
			next;
		}
	}
	$errors and die("CHECK: $errors errors found");
	return(1);
}
#
## mc_flipcards() ########################################################
#
sub mc_flipcards
{
	@ARGV and die("error: unexpected arguments");
	my $g = ML::Gatherer->new($mcs, $db);
	$g->verbose(1) if $v;
	print "** flipcards'ing\n" if $v;
	my $data = $g->flipcards();
	$data or die("error: could not fetch flipcards");
	$db->flipcards($data) or die("error: could not save flipcards");
	print "Collected ", $data->{'set_size'}, " flip cards\n" if !$q;
	return(1);
}
#
## mc_setlists() #########################################################
#
sub mc_setlists
{
	my $errors = 0;
	my @sets = @ARGV;

	my $g = ML::Gatherer->new($mcs, $db);
	$g->verbose(1) if $v;
	if (!@sets)
	{
		#
		## Determine mssing sets #################################
		#
		my $codes = $mcs->setMaps;
		$codes or die("error: could not get set codes");
		foreach my $code (@$codes)
		{
			push(@sets, $code) if ! -e $db->setPath($code);
		}
	}
	else
	{	# Don't need to check this if setMaps() was our data source
		foreach my $code (@sets)
		{	# check all set codes
			next if $mcs->setMaps($code);
			print STDERR "error: unsupported set code: $code\n";
			$errors++;
		}
	}
	$errors and die("errors: found $errors error(s)");
	print "** gather'ing ${\(scalar(@sets))} set(s)\n" if $v;
	foreach my $code (@sets)
	{
		print "** fetching: $code\n" if $v;
		my $data = $g->fetch($code);
		if (!$data)
		{
			print STDERR "error: could not fetch set: $code\n";
			$errors++;
			next;
		}
		print "** saving: $code\n" if $v;
		if (!$db->set($code, $data))
		{
			print STDERR "error: could not save set: $code\n";
			$errors++;
			next;
		}
		print "Gathered $code, ", $data->{'set_size'}, " cards\n" if !$q;
	}
	$errors and die("SETLISTS: $errors errors found");
	return(1);
}
#
## mc_setup() ############################################################
#
sub mc_setup
{
	foreach my $cmd (
		"splitcards",
		"setlists",
	)
	{
		my $status = eval("mc_$cmd");
		defined($status) or
			die("ERROR: $@");
	}
	return(1);
}
#
## mc_splitcards() #######################################################
#
sub mc_splitcards
{
	@ARGV and die("error: unexpected arguments");
	my $g = ML::Gatherer->new($mcs, $db);
	$g->verbose(1) if $v;
	print "** splitcards'ing\n" if $v;
	my $data = $g->splitcards();
	$data or die("error: could not fetch splitcards");
	$db->splitcards($data) or die("error: could not save splitcards");
	print "Collected ", $data->{'set_size'}, " split cards\n" if !$q;
	return(1);
}
#
## mc_inventory() ########################################################
#
sub mc_inventory
{

	@ARGV or die("error: missing inventory file argument");
	my $path = shift(@ARGV);
	!@ARGV or die("error: extra inventory file argument(s): " . join(', ', @ARGV));
	my $m = ML::MTGO->new($mcs);
	$m->verbose(1) if $v;
	print "** inventory'ing: $path\n" if $v;
	my $data = $m->inventory($path);
	if (!$data)
	{
		print STDERR "error: could not load inventory: $path\n";
		return(undef);
	}
	print "** saving inventory\n" if $v;
	if (!$db->inv($data))
	{
		print STDERR "error: could not save inventory\n";
		return(undef);
	}
	print "Inventoried ", $data->{'num_cards'}, " total cards\n" if !$q;
	return(1);
}
#
## mc_list() #############################################################
#
sub mc_list
{
	my $errors = 0;

	@ARGV or die("error: missing set code argument");
	print "** list'ing ${\(scalar(@ARGV))} set(s)\n" if $v;
	foreach my $code (@ARGV)
	{
		print "** list'ing: $code\n" if $v;
		my $data = $db->set($code);
		if (!$data)
		{
			print STDERR "error: could not load set: $code\n";
			$errors++;
			next;
		}
		print "Set Name: ", $data->{'set_name'}, "\n";
		print "Retrieved: ", $data->{'retrieved'}, "\n";
		print "Source: ", $data->{'source'}, "\n";
		print "Size: ", $data->{'set_size'}, "\n";
	}
	return($errors ? 0 : 1);
}
#
## mc_noop() #############################################################
#
sub mc_noop
{
	exit(0);
}

#
##########################################################################
#
__END__

=head1 NAME

mc - Magic Online Collection management tool

=head1 SYNOPSIS

	mc [-help] [-force] [-man] [-verbose] [-quiet] [-db path] command args

    Commands:
	check
	compile
	flipcards
	inventory file.csv
	list setcode ...
	noop
	setlists [setcode ...]
	setup
	splitcards

=head1 DESCRIPTION

B<mc> is a front end for managing your Magic Online collection.
It queries Gatherer for set information, parses your CSV-exported
collection data, reports cards you have less than four of, etc.
Each type of activity is specified by individual commands which
are described in the next section.

Magic Online described the set a card belongs to using its 3-letter
setcode. B<mc> does the same.

By default, data is stored as XML in a sub-directory named B<mcdata>.
The B<-db> argument can be used to over-ride this.

=head2 Initial Setup

Run this command to initialize set data from Gatherer:

	mc.pl setup

Then, run this sequence of commands to ingest collection data
originating from MtGO:

	mc.pl inventory mtgo.csv

=head1 COMMANDS

=over 4

=item B<check>

Perform various sanity checks. These include verifying:

	o existence of your inventory
	o all the set codes in your inventory are supported
	o card set data exists for all supported set codes

=item B<inventory> I<file.csv>

Process and store the specified CSV inventory file.

=item B<list> I<setcode> ...

List the contents of the specified set. Assumes this set has already
been gathered.

=item B<needed> [I<setcode> ...]

Determine which cards are needed for the collection.
If I<setcode> is specified, just report cards needed
to complete that set.

A card is needed for a collection
if the inventory contains fewer than four copies of that card from
the preferred set.
A card is needed for a set
if the inventory contains fewer than four copies of that card from
the specified set.

At this time, foil cards are ignored for purposes of being needed.

=item B<noop>

This sub-command does mostly nothing. The directory for persistent
data will be created if it doesn't exist. If you don't want this
to happen, specify B<.> for the B<-db> argument.

=item B<setlists> I<setcode> ...

Collect information from Gatherer about the specified sets.
This information is stored in the data directory in a file
whose name begins with the I<setcode> followed by a B<.xml> suffix.

If the set information already exists, then B<mc> does nothing
unless the B<-force> argument was specified.

If no I<setcodes> are specified, then all sets missing Gatherer
information are collected.

=item B<setup>

This is equivalent to running this sequence of commands:

	mc.pl splitcards
	mc.pl setlists
	mc.pl compile

=item B<splitcards>

Retrieve information about split cards from Gatherer.
This informaiton must be retrieved each time a enw set is released
that contains plsit cards.

=back

=head1 ARGUMENTS

The command line arguments are described below.
All arguments can be abbreviated to their shortest unique values.

=over 4

=item -db path

Store persistent data in I<path>. This directory will be created
if it does not exist.

=item -force

When this argument is specified, data files will be over-written.
For example, if you asked for the Gatherer information for the B<VMA>
set to be retrieved and that file was already present,
then B<mc> wouldn't do anything by default.
If this argument was specified, B<mc> would over-write that file with
fresh information.

=item -help

Print a help message and exit.

=item -man

Prints a manual page and exits.

=item -quiet

When this argument is specified, only error messages are displayed.

=item -verbose

This argument will cause various sub-systems to report additional
details that they think you might find of interest.

=back

=head1 EXAMPLES


=head1 FILES

=head1 ENVIRONMENT VARIABLES

=over 4

=item FOO

=back

=head1 SCM INFORMATION

This tool is maintained at GitHub in
F<https://github.com/pcjr/mtgo-cards.git>.

=cut
