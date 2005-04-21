package Onis::Data::Persistent::Dbm;

use strict;
use warnings;

BEGIN
{
	@AnyDBM_File::ISA = (qw(DB_File GDBM_File SDBM_File NDBM_File ODBM_File));
}

use Carp qw(carp confess);
use Fcntl (qw(O_RDWR O_CREAT));
use AnyDBM_File;

use Onis::Config (qw(get_config));

=head1 NAME

Onis::Data::Persistent::Dbm - Storage backend using AnyDBM_File.

=head1 DESCRIPTION

Storage backend that uses DBM files for storing data permanently.

=head1 CONFIGURATION OPTIONS

=over 4

=item B<dbm_directory>: I<E<lt>dirE<gt>>

Directory in which the DBM-files are kept. Defaults to the B<var>-directory in
onis' main directory.. 

=back

=cut

our $DBMDirectory = 'var';
if (get_config ('storage_dir'))
{
	$DBMDirectory = get_config ('storage_dir');
}
elsif ($ENV{'HOME'})
{
	$DBMDirectory = $ENV{'HOME'} . '/.onis/data';
}
$DBMDirectory =~ s#/+$##g;

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

	$filename = "$DBMDirectory/$id.dbm";
	
	if (exists ($Objects{$id}))
	{
		print STDERR $/, __FILE__, ": Name $name has been used in context $caller before.";
		return (undef);
	}

	no strict (qw(subs));
	tie (%hash, 'AnyDBM_File', $filename, O_RDWR | O_CREAT, 0666) or die ("tie: $!");

	$obj->{'data'} = tied %hash;
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
	
	$Objects{$id} = bless ($obj, $pkg);
	return ($Objects{$id});
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
		$val = $db->FETCH ($key);
		if (!defined ($val))
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

	no strict (qw(subs));
	for (($key, $val) = $db->FIRSTKEY (); defined ($key) and defined ($val); ($key, $val) = $db->NEXTKEY ($key))
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
	{
		for (@field_indizes)
		{
			my $d = $obj->{'cache'}{$a}[$_] cmp $obj->{'cache'}{$b}[$_];
			return ($d) if ($d);
		}
	} (keys %{$obj->{'cache'}}));
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
			$db->DELETE ($key);
			$obj->{'cache'}{$key} = undef;
		}
		# It's known that the key doesn't exist..
	}
	else
	{
		$db->DELETE ($key);
		$obj->{'cache'}{$key} = undef;
	}
}

sub sync
{
	my $obj = shift;
	my $db = $obj->{'data'};

	for (CORE::keys %{$obj->{'cache'}})
	{
		my $key = $_;
		next unless (defined ($obj->{'cache'}{$key}));

		my $val = join ($Alarm, @{$obj->{'cache'}{$key}});

		$db->STORE ($key, $val);
		delete ($obj->{'cache'}{$key});
	}

	$db->sync ();
}

END
{
	for (CORE::keys (%Objects))
	{
		my $key = $_;
		my $obj = $Objects{$key};
		$obj->sync ();
	}
}

=head1 AUTHOR

Florian octo Forster, L<octo at verplant.org>

=cut
