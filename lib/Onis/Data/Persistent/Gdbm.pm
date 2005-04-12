package Onis::Data::Persistent::Dbm;

use strict;
use warnings;

use Carp qw(carp confess);
use AnyDBM_File;

use Onis::Config (qw(get_config));

=head1 NAME

Onis::Data::Persistent::Dbm - Storage backend using AnyDBM_File.

=head1 DESCRIPTION

Storage backend that uses DBM files for storing data permanently.

=head1 CONFIGURATION OPTIONS

=over 4

=item B<gdbm_directory>: I<E<lt>dirE<gt>>

Directory in which the GDBM-files are kept.

=back

=cut

our $DBMDirectory = get_config ('gdbm_directory') || 'var';
$DBMDirectory =~ s#/$##g;

if (!$DBMDirectory or !-d $DBMDirectory)
{
	print STDERR <<ERROR;
The directory ``$DBMDirectory'' does not exist or is not useable. Please
create it before running onis.
ERROR
	exit (1);
}

our $Alarm = chr (7);
our %Objects = ();

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
	$id =~ s#/##g;

	$filename = "$GDBMDirectory/$id.gdbm";
	
	if (exists ($Objects{$id}))
	{
		print STDERR $/, __FILE__, ": Name $name has been used in context $caller before.";
		return (undef);
	}

	$Objects{$id} = $obj;

	$obj->{'data'} = tie (%hash, 'AnyDBM_File', $filename, O_CREAT|O_RDWR, 0664);
	$obj->{'key'} = $key;
	$obj->{'fields'} = [@fields];
	$obj->{'num_fields'} = scalar (@fields);
	$obj->{'field_index'} = {map { $_ => $i++ } (@fields)};
	$obj->{'id'} = $id;
	$obj->{'cache'} = {};

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
	my $db = $obj->{'data'};

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

	$obj->{'cache'}{$key} = [@fields];
}

sub get
{
	my $obj = shift;
	my $key = shift;
	my $val;
	my @ret;
	my $db = $obj->{'data'};

	if (!exists ($obj->{'cache'}{$key}))
	{
		if ($db->get ($key, $val))
		{
			$obj->{'cache'}{$key} = undef;
		}
		else
		{
			$obj->{'cache'}{$key} = [split ($Alarm, $val)];
		}
	}

	if (!defined ($obj->{'cache'}{$key}))
	{
		return (qw());
	}
	else
	{
		@ret = @{$obj->{'cache'}{$key}};
	}

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
	my $db = $obj->{'data'};
	my $key;
	my $val;

	for ($db->seq ($key, $val, R_FIRST); $db->seq ($key, $val, R_NEXT) == 0;)
	{
		next if (defined ($obj->{'cache'}{$key}));
		$obj->{'cache'}{$key} = [split ($Alarm, $val)];
	}

	if (!@fields)
	{
		return (keys %{$obj->{'cache'}});
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
			my $d = $obj->{'cache'}{$a}[$_] cmp $obj->{'cache'}{$b}[$_];
			return ($d) if ($d);
		}
	}, @keys);
}

sub del
{
	my $obj = shift;
	my $key = shift;
	my $db = $obj->{'data'};

	if (exists ($obj->{'cache'}{$key}))
	{
		if (defined ($obj->{'cache'}{$key}))
		{
			$db->del ($key);
			$obj->{'cache'}{$key} = undef;
		}
		# It's known that the key doesn't exist..
	}
	else
	{
		$db->del ($key);
		$obj->{'cache'}{$key} = undef;
	}
}

sub sync
{
	my $obj = shift;
	my $db = $obj->{'data'};

	for (keys %{$obj->{'cache'}})
	{
		my $key = $_;
		my $val = join ($Alarm, @{$obj->{'cache'}{$key}});

		$db->put ($key, $val);
		delete ($obj->{'cache'}{$key});
	}

	$db->sync ();
}

END
{
	for (keys (%Objects))
	{
		my $obj = $_;
		$obj->sync ();
	}
}

=head1 AUTHOR

Florian octo Forster, L<octo at verplant.org>

=cut
