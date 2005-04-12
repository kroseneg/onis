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

=item B<storable_file>: I<E<lt>fileE<gt>>

Sets the file to use for storable.

=back

=cut

our $StorableFile = get_config ('storable_file') || 'var/storable.dat';

if (-f $StorableFile)
{
	$TREE = retrieve ($StorableFile);
}

if ($::DEBUG & 0x0200)
{
	require Data::Dumper;
}

@Onis::Data::Persistent::Storable::ISA = ('Onis::Data::Persistent::None');

return (1);

END
{
	store ($TREE, $StorableFile);
}

=head1 AUTHOR

Florian octo Forster, E<lt>octo at verplant.orgE<gt>

=cut
