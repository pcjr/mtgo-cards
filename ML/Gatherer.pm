package ML::Gatherer;

use Exporter ();
@ISA = qw(Exporter);
@EXPORT =
qw(
);

use strict;
use warnings;

use LWP::UserAgent;
use HTML::Form;
use HTML::TableExtract;
use HTTP::Cookies;

=head1 NAME

ML::Gatherer - Gatherer interface

=head1 SYNOPSIS

    use ML::Gatherer;

=head1 DESCRIPTION

This package provides an interface for downloading and managing
Gatherer data.

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

Create an instance of a B<ML::Gatherer> object.

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
                'URL'	=> 'http://gatherer.wizards.com/Pages/Search/Default.aspx',
		'USER_AGENT'		=> undef,
		'USER_AGENT_NAME'	=> 'Mozilla/5.0 ',
		'COOKIE_JAR'	=> 'lwp_cookies.dat',
		'VERBOSE'	=> 0,
        };      
                
        bless($self, $class);   
        return($self);
}       
#
############################################################################
#

=item fetch ($name, $dir)

Fetch the Gatherer data for the set named $name.
Data is written to $dir if set. Otherwise it is returned as a single string.
$dir must already exist.

=cut
#
############################################################################
#       
sub fetch
{       
        my($self) = shift;
	my($name, $dir) = @_;

	my $ua = $self->userAgent;
	# Construct URL
#http://gatherer.wizards.com/Pages/Search/Default.aspx?output=checklist&sort=cn+&set=%5b%22Vintage+Masters%22%5d
	my $url = $self->url .
		'?output=checklist&sort=cn+&set=["' .
		$name .
		'"]';
	# Fetch page
	print "** fetch(): getting: $url\n" if $self->verbose;
	my($res) = $ua->get($url);
	if (!$res->is_success)
	{
		print STDERR "ERROR: fetch(): failed for: $url\nStatus line: ",
			$res->status_line, "\n";
		return(undef);
	}
	print "** fetch(): bytes downloaded: ${\(length($res->content))}\n" if $self->verbose;
	# Extract table and then row data
	# Don't need to specify every table header column,
	# just the ones we want to extract
	# just enough to uniquely match the table...
	# # Name Artist Color Rarity Set
	# Generate XML
	# Return XML???
}       
#
############################################################################
#

=item userAgent ($agent)

Get or set user agent. Create one if it doesn't already exist.

=cut
#
############################################################################
#       
sub userAgent
{       
        my $self = shift;
	#
	## Initialize LWP object #############################################
	#
	$self->{'USER_AGENT'} = shift if (@_);
	return($self->{'USER_AGENT'}) if $self->{'USER_AGENT'};
	my($agent) = LWP::UserAgent->new(
		'agent' => $self->userAgentName,
	);
	$agent->cookie_jar(HTTP::Cookies->new(
		'file' => $self->cookieJar,
		'autosave' => 1,
		'ignore_discard' => 1,
	));
	print "** userAgent(): cookie jar: ${\($self->cookieJar)}\n" if $self->verbose;
	return($self->userAgent($agent));
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

=item cookieJar ()

Get or set the path to the file used to store cookies.

=cut
#
############################################################################
#       
sub cookieJar
{       
        my($self) = shift;
                
	$self->{'COOKIE_JAR'} = shift if (@_);
	return($self->{'COOKIE_JAR'});
}       
#
############################################################################
#

=item url ()

Get or set the base URL associated with Gatherer.

=cut
#
############################################################################
#       
sub url
{       
        my($self) = shift;
                
	$self->{'URL'} = shift if (@_);
	return($self->{'URL'});
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

=item userAgentName ()

Get or set the base User Agent to report to the remote web server.

=cut
#
############################################################################
#       
sub userAgentName
{       
        my($self) = shift;
                
	$self->{'USER_AGENT_NAME'} = shift if (@_);
	return($self->{'USER_AGENT_NAME'});
}       
#
############################################################################
#

=back

=head1 AUTHOR

Peter Costantinidis

=cut

1;
