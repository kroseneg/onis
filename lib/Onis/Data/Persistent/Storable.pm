package Onis::Data::Persistent::Storable;

use strict;
use warnings;

use Carp (qw(carp confess));
use Storable (qw(store retrieve));

use Onis::Config (qw(get_config));
use Onis::Data::Persistent::None (qw($TREE));

=head1 NAME

Onis::Data::Persistent::Storable - Storage backend using storable

=head1 DESCRIPTION

Simple storage backend that handles data in-memory. At the end of each session
the data is read from a storable-dump.

This module is basically a wrapper around L<Onis::Data::Persistent::None> that
gets the data from a file before and action is taken and writes it back to the
file after everything has been done.

=head1 CONFIGURATION OPTIONS

=over 4

=item B<storage_file>: "I<storage.dat>";

Sets the file storable will write it's data to.

=item B<storage_dir>: "I<var/>";

Sets the directory in which B<storage_file> can be found.

=back

=cut

our $StorageFile = get_config ('storage_file') || 'storage.dat';
our $StorageDir  = get_config ('storage_dir')  || 'var';

$StorageDir =~ s#/+$##;

if (!-d $StorageDir)
{
	print STDERR $/, __FILE__, ':', <<ERROR;

``storage_dir'' is set to ``$StorageDir'', but the directory doesn't exist or
isn't a directory. Please fix it..

ERROR
	exit (1);
}

if (-f "$StorageDir/$StorageFile")
{
	$TREE = retrieve ("$StorageDir/$StorageFile");
}

if ($::DEBUG & 0x0200)
{
	require Data::Dumper;
}

@Onis::Data::Persistent::Storable::ISA = ('Onis::Data::Persistent::None');

return (1);

END
{
	store ($TREE, "$StorageDir/$StorageFile");
}

=head1 AUTHOR

Florian octo Forster, E<lt>octo at verplant.orgE<gt>

=cut
