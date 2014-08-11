package ML::Storage;

use strict;
use warnings;

use File::Path qw(make_path);
use File::Basename;
use XML::Simple qw(:strict);

=head1 NAME

ML::Storage - Manage persistent data

=head1 SYNOPSIS

    use ML::Storage;

=head1 DESCRIPTION

This package provides an interface for saving/loading set-related and
other information.

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

=item new ($dir)

Create a new object. $dir is the location for persistent storage.
Current directory is assumed if none is specified. This directory will be
created if it does not already exist.

=cut
#
############################################################################
#
sub new
{
        my($class) = shift;
        my($self) =
        {
		'DIR'	=> '.',
        };      
                
        bless($self, $class);   
	$self->dir(shift) if @_;
        return($self);
}       
#
############################################################################
#       

=item preserve ($path)

If $path already exists, rename it insead of simply removing it. The file
is renamed my prepending B<OLD> to its basename and appending a timestamp.

Returns true on success, false otherwise.

=cut
#
############################################################################
#
sub preserve
{
        my $self = shift;
	my $path = shift;

	return(1) if (! -e $path);
	my($sec, $min, $hour, $mday, $mon, $year) = (localtime())[0..5];
	my $sfx = sprintf("%04d%02d%02d-%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec);
	my($filename, $dir) = fileparse($path);
	my $newpath = "$dir/OLD$filename$sfx";
	if (!rename($path, $newpath))
	{
		print STDERR "ERROR: preserve(): could not rename '$path' to: '$newpath' ($!)\n";
		return(undef);
	}
	return(1);
}
#
############################################################################
#

=back

=head2 Set-related methods

=over 4
#
############################################################################
#       

=item setPath ($code)

Return pathname for set data file with three-letter abbreviation $code.

=cut
#
############################################################################
#
sub setPath
{
        my $self = shift;
	my($code) = @_;

	return($self->dir . "/set_$code.xml");
}
#
############################################################################
#       

=item setLoad ($code)

Load the set with three-letter abbreviation $code.

Returns reference to same data structure as originally passed to setSave().
Returns B<undef> on failure.

=cut
#
############################################################################
#
sub setLoad
{
        my $self = shift;
	my($code) = @_;
	my $path = $self->setPath($code);

	my $xml = eval { XMLin($path,
		'ForceArray' => 1,
		'KeyAttr' => 'name',
	) };
	if ($@)
	{
		print STDERR "ERROR: setLoad(): XML parsing errors: $@\n";
		return(undef);
	}
	return($xml);
}
#
############################################################################
#       

=item setSave ($code, $data)

Save the set with three-letter abbreviation $code.

Returns true on success, false otherwise.

=cut
#
############################################################################
#
sub setSave
{
        my $self = shift;
	my($code, $data) = @_;
	my $path = $self->setPath($code);

	my $xml = XMLout($data,
		'KeyAttr' => 'name',
		'Attrindent' => 1,
	);
	$self->preserve($path) or return(undef);
	if (!open(SET, ">$path"))
	{
		print STDERR "ERROR: setSave(): open: $path ($!)\n";
		return(undef);
	}
	if (!print SET $xml)
	{
		print STDERR "ERROR: setSave(): write error to: $path ($!)\n";
		close(SET);
		return(undef);
	}
	close(SET);
	return(1);
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

=item dir ()

Get or set the path to the file used to store cookies.
Create it if it doesn't exist.

=cut
#
############################################################################
#       
sub dir
{       
        my($self) = shift;
                
	$self->{'DIR'} = shift if (@_);
	make_path($self->{'DIR'}) if (! -d $self->{'DIR'});
	return($self->{'DIR'});
}       
#
############################################################################
#

=back

=head1 AUTHOR

Peter Costantinidis

=cut

1;
