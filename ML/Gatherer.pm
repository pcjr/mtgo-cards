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

Create an instance of a B<ML::Gatherer> object.
$ mcs is a Magic Card Static object.

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

Fetch the Gatherer data for the set with set abbreviation code $setcode.
Returns a hash reference containing the following keys:

	cards	- reference to list of hash references describing cards in set
	retrieved- time/date stamp of when the data was downloaded
	seconds - how many seconds it took to download and parse the data
	set_code- set name abbreviation
	set_name- Full name of set
	set_size- number of cards in set
	source	- source for data, actual Gatherer URL used for download

Below is information for how we use Gatherer.

The B<Checklist> format from Gatherer contains the following columns:
	# Name Artist Color Rarity Set

The B<Compact> format from Gatherer contains the following columns:
	Name Cost Type P T Printings

B<Checklist> will show you all the cards in one page. B<Compact> won't,
but there's a B<Results Per Page> preference setting should be able to
control this. However, if you use this, then everything becomes 25
entries per page. You have to delete the cookie to get back the oringinal
behavior.

The B<Printings> column of the B<Compact> display contains the GathererIDs.
If the same card appears in a set multiple times, the B<Checklist> will
contain identical rows (bug?).  B<Compact> will contain links to individual
Gatherer entries via the B<Printings> column. It is from here that you can
obtain the GathererIDs. However, this requires that you load multiple pages.
It seems that you can only get 100 results per page for the B<Compact>
display.

When we encounter a duplicate card name from the B<Checklist> display,
we ignore the extra ones. When processing the B<Compact> display, we
also check for duplicate card names. When we find one, we replicate
the existing card entry that we got from the B<Checklist> display and
assign it the GathererID.

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
	my $tstart = time();

	if (!$setname)
	{
		print STDERR "ERROR: fetch(): bad set code: '$setcode'\n";
		return(undef);
	}
	#
	## First download Checklist display ################################
	#       
	my $display = 'checklist';
	my $url = $self->url($setname, $display);
	print "** fetch(): getting checklist: $url\n" if $self->verbose;
	my($res) = $ua->get($url);
	if (!$res->is_success)
	{
		print STDERR "ERROR: fetch(): failed for: $url\nStatus line: ",
			$res->status_line, "\n";
		return(undef);
	}
	print "** fetch(): bytes downloaded: ${\(length($res->content))}\n" if $self->verbose;
	my $rows = $self->getRows($res->content, [ '#', 'Name', 'Color', 'Rarity', 'Set', ]);
	if (!$rows)
	{
		print STDERR "ERROR: fetch(): could not find $display table for: $setname\n";
		return(undef);
	}
	print "** fetch(): rows in $display table: ${\(scalar(@{ $rows }))}\n" if $self->verbose;
	my %cards;
	my $row = 1;
	my $sname;
	foreach my $r (@$rows)
	{
		my($cnum, $cname, $ccolor, $crarity);
		($cnum, $cname, $ccolor, $crarity, $sname) = @$r;
		($cname =~ m#<a [^>]*>([^<]*)</a>#) and ($cname = $1);
		$cname = $self->mcs->fixCardNames($cname);
		$cnum = 'N/A' if !$cnum; # no card number for old sets
		#
		## Remember duplicate card names ###########################
		#
		if ($cards{$cname})
		{
			$cards{$cname}->{'_c'}++;
			$cards{$cname}->{'printings'} = $cards{$cname}->{'_c'};
			next;
		}
		#
		## Save card ###############################################
		#
		my %card =
		(
			'num'	=> $cnum,
			'name'	=> $cname,
			'color'	=> $ccolor,
			'rarity'=> $crarity,
			'_c'	=> 1,	# used to count number of duplicates
		);
		defined($ccolor) or delete($card{'color'});
		#
		## Check for unexpected html ###############################
		#
		foreach my $k (keys(%card))
		{
			print STDERR "WARNING: row $row, unexpected text for column $k: ${\($card{$k})}\n" if ($card{$k} =~ m#[<>&]#);
		}
		$cards{$cname} = \%card;
		#Too much output: print "**\t$cnum $crarity $sname $cname\n" if $self->verbose;
		($sname eq $setname) or
			print STDERR "WARNING: row $row, unexpected set name: $sname != $setname\n";
		$row++;
	}
	#
	## Download Compact display ########################################
	#
	$display = 'compact';
	my $url_compact = $self->url($setname, $display);
	my $page = 0;
	while (1)	# we quit after 100 pages...
	{
		my $url_page = $url_compact . '&page=' . $page;
		print "** fetch(): getting $display: $url_page\n" if $self->verbose;
		my($res) = $ua->get($url_page);
		if (!$res->is_success)
		{
			print STDERR "ERROR: fetch(): failed for: $url_page\nStatus line: ",
				$res->status_line, "\n";
			return(undef);
		}
		print "** fetch(): bytes downloaded: ${\(length($res->content))}\n" if $self->verbose;
		my $rows = $self->getRows($res->content, [ 'Name', 'Type', 'Printings', ]);
		if (!$rows)
		{
			print STDERR "ERROR: fetch(): could not find $display table for: $setname\n";
			return(undef);
		}
		print "** fetch(): rows in $display table: ${\(scalar(@{ $rows }))}\n" if $self->verbose;
		foreach (@$rows)
		{
			my($cname, $ctype, $cprinting) = @$_;
			($cname =~ m#<a [^>]*>([^<]*)</a>#) and ($cname = $1);
			$cname = $self->mcs->fixCardNames($cname);
#print STDERR "DEBUG: compact card: '$cname'\n";
			# Taking a short cut here instead if using a full
			# parser to get the anchor tags containing the
			# GatherIDs
# <a onclick="return CardLinkAction(event, this, 'SameWindow');" href="../Card/Details.aspx?multiverseid=220947">
			while ($cprinting =~ m/.*?<a\s.*?multiverseid=(\d+)"/)
			{
				my $id = $1;
				if ($cards{$cname}->{'gid'})
				{	# already found this card, multiple
					# printings - duplicate it
#print STDERR "DEBUG: found duplicate card: $cname\n";
					my %newcard = %{ $cards{$cname} };
					$newcard{'gid'} = $id;
					# Add to has with unique name
					$cards{$cname . $id} = \%newcard;
					$newcard{'_c'} = 0;
					$cards{$cname}->{'_c'}--;
				}
				else
				{
#print STDERR "DEBUG: card: $cname, gid: $id\n";
					$cards{$cname}->{'gid'} = $id;
					$cards{$cname}->{'_c'}--;
				}
				$cprinting =~ s#.*?</a>##;
			}
		}
		#
		## Determine if more pages #################################
		#
		$page++;
		my $str = $res->content;
#print STDERR "DEBUG: checking for page controls page: $page\n";
		last if $str !~ m/.*class="pagingcontrols">(.*)$/s;
		$str = $1;	# there are pages
		# See if there are pages beyond the current one
		last if $str !~ m#/Pages.*?page=$page\&amp;#;
#print STDERR "DEBUG: next page: $page\n";
		if (!$page > 100)
		{
			print STDERR "ERROR: fetch(): too man compact pages for: $setname\n";
			return(undef);
		}
	}
	#
	## Handle split cards ##############################################
	#
	# Look for two cards with the same num and gid
	# Create new card with name that's the same name as the card found
	# in the MTGO inventory...might need to hard code the set of split cards...
	# Split cards do not have a collector number in the MTGO inventory!!!
	#
	## Generate card list ##############################################
	#
	my @list;
	foreach my $name (sort(keys(%cards)))
	{
		if ($cards{$name}->{'_c'})
		{
			print STDERR "ERROR: fetch(): missing ",
				$cards{$name}->{'_c'}, " copies of card: $name\n";
			return(undef);
		}
		# Delete the temporary '_c' hash entries...
		delete($cards{$name}->{'_c'});
		push(@list, $cards{$name});
	}
	#
	## Complete data structure #########################################
	#
	my($sec, $min, $hour, $mday, $mon, $year) = (localtime())[0..5];
	my %setinfo =
	(
		'retrieved' =>	sprintf("%04d%02d%02d-%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec),
		'set_name' =>	$setname,
		'set_code' =>	$setcode,
		'set_size' =>	scalar(@list),
		'source' =>	$url,
		'cards' =>	\@list,
		'seconds' =>	time() - $tstart,
	);
	return(\%setinfo);
}       
#
############################################################################
#

=item getRows ($content, $headers)

Parse $content and return the rows from the table specified by $headers.
Returns reference to list of rows or B<undef> on error.

=cut
#
############################################################################
#       
sub getRows
{       
        my $self = shift;
	my($content, $headers) = @_;

	my $te = HTML::TableExtract->new(
		'headers' => $headers,
		'keep_html' => 1,
	);
	$te->parse($content);
	my $tbl = $te->first_table_found;
	$tbl or return(undef);
	return($tbl->rows);
}       
#
############################################################################
#

=item url ($set_name, $format)

Return the Gatherer URL for selecting set $set_name with output style $format.
$format defaults to "checklist".

Sample URL:
	http://gatherer.wizards.com/Pages/Search/Default.aspx?output=checklist&set=%5b%22Vintage+Masters%22%5d

=cut
#
############################################################################
#       
sub url
{       
        my $self = shift;
	my($set_name, $format) = @_;

	$format = 'checklist' if !$format;
	return(join('',
		$self->url_base, '?',
		'output=', $format, '&',
		'set=["', $set_name, '"]'));
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

=item url_base ()

Get or set the base URL associated with Gatherer.

=cut
#
############################################################################
#       
sub url_base
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
