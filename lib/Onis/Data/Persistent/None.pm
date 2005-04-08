package Onis::Data::Persistent::None;

use strict;
use warnings;

use vars (qw($TREE));

use Carp qw(confess);

=head1 NAME

Onis::Data::Persistent::None - Storage backend without storage.. ;)

=head1 DESCRIPTION

Simple storage backend that handles data in-memory only..

=head1 CONFIGURATION OPTIONS

None.

=cut

$TREE = {};

return (1);

sub new
{
	my $pkg    = shift;
	my $name   = shift;
	my $key    = shift;
	my @fields = @_;
	my $caller = caller ();
	my $obj    = {};
	my $i = 0;
	
	my $id = $caller . ':' . $name;
	
	if (exists ($TREE->{$id}))
	{
		print STDERR $/, __FILE__, ": Name $name has been used in context $caller before.";
		return (undef);
	}

	$TREE->{$id} = {};
	$obj->{'data'} = $TREE->{$id};

	$obj->{'key'} = $key;
	$obj->{'fields'} = [@fields];
	$obj->{'num_fields'} = scalar (@fields);
	$obj->{'field_index'} = {map { $_ => $i++ } (@fields)};
	$obj->{'id'} = $id;
	
	return (bless ($obj, $pkg));
}

sub put
{
	my $obj    = shift;
	my $key    = shift;
	my @fields = @_;

	if ($obj->{'num_fields'} != scalar (@fields))
	{
		my $id = $obj->{'id'};
		print STDERR $/, __FILE__, ": Number of fields do not match ($id).";
		return;
	}

	$obj->{'data'}{$key} = [@fields];
}

sub get
{
	my $obj = shift;
	my $key = shift;

	if (!defined ($obj->{'data'}{$key}))
	{
		return (qw());
	}

	return (@{$obj->{'data'}{$key}});
}

sub keys
{
	my $obj = shift;
	my @fields = @_;
	my @field_indizes = ();
	my @keys = keys %{$obj->{'data'}};

	if (!@fields)
	{
		return (@keys);
	}

	for (@fields)
	{
		my $field = $_;
		if (!defined ($obj->{'field_index'}{$field}))
		{
			my $id = $obj->{'id'};
			print STDERR $/, __FILE__, ": $field is not a valid field ($id).";
		}
		push (@field_indizes, $obj->{'field_index'}{$field});
	}

	return (sort (sub
	{
		for (@field_indizes)
		{
			my $d = $obj->{'data'}{$a}[$_] cmp $obj->{'data'}{$b}[$_];
			return ($d) if ($d);
		}
	}, @keys));
}

=head1 AUTHOR

Florian octo Forster, L<octo@verplant.org>

=cut

exit (0);
