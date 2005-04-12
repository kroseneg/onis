package Onis::Data::Persistent::Gdbm;

use strict;
use warnings;

use Carp qw(carp confess);
use GDBM_File;

use Onis::Config (qw(get_config));

=head1 NAME

Onis::Data::Persistent::Gdbm - Storage backend using GDBM_File.

=head1 DESCRIPTION

Storage backend that uses GDBM files for storing data permanently.

=head1 CONFIGURATION OPTIONS

=over 4

=item B<gdbm_directory>: I<E<lt>dirE<gt>>

Directory in which the GDBM-files are kept.

=back

=cut

our $Alarm = chr (7);

our $GDBMDirectory = get_config ('gdbm_directory') || 'var';
$GDBMDirectory =~ s#/$##g;

if (!$GDBMDirectory or !-d $GDBMDirectory)
{
	print STDERR <<ERROR;
The directory ``$GDBMDirectory'' does not exist or is not useable. Please
create it before running onis.
ERROR
	exit (1);
}

our %Tables = ();

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
	my %hash;
	my $i = 0;
	my $filename;
	
	my $id = $caller . ':' . $name;

	$filename = "$GDBMDirectory/$id.gdbm";
	
	if (exists ($Tables{$id}))
	{
		print STDERR $/, __FILE__, ": Name $name has been used in context $caller before.";
		return (undef);
	}

	$Tables{$id} = tie (%hash, 'GDBM_File', $filename, &GDBM_WRCREAT, 0664);

	$obj->{'data'} = $Tables{$id};
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

	$obj->{'data'}{$key} = join ($Alarm, @fields);
}

sub get
{
	my $obj = shift;
	my $key = shift;
	my @ret;

	if (!exists ($obj->{'data'}{$key}))
	{
		return (qw());
	}

	@ret = split ($Alarm, $obj->{'data'}{$key});

	if ($::DEBUG & 0x0200)
	{
		print STDOUT $/, __FILE__, ': GET(', $obj->{'id'}, ', ', $key, ') = (' . join (', ', @ret) . ')';
	}

	return (@ret);
}

sub keys
{
	my $obj = shift;
	my @fields = @_;
	my @field_indizes = ();
	my @keys = keys %{$obj->{'data'}};
	my $data = {};

	if (!@fields)
	{
		return (@keys);
	}

	for (@keys)
	{
		$data->{$_} = [split ($Alarm, $obj->{'data'}{$_})];
	}

	for (@fields)
	{
		my $field = $_;
		if (!defined ($obj->{'field_index'}{$field}))
		{
			my $id = $obj->{'id'};
			print STDERR $/, __FILE__, ": $field is not a valid field ($id).";
			next;
		}
		push (@field_indizes, $obj->{'field_index'}{$field});
	}

	return (sort
	sub {
		for (@field_indizes)
		{
			my $d = $data->{$a}[$_] cmp $data->{$b}[$_];
			return ($d) if ($d);
		}
	}, @keys);
}

sub del
{
	my $obj = shift;
	my $key = shift;

	if (exists ($obj->{'data'}{$key}))
	{
		delete ($obj->{'data'}{$key});
	}
}

END
{
	for (keys (%Tables))
	{
		my $key = $_;
		untie (%{$Tables{$key}});
	}
}

=head1 AUTHOR

Florian octo Forster, L<octo at verplant.org>

=cut
