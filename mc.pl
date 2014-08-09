#!/usr/bin/perl
use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use File::Path;
use ML::Gatherer;
use ML::Static;
#
## TODO ####################################################################
#
# Consider what, if anything, to do about the cookie file
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
my $db = $opts{'db'} || 'mcdata';
#
## Sanity checks ###########################################################
#
my %commands =
(
	'gatherer' => 1,
	'noop' => 1,
);
@ARGV or die("error: missing sub-command");
my $command = shift;
exists($commands{$command}) or die("error: unrecognized sub-command: $command");
#
## Startup initialization ################################################
#
my $mcs = ML::Static->new();
if (-e $db and $command ne 'noop')
{
	make_path($db,
	{
		'verbose' => $v,
	});
}
#
## Run command ###########################################################
#
eval("mc_$command");
exit($?);
#
## Sub-commands ##########################################################
#
#
## mc_gatherer() #########################################################
#
sub mc_gatherer
{
	my $errors = 0;

	@ARGV or die("error: missing set code argument");
	my $g = ML::Gatherer->new();
	$g->verbose(1) if $v;
	foreach my $code (@ARGV)
	{	# check all set codes
		next if $mcs->setMaps($code);
		print STDERR "error: unsupported set code: $code\n";
		$errors++;
	}
	$errors and die("errors: found $errors error(s)");
	print "** fetching ${\(scalar(@ARGV))} set(s)\n" if $v;
	foreach my $code (@ARGV)
	{
		my $name = $mcs->setMaps($code);
		print "** fetching: $name\n" if $v;
		my $xml = $g->fetch($name);
	}
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
	gatherer setcode ...
	noop

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

=head1 COMMANDS

=over 4

=item gatherer setcode ...

Collect information from Gatherer about the specified sets.
This information is stored in the data directory in a file
whose name begins with the I<setcode> followed by a B<.xml> suffix.

If the set information already exists, then B<mc> does nothing
unless the B<-force> argument was specified.

=item noop

This sub-command does nothing.

=back

=head1 ARGUMENTS

The command line arguments are described below.
All arguments can be abbreviated to their shortest unique values.

=over 4

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
