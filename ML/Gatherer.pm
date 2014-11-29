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

=item new ($mcs, $db)

Create an instance of a B<ML::Gatherer> object.
$mcs is a Magic Card Static object.
$db is a Magic Library Storage object.

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
		'DB'		=> undef,
		'USER_AGENT'	=> undef,
		'USER_AGENT_NAME'	=> 'Mozilla/5.0 ',
		'VERBOSE'	=> 0,
                'URL'		=> 'http://gatherer.wizards.com/Pages/Search/Default.aspx',
        };      
                
        bless($self, $class);   
	$self->mcs(shift);
	$self->db(shift);
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
	my $db = $self->db;
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
	my $url = $self->url({ 'set' => $setname }, $display);
	print "** fetch(): getting ($display): $url\n" if $self->verbose;
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
	my $url_compact = $self->url({ 'set' => $setname }, $display);
	my $page = 0;
	while (1)	# we quit after 100 pages...
	{
		my $url_page = $url_compact . '&page=' . $page;
		print "** fetch(): getting ($display): $url_page\n" if $self->verbose;
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
				if ($cards{$cname}->{'gid'} and !$db->isSplitCard($cname))
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
	foreach my $name (keys(%cards))
	{
#print "DEBUG: Checking for split card: $name\n";
		my $fullname = $db->isSplitCard($name);
		$fullname or next;
#print "DEBUG: FOUND split card: $fullname for $name\n";
		if (!$cards{$fullname})
		{
			my %tmp = %{ $cards{$name} };	# create new card
			$tmp{'name'} = $fullname;	# change the name
			$cards{$fullname} = \%tmp;	# add to setlist
		}
		delete($cards{$name});
	}
#print "DEBUG: Total cards left ", scalar(keys(%cards)), "\n";
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

=item flipcards ()

To generate Flip card index, search this in Gatherer:
http://gatherer.wizards.com/Pages/Search/Default.aspx?action=advanced&output=standard&text=+[flip]&format=[%22Kamigawa%20Block%22]

Format contains: Kamigawa Block
Text contains: flip
Display: Standard

Look for all names with () in them. Ignore all others.

Fetch the Gatherer data for flip cards.
Returns a hash reference containing the following keys:

	cards	- reference to list of hash references describing cards in set
	retrieved- time/date stamp of when the data was downloaded
	seconds - how many seconds it took to download and parse the data
	set_size- number of cards in set
	source	- source for data, actual Gatherer URL used for download

Below is information for how we use Gatherer.

The B<Standard> format from Gatherer contains the following columns:


=cut
#
############################################################################
#       
sub flipcards
{       
        my($self) = shift;
	my $ua = $self->userAgent;
	my $tstart = time();

	#
	## Download Compact display ########################################
	#
	my %cards;
	my $display = 'standard';
	my $url = $self->url({ 'name' => '+[//]' }, $display);
	my $page = 0;
	while (1)	# we quit after 100 pages...
	{
		my $url_page = $url . '&page=' . $page;
		print "** flipcards(): getting ($display): $url_page\n" if $self->verbose;
		my($res) = $ua->get($url_page);
		if (!$res->is_success)
		{
			print STDERR "ERROR: flipcards(): failed for: $url_page\nStatus line: ",
				$res->status_line, "\n";
			return(undef);
		}
		# I admit that this is a hack and I should be using HTML::Parser
		my @lines = split(m/[\r\n]/, $res->content);
		print "** flipcards(): bytes downloaded: ${\(length($res->content))}, ${\(scalar(@lines))} lines\n" if $self->verbose;
		@lines = grep(m#<a\s[^>]*>.*//.* \(.*\)</a>#, @lines);
		foreach my $line (@lines)
		{
#<a id="ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ctl00_listRepeater_ctl00_cardTitle" onclick="return CardLinkAction(event, this, 'SameWindow');" href="../Card/Details.aspx?multiverseid=369041&amp;part=Alive">Alive // Well (Alive)</a>
			# Extract multiverseid and card name
			if ($line !~ m#.*multiverseid=(\d+)#)
			{
				print STDERR "ERROR: flipcards(): no multiverseid in: $line\n";
				return(undef);
			}
			my $multiverseid = $1;	# can have multiple ID's
			if ($line !~ m#.*<a\s[^>]*>([^/]+)\s//\s([^(]+)\s\(.*\)</a>#)
			{
				print STDERR "ERROR: flipcards(): no multiverseid in: $line\n";
				return(undef);
			}
			my($first, $last) = ($1, $2);
			next if $cards{"$first/$last"};
			my %card =
			(
				'name'	=> "$first/$last",
				'first'	=> $first,
				'last'	=> $last,
			);
			$cards{"$first/$last"} = \%card;
#print STDERR "DEBUG: $first/$last\n";
		}
		#
		## Determine if more pages #################################
		#
		$page++;
		my $str = $res->content;
#print STDERR "DEBUG: checking for page controls page: $page\n";
		last if $str !~ m/.*class="pagingcontrols">(.*)$/s;
		$str = $1;	# there are pages
#print STDERR "DEBUG: there are pages\n";
		# See if there are pages beyond the current one
		last if $str !~ m#/Pages.*?page=$page\&amp;#;
#print STDERR "DEBUG: next page: $page\n";
		if (!$page > 100)
		{
			print STDERR "ERROR: flipcards(): too man pages\n";
			return(undef);
		}
	}
	#
	## Complete data structure #########################################
	#
	my($sec, $min, $hour, $mday, $mon, $year) = (localtime())[0..5];
	my %setinfo =
	(
		'retrieved' =>	sprintf("%04d%02d%02d-%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec),
		'set_name' =>	'Split Cards',
		'set_size' =>	scalar(keys(%cards)),
		'source' =>	$url,
		'cards' =>	[values(%cards)],
		'seconds' =>	time() - $tstart,
	);
	return(\%setinfo);
}       
#
############################################################################
#

=item splitcards ()

Fetch the Gatherer data for split cards.
Returns a hash reference containing the following keys:

	cards	- reference to list of hash references describing cards in set
	retrieved- time/date stamp of when the data was downloaded
	seconds - how many seconds it took to download and parse the data
	set_size- number of cards in set
	source	- source for data, actual Gatherer URL used for download

Below is information for how we use Gatherer.

The B<Standard> format from Gatherer contains the following columns:


=cut
#
############################################################################
#       
sub splitcards
{       
        my($self) = shift;
	my $ua = $self->userAgent;
	my $tstart = time();

	#
	## Download Compact display ########################################
	#
	my %cards;
	my $display = 'standard';
	my $url = $self->url({ 'name' => '+[//]' }, $display);
	my $page = 0;
	while (1)	# we quit after 100 pages...
	{
		my $url_page = $url . '&page=' . $page;
		print "** splitcards(): getting ($display): $url_page\n" if $self->verbose;
		my($res) = $ua->get($url_page);
		if (!$res->is_success)
		{
			print STDERR "ERROR: splitcards(): failed for: $url_page\nStatus line: ",
				$res->status_line, "\n";
			return(undef);
		}
		# I admit that this is a hack and I should be using HTML::Parser
		my @lines = split(m/[\r\n]/, $res->content);
		print "** splitcards(): bytes downloaded: ${\(length($res->content))}, ${\(scalar(@lines))} lines\n" if $self->verbose;
		@lines = grep(m#<a\s[^>]*>.*//.* \(.*\)</a>#, @lines);
		foreach my $line (@lines)
		{
#<a id="ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_ctl00_listRepeater_ctl00_cardTitle" onclick="return CardLinkAction(event, this, 'SameWindow');" href="../Card/Details.aspx?multiverseid=369041&amp;part=Alive">Alive // Well (Alive)</a>
			# Extract multiverseid and card name
			if ($line !~ m#.*multiverseid=(\d+)#)
			{
				print STDERR "ERROR: splitcards(): no multiverseid in: $line\n";
				return(undef);
			}
			my $multiverseid = $1;	# can have multiple ID's
			if ($line !~ m#.*<a\s[^>]*>([^/]+)\s//\s([^(]+)\s\(.*\)</a>#)
			{
				print STDERR "ERROR: splitcards(): no multiverseid in: $line\n";
				return(undef);
			}
			my($first, $last) = ($1, $2);
			next if $cards{"$first/$last"};
			my %card =
			(
				'name'	=> "$first/$last",
				'first'	=> $first,
				'last'	=> $last,
			);
			$cards{"$first/$last"} = \%card;
#print STDERR "DEBUG: $first/$last\n";
		}
		#
		## Determine if more pages #################################
		#
		$page++;
		my $str = $res->content;
#print STDERR "DEBUG: checking for page controls page: $page\n";
		last if $str !~ m/.*class="pagingcontrols">(.*)$/s;
		$str = $1;	# there are pages
#print STDERR "DEBUG: there are pages\n";
		# See if there are pages beyond the current one
		last if $str !~ m#/Pages.*?page=$page\&amp;#;
#print STDERR "DEBUG: next page: $page\n";
		if (!$page > 100)
		{
			print STDERR "ERROR: splitcards(): too man pages\n";
			return(undef);
		}
	}
	#
	## Complete data structure #########################################
	#
	my($sec, $min, $hour, $mday, $mon, $year) = (localtime())[0..5];
	my %setinfo =
	(
		'retrieved' =>	sprintf("%04d%02d%02d-%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec),
		'set_name' =>	'Split Cards',
		'set_size' =>	scalar(keys(%cards)),
		'source' =>	$url,
		'cards' =>	[values(%cards)],
		'seconds' =>	time() - $tstart,
	);
	return(\%setinfo);
}       
#
############################################################################
#

=item url ($config, $format)

Return the Gatherer URL for selecting with output style $format.
$config specifies the configuration of the query. It is a hash reference.
The keys are the names of search attributes. Special handling is performed
for the following search attributes:

	set - value is surrounded by []'s

Sample URL:
	http://gatherer.wizards.com/Pages/Search/Default.aspx?output=checklist&set=%5b%22Vintage+Masters%22%5d

=cut
#
############################################################################
#       
sub url
{       
        my $self = shift;
	my($config, $format) = @_;

	$format = 'checklist' if !$format;
	my @attrs =
	(
		'output=' . $format,
	);
	foreach my $k (keys(%$config))
	{
		if ($k eq 'set')
		{
			push(@attrs, 'set=["' . $config->{$k} . '"]');
			next;
		}
		push(@attrs, $k . '="' . $config->{$k} . '"');
	}
	return(join('', $self->url_base, '?', join('&', @attrs)));
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

=item db ()

Get or set the ML::Storage object.

=cut
#
############################################################################
#       
sub db
{       
        my($self) = shift;
                
	$self->{'DB'} = shift if (@_);
	return($self->{'DB'});
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
