package Onis::Data::Persistent::None;

use strict;
use warnings;
use vars (qw($TREE));

use Carp qw(carp confess);
use Exporter;

=head1 NAME

Onis::Data::Persistent::None - Storage backend without storage.. ;)

=head1 DESCRIPTION

Simple storage backend that handles data in-memory only..

=head1 CONFIGURATION OPTIONS

None.

=cut

@Onis::Data::Persistent::None::EXPORT_OK = (qw($TREE));
@Onis::Data::Persistent::None::ISA = ('Exporter');

if ($::DEBUG & 0x0200)
{
	require Data::Dumper;
}

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
	
	if (!exists ($TREE->{$id}))
	{
		$TREE->{$id} = {};
	}

	$obj->{'data'} = $TREE->{$id};
	$obj->{'key'} = $key;
	$obj->{'fields'} = [@fields];
	$obj->{'num_fields'} = scalar (@fields);
	$obj->{'field_index'} = {map { $_ => $i++ } (@fields)};
	$obj->{'id'} = $id;

	if ($::DEBUG & 0x0200)
	{
		my $prefix = __FILE__ . ': ';
		my $dbg = Data::Dumper->Dump ([$obj], ['obj']);
		$dbg =~ s/^/$prefix/mg; chomp ($dbg);
		print STDOUT $/, $dbg;
	}
	
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
		carp ("Number of fields do not match ($id).");
		return;
	}

	if ($::DEBUG & 0x0200)
	{
		print STDOUT $/, __FILE__, ': PUT(', $obj->{'id'}, ', ', $key, ') = (' . join (', ', @fields) . ')';
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

	if ($::DEBUG & 0x0200)
	{
		print STDOUT $/, __FILE__, ': GET(', $obj->{'id'}, ', ', $key, ') = (' . join (', ', @{$obj->{'data'}{$key}}) . ')';
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

	return (sort
	sub {
		for (@field_indizes)
		{
			my $d = $obj->{'data'}{$a}[$_] cmp $obj->{'data'}{$b}[$_];
			return ($d) if ($d);
		}
	}, @keys);
}

sub del
{
	my $obj = shift;
	my $key = shift;

	if (defined ($obj->{'data'}{$key}))
	{
		delete ($obj->{'data'}{$key});
	}
}

=head1 AUTHOR

Florian octo Forster, L<octo@verplant.org>

=cut

exit (0);
