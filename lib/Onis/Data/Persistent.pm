package Onis::Data::Persistent;

use strict;
use warnings;

use Carp qw(confess);

=head1 NAME

Onis::Data::Persistent - Interface for storage backends

=head1 DESCRIPTION

Abstraction layer for modules that act as a backend and are able to store
internal data for longer than one run..

=cut

use Onis::Config qw#get_config get_checksum#;

our $StoreModule = 'None';

=head1 CONFIGURATION OPTIONS

Since this is a B<interface> the options are very few. One, to be specific. See
your favorite backend's documentation on it's options..

=over 4

=item B<storage_module>

Selects the storage module to use. Defaults to I<None> which is a dummy module
that doesn't do anything with the data.. (Other than storing it internally..)
Currently implemented options are:

    None       (todo)
    Storable   (maybe)
    GDBM/SDBM  (todo)
    MySQL      (todo)
    PostgreSQL (maybe)

=back

=cut

if (get_config ('storage_module'))
{
	$StoreModule = ucfirst (lc (get_config ('storage_module')));
}

{
	my $mod_name = "Onis::Data::Persistent::$StoreModule";

	eval qq(use $mod_name;);

	if ($@)
	{
		print STDERR $/, __FILE__, ": Could not load storage module ``$StoreModule''. Are you sure it exists?";
		exit (1);
	}

	unshift (@Onis::Data::Persistent::ISA, $mod_name);
}

return (0);

=head1 INTERFACE

The child-modules have to provide the following interface:

=over 4

=item B<Onis::Data::Persistent-E<gt>new> (I<$name>, I<$key_name>, I<@field_names>)

This is the constructor for the objects that will hold the data. Some modules
may need a name for each field, and this is where plugins have to give the name
of each field. This is particularly important for backends using relational
databeses. I<$name> is merely a name for that variable or, in the database
world - a table. The name must be unique for each calling method's namespace.

Since this is a constructor it returns an object. The object "knows" the folling methods:

=item B<$data-E<gt>put> (I<$key>, I<@fields>)

Stores the given values in the data structure. How this is done is described
below in L<another paragraph>. Doesn't return anything. The number of entries
in I<@fields> has to match the number of entries in I<@field_names> when
creating the object using B<new>.

=item B<$data-E<gt>get> (I<$key>) 

Returns the data associated with the given I<$key> pair or an empty list if no
data has been stored under this tupel before..

=item B<$data-E<gt>keys> ([I<$field>, ...])

Returns a list of all the keys defined for this object. If one field is given
the list will be sorted by that field's values, if more fields are given the
list is sorted with the first field taking precedence over the others. If no
field is supplied the order is undefined.

=back

=head1 INTERNALS

The B<put> and B<get> methods can be found in the
B<Onis::Data::Persistent::None> module. Other modules are encouraged to inherit
from that module, but don't need to. The data is stored as follows: The object
that's returned to the caller is actually a hash with this layout:

    %object =
    (
        data =>
        {
            key0 => [ qw(field0 field1 field2 ...) ],
            key1 => [ qw(field0 field1 field2 ...) ],
            key2 => [ qw(field0 field1 field2 ...) ],
            ...
	}
    );

The actual data is not directly stored under I<%object> so database backends
can store metadata there (table name, credentials, whatever..).

=head1 FURTHER CONSIDERATIONS

Backend modules will probably read the entire data at startup and save
everything at the end. Another strategy might be reading (at least trying to)
an entry when it's first tried to B<get>..

=head1 AUTHOR

Florian octo Forster, L<octo@verplant.org>. Any comments welcome as long as I
haven't started implementing this ;)

=cut
