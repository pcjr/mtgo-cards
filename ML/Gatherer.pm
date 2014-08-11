package ML::Gatherer;

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

=item new ($mcs)

Create an instance of a B<ML::Gatherer> object. $mcs is a Magic Card Static
object.

=cut
#
############################################################################
#
sub new
{
        my($class) = shift;
	@_ or die('missing $mcs to ML::Gatherer->new()');
        my($self) =
        {
		'COOKIE_JAR'	=> 'lwp_cookies.dat',
		'MCS'		=> undef,
		'USER_AGENT'	=> undef,
		'USER_AGENT_NAME'	=> 'Mozilla/5.0 ',
		'VERBOSE'	=> 0,
                'URL'		=> 'http://gatherer.wizards.com/Pages/Search/Default.aspx',
        };      
                
        bless($self, $class);   
	$self->mcs(shift);
        return($self);
}       
#
############################################################################
#

=item fetch ($setcode)

Fetch the Gatherer data for the set with 3-letter code $setcode. Data is
returned as an XML string.

Returns a hash reference containing the following keys:

	created	- time/date stamp of when the data was downloaded
	source	- source for data, Gatherer URL
	set_name- Full name of set
	set_code- Three-letter code for set
	set_size- number of cards in set
	cards	- reference to list of hash references describing cards in set

=cut
#
############################################################################
#       
sub fetch
{       
        my($self) = shift;
	my($setcode) = @_;
	my $setname = $self->mcs->setMaps($setcode);
	my $ua = $self->userAgent;

	if (!$setname)
	{
		print STDERR "ERROR: fetch(): bad set code: '$setcode'\n";
		return(undef);
	}
	# Construct URL
#http://gatherer.wizards.com/Pages/Search/Default.aspx?output=checklist&sort=cn+&set=%5b%22Vintage+Masters%22%5d
	my $url = $self->url .
		'?output=checklist&sort=cn+&set=["' .
		$setname .
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
	my $te = HTML::TableExtract->new(
		'headers' => [ '#', 'Name', 'Color', 'Rarity', 'Set', ],
		'keep_html' => 1,
	);
	$te->parse($res->content);
	my $tbl = $te->first_table_found;
	if (!$tbl)
	{
		print STDERR "ERROR: fetch(): could not find table for: $setname\n";
		return(undef);
	}
	if (!$tbl->rows)
	{
		print STDERR "ERROR: fetch(): no rows in table for: $setname\n";
		return(undef);
	}
	print "** fetch(): rows in table: ${\(scalar(@{ $tbl->rows }))}\n" if $self->verbose;
	my @cards;
	my $row = 1;
	my $sname;
	foreach my $r ($tbl->rows)
	{
		my($cnum, $cname, $ccolor, $crarity);
		($cnum, $cname, $ccolor, $crarity, $sname) = @$r;
		($cname =~ m#<a [^>]*>([^<]*)</a>#) and ($cname = $1);
		$cname = $self->mcs->fixCardNames($cname);
		my %card =
		(
			'num' => $cnum,
			'name' => $cname,
			'color' => $ccolor,
			'rarity' => $crarity,
		);
		defined($ccolor) or delete($card{'color'});
		#
		## Check for unexpected html ###############################
		#
		foreach my $k (keys(%card))
		{
			print STDERR "WARNING: unexpected tag for $k in row $row: ${($card{$k})}\n" if ($card{$k} =~ m#[<>&]#);
		}
		push(@cards, \%card);
		print "**\t$cnum $crarity $sname $cname\n" if $self->verbose;
		($sname eq $setname) or
			print STDERR "WARNING: unexpected set name: $sname != $setname\n";
		$row++;
	}
	my($sec, $min, $hour, $mday, $mon, $year) = (localtime())[0..5];
	my %setinfo =
	(
		'retrieved' =>	sprintf("%04d%02d%02d-%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec),
		'set_name' =>	$setname,
		'set_code' =>	$setcode,
		'set_size' =>	scalar(@cards),
		'source' =>	$url,
		'cards' =>	\@cards,
	);
	return(\%setinfo);
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
	## Initialize LWP object ###########################################
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
