package Onis::Data::Core;

=head1 NAME

Onis::Data::Core - User management

=head1 DESCRIPTION

Store data to the internal structure, care about users, nicks and idents and
dispatch to plugins. The core of the data even..

=cut

use strict;
use warnings;

use Exporter;
use Onis::Config qw#get_config#;
use Onis::Users qw#host_to_username nick_to_username#;
use Onis::Data::Persistent qw#init#;

@Onis::Data::Core::EXPORT_OK = qw#all_nicks get_channel
	nick_to_ident
	ident_to_nick ident_to_name
	get_main_nick
	get_total_lines nick_rename print_output
	register_plugin store get_print_name#;
@Onis::Data::Core::ISA = ('Exporter');

our $DATA = init ('$DATA', 'hash');

our $REGISTER = {};
our $OUTPUT   = [];
our @ALLNICKS = ();
our @ALLNAMES = ();
our %NICK_MAP = ();
our %NICK2IDENT = ();
our %IDENT2NICK = ();
our $LASTRUN_DAYS = 0;

our $UNSHARP = 'MEDIUM';
if (get_config ('unsharp'))
{
	my $tmp = get_config ('unsharp');
	$tmp = uc ($tmp);
	$tmp =~ s/\W//g;

	if ($tmp eq 'NONE' or $tmp eq 'LIGHT'
			or $tmp eq 'MEDIUM'
			or $tmp eq 'HARD')
	{
		$UNSHARP = $tmp;
	}
	else
	{
		print STDERR $/, __FILE__, ": ``$tmp'' is not a valid value for config option ``unsharp''.",
		$/, __FILE__, ": Using standard value ``MEDIUM''.";
	}
}

if (!%$DATA)
{
		$DATA->{'idents_of_nick'} = {};
		$DATA->{'channel'} = {};
		$DATA->{'total_lines'} = 0;
}

if (defined ($DATA->{'lastrun'}))
{
	my $last = $DATA->{'lastrun'};
	my $now  = time;

	my $diff = ($now - $last) % 86400;

	if ($diff > 0)
	{
		$DATA->{'lastrun'} = $now;
		$LASTRUN_DAYS = $diff;
	}
}
else
{
	$DATA->{'lastrun'} = time;
}

my $VERSION = '$Id: Core.pm,v 1.14 2004/10/31 15:00:32 octo Exp $';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

=head1 EXPORTED FUNCTIONS

=over 4

=item I<@nicks> = B<all_nicks> ()

Returns an array of all seen nicks.

=cut

sub all_nicks
{
	return (@ALLNICKS);
}

sub calculate_nicks
{
	my @temp = keys (%{$DATA->{'idents_of_nick'}});
	my $nicks_of_ident = {};

	print STDERR $/, __FILE__, ': Looking at ', scalar (@temp), ' nicks.' if ($::DEBUG & 0x100);

	for (@temp)
	{
		my $this_nick = $_;
		my $this_ident = 'unidentified';
		my $this_total = 0;
		my $this_max = 0;
		my $this_ident_is_user = 0;

		my @idents = keys (%{$DATA->{'idents_of_nick'}{$this_nick}});

		for (@idents)
		{
			my $ident = $_;
			my $num = $DATA->{'idents_of_nick'}{$this_nick}{$ident};
			my $newnum;
			my $ident_is_user = 1;
			
			if ($ident =~ m/^[^@]+@.+$/)
			{
				$ident_is_user = 0;
			}
			
			$this_total += $num;

			$newnum = int ($num * (0.9**$LASTRUN_DAYS));
			if (!$newnum)
			{
				print STDERR $/, __FILE__, ": Deleting ident ``$ident'' because it's too old." if ($::DEBUG);
				delete ($DATA->{'idents_of_nick'}{$this_nick}{$ident});
				if (!keys %{$DATA->{'idents_of_nick'}{$this_nick}})
				{
					print STDERR $/, __FILE__, ": Deleting nick ``$this_nick'' because it's too old." if ($::DEBUG);
					delete ($DATA->{'idents_of_nick'}{$this_nick});
				}
			}
			elsif ($ident_is_user)
			{
				if (($num >= $this_max) or !$this_ident_is_user)
				{
					$this_max = $num;
					$this_ident = $ident;
					$this_ident_is_user = 1;
				}
			}
			elsif ($ident !~ m/\@unidentified$/)
			{
				if (($num >= $this_max) and !$this_ident_is_user)
				{
					$this_max = $num;
					$this_ident = $ident;
				}
			}
		}

		print $/, __FILE__, ": max_ident ($this_nick) = $this_ident" if ($::DEBUG & 0x100);

		if ($this_ident ne 'unidentified')
		{
			if (!$this_ident_is_user and nick_to_username ($this_nick))
			{
				print STDERR $/, __FILE__, ": $this_nick!$this_ident -> " if ($::DEBUG & 0x100);

				$this_ident = nick_to_username ($this_nick);
				$this_ident_is_user = 1;

				print STDERR $this_ident if ($::DEBUG & 0x100);
			}
			$nicks_of_ident->{$this_ident}{$this_nick} = $this_total;
		}
		elsif ($::DEBUG & 0x100)
		{
			print STDERR $/, __FILE__, ": Ignoring unidentified nick ``$this_nick''";
		}
	}

	@temp = keys (%$nicks_of_ident);
	
	print STDERR $/, __FILE__, ': Looking at ', scalar (@temp), ' idents.' if ($::DEBUG & 0x100);

	for (@temp)
	{
		my $this_ident = $_;
		my $this_nick = '';
		my $this_max = 0;
		my @other_nicks = ();

		my @nicks = keys (%{$nicks_of_ident->{$this_ident}});

		for (@nicks)
		{
			my $nick = $_;
			my $num = $nicks_of_ident->{$this_ident}{$nick};

			if ($num > $this_max)
			{
				if ($this_nick) { push (@other_nicks, $this_nick); }
				$this_nick = $nick;
				$this_max = $num;
			}
			else
			{
				push (@other_nicks, $nick);
			}
		}

		print STDERR $/, __FILE__, ": max_nick ($this_ident) = $this_nick" if ($::DEBUG & 0x100);

		for (@other_nicks, $this_nick)
		{
			push (@ALLNICKS, $_);
			$NICK_MAP{$_} = $this_nick;
			$NICK2IDENT{$_} = $this_ident;
		}

		$IDENT2NICK{$this_ident} = $this_nick;
	}
}

=item I<$channel> = B<get_channel> ()

Returns the name of the channel we're generating stats for.

=cut

sub get_channel
{
	my $chan;
	if (get_config ('channel'))
	{
		$chan = get_config ('channel');
	}
	elsif (keys (%{$DATA->{'channel'}}))
	{
		($chan) = sort
		{
			$DATA->{'channel'}{$b} <=> $DATA->{'channel'}{$a}
		} (keys (%{$DATA->{'channel'}}));
	}
	else
	{
		$chan = '#unknown';
	}

	# Fix network-safe channel named (RFC 2811)
	if ($chan =~ m/^![A-Z0-9]{5}.+/)
	{
		$chan =~ s/[A-Z0-9]{5}//;
	}

	return ($chan);
}

=item I<$main> = B<get_main_nick> (I<$nick>)

Returns the main nick for I<$nick> or an empty string if the nick is unknown..

=cut

sub get_main_nick
{
	my $nick = shift;
	if (defined ($NICK_MAP{$nick}))
	{
		return ($NICK_MAP{$nick});
	}
	else
	{
		return ('');
	}
}

=item I<$ident> = B<nick_to_ident> (I<$nick>)

Returns the ident for this nick or an empty string if unknown.

=cut

sub nick_to_ident
{
	my $nick = shift;
	if (defined ($NICK2IDENT{$nick}))
	{
		return ($NICK2IDENT{$nick});
	}
	else
	{
		return ('');
	}
}

=item I<$nick> = B<ident_to_nick> (I<$ident>)

Returns the nick for the given ident or an empty string if unknown.

=cut

sub ident_to_nick
{
	my $ident = shift;

	if (!defined ($ident)
			or (lc ($ident) eq 'ignore')
			or (lc ($ident) eq 'unidentified'))
	{
		return ('');
	}
	elsif (defined ($IDENT2NICK{$ident}))
	{
		return ($IDENT2NICK{$ident});
	}
	else
	{
		return ('');
	}
}

=item I<$name> = B<ident_to_name> (I<$ident>)

Returns the printable version of the name for the chatter identified by
I<$ident>. Returns an empty string if the ident is not known.

=cut

sub ident_to_name
{
	my $ident = shift;
	my $nick = ident_to_nick ($ident);
	my $name;
	
	if (!$nick)
	{
		return ('');
	}

	$name = get_print_name ($nick);

	return ($name);
}

=item I<$name> = B<get_print_name> (I<$nick>)

Returns the printable version of the name for the nick I<$nick> or I<$nick> if
unknown.

=cut

sub get_print_name
{
	my $nick = shift;
	my $ident = '';
	my $name = $nick;

	if (defined ($NICK2IDENT{$nick}))
	{
		$ident = $NICK2IDENT{$nick};
	}

	if (($ident !~ m/^[^@]+@.+$/) and $ident)
	{
		$name = $ident;
	}

	return ($name);
}

=item I<$lines> = B<get_total_lines> ()

Returns the total number of lines parsed so far.

=cut

sub get_total_lines
{
	return ($DATA->{'total_lines'});
}

=item B<nick_rename> (I<$old_nick>, I<$new_nick>)

Keeps track of a nick's hostname if the nick changes.

=cut

sub nick_rename
{
	my $old_nick = shift;
	my $new_nick = shift;

	if (defined ($DATA->{'host_cache'}{$old_nick}))
	{
		my $host = $DATA->{'host_cache'}{$old_nick};
		$DATA->{'host_cache'}{$new_nick} = $host;

		if (!defined ($DATA->{'hosts_of_nick'}{$new_nick}{$host}))
		{
			$DATA->{'hosts_of_nick'}{$new_nick}{$host} = 1;
		}
	}

	if (defined ($DATA->{'byident'}{"$old_nick\@unidentified"}))
	{
		# Other data may be overwritten, but I don't care here..
		# This should be a extremely rare case..
		$DATA->{'byident'}{"$new_nick\@unidentified"} = $DATA->{'byident'}{"$old_nick\@unidentified"};
		delete ($DATA->{'byident'}{"$old_nick\@unidentified"});
	}
}

=item B<print_output> ()

Print the output. Should be called only once..

=cut

sub print_output
{
	if (!$DATA->{'total_lines'})
	{
		print STDERR <<'MESSAGE';

ERROR: No data found

The most common reasons for this are:
- The logfile used was empty.
- The ``logtype'' setting did not match the logfile.
- The logfile did not include a date.

MESSAGE
		return;
	}
	
	calculate_nicks ();
	merge_idents ();

	for (@$OUTPUT)
	{
		&$_ ();
	}

	delete ($DATA->{'byname'});
}

=item I<$data> = B<register_plugin> (I<$type>, I<$sub_ref>)

Register a subroutine for the given type. Returns a reference to the internal
data object. This will change soon, don't use it anymore if possible.

=cut

sub register_plugin
{
	my $type = shift;
	my $sub_ref = shift;

	$type = uc ($type);
	if (ref ($sub_ref) ne "CODE")
	{
		print STDERR $/, __FILE__, ": Plugin tried to register a non-code reference. Ignoring it.";
		return (undef);
	}

	if ($type eq 'OUTPUT')
	{
		push (@$OUTPUT, $sub_ref);
	}
	else
	{
		if (!defined ($REGISTER->{$type}))
		{
			$REGISTER->{$type} = [];
		}
	}

	push (@{$REGISTER->{$type}}, $sub_ref);

	print STDERR $/, __FILE__, ': ', scalar (caller ()), " registered for ``$type''." if ($::DEBUG & 0x800);

	return ($DATA);
}

=item B<store> (I<$type>, I<$data>)

Passes I<$data> (a hashref) to all plugins which registered for I<$type>. 

=cut

sub store
{
	my $data = shift;
	my $type = $data->{'type'};
	my $nick;
	my $ident;

	if (!defined ($type))
	{
		print STDERR $/, __FILE__, ": Plugin data did not include a type. This line will be skipped." if ($::DEBUG & 0x20);
		return (undef);
	}

	if (!defined ($data->{'nick'}))
	{
		print STDERR $/, __FILE__, ": Plugin data did not include a nick. This line will be skipped." if ($::DEBUG & 0x20);
		return (undef);
	}

	$nick = $data->{'nick'};

	if (defined ($data->{'host'}))
	{
		my $user = host_to_username ($nick . '!' . $data->{'host'});

		if ($user)
		{
			$data->{'ident'} = $user;
			$NICK2IDENT{$nick} = $user;
		}
		else
		{
			my $host = unsharp ($data->{'host'});
			$data->{'host'} = $host;
			$data->{'ident'} = $host;
			$NICK2IDENT{$nick} = $host;
		}

		if (defined ($DATA->{'byident'}{"$nick\@unidentified"}))
		{
			my $ident = $data->{'ident'};

			print STDERR $/, __FILE__, ": Merging ``$nick\@unidentified'' to ``$ident''" if ($::DEBUG & 0x100);
			
			if (!defined ($DATA->{'byident'}{$ident}))
			{
				$DATA->{'byident'}{$ident} = {};
			}

			add_hash ($DATA->{'byident'}{$ident}, $DATA->{'byident'}{"$nick\@unidentified"});
			delete ($DATA->{'byident'}{"$nick\@unidentified"});
		}
	}
	elsif (defined ($NICK2IDENT{$nick}))
	{
		$data->{'ident'} = $NICK2IDENT{$nick};
	}
	else
	{
		my $user = nick_to_username ($nick);

		if ($user)
		{
			$data->{'ident'} = $user;
			$NICK2IDENT{$nick} = $user;
		}
		else
		{
			$data->{'ident'} = $nick . '@unidentified';
		}
	}

	$ident = $data->{'ident'};

	if ($::DEBUG & 0x0100)
	{
		print STDERR $/, __FILE__, ": id ($nick) = ", $data->{'ident'};
	}

	if (defined ($data->{'channel'}))
	{
		my $chan = lc ($data->{'channel'});
		$DATA->{'channel'}{$chan}++;
	}

	if ($::DEBUG & 0x400)
	{
		my @keys = keys (%$data);
		for (sort (@keys))
		{
			my $key = $_;
			my $val = $data->{$key};
			print STDERR $/, __FILE__, ': ';
			printf STDERR ("%10s: %s", $key, $val);
		}
	}

	if (lc ($ident) eq "ignore")
	{
		print STDERR $/, __FILE__, ': Ignoring line from ignored user.' if ($::DEBUG & 0x0100);
		return (0);
	}
	
	$DATA->{'idents_of_nick'}{$nick}{$ident}++;
	$DATA->{'total_lines'}++;

	if (defined ($REGISTER->{$type}))
	{
		for (@{$REGISTER->{$type}})
		{
			my $sub_ref = $_;
			&$sub_ref ($data);
		}
	}

	return (1);
}

=item B<unsharp> (I<$ident>)

Takes an ident (i.e. a user-host-pair, e.g. I<user@host.domain.com> or
I<login@123.123.123.123>) and "unsharps it". The unsharp version is then
returned.

What unsharp exactly does is described in the F<README>.

=cut

sub unsharp
{
	my $user_host = shift;

	my $user;
	my $host;
	my @parts;
	my $num_parts;
	my $i;
	my $retval;

	print STDERR $/, __FILE__, ": Unsharp ``$user_host''" if ($::DEBUG & 0x100);
	
	($user, $host) = split (m/@/, $user_host, 2);

	@parts = split (m/\./, $host);
	$num_parts = scalar (@parts);
	
	if (($UNSHARP ne 'NONE')
			and ($user =~ m/^[\~\^\-\+\=](.+)$/))
	{
		$user = $1;
	}
	
	if ($UNSHARP eq 'NONE')
	{
		return ($user . '@' . $host);
	}
	elsif ($host =~ m/^[\d\.]{7,15}$/)
	{
		if ($UNSHARP ne 'LIGHT')
		{
			$parts[-1] = '*';
		}
	}
	else
	{
		for ($i = 0; $i < ($num_parts - 2); $i++)
		{
			if ($UNSHARP eq 'LIGHT')
			{
				if ($parts[$i] !~ s/\d+/*/g)
				{
					last;
				}
			}
			elsif ($UNSHARP eq 'MEDIUM')
			{
				if ($parts[$i] =~ m/\d/)
				{
					$parts[$i] = '*';
				}
				else
				{
					last;
				}
			}
			else # ($UNSHARP eq 'HARD')
			{
				$parts[$i] = '*';
			}
		}
	}

	$host = lc (join ('.', @parts));
	$host =~ s/\*(\.\*)+/*/;
	$retval = $user . '@' . $host;
	
	print STDERR " -> ``$retval''" if ($::DEBUG & 0x100);
	return ($retval);
}

=item B<merge_idents> ()

Merges idents. Does magic, don't interfere ;)

=cut

sub merge_idents
{
	my @idents = keys (%IDENT2NICK);

	for (@idents)
	{
		my $ident = $_;
		my $name = ident_to_name ($ident);

		if (!defined ($DATA->{'byident'}{$ident}))
		{
			next;
		}
		
		if (!defined ($DATA->{'byname'}{$name}))
		{
			$DATA->{'byname'}{$name} = {};
		}

		add_hash ($DATA->{'byname'}{$name}, $DATA->{'byident'}{$ident});
	}
}

sub add_hash
{
	my $dst = shift;
	my $src = shift;

	my @keys = keys (%$src);

	for (@keys)
	{
		my $key = $_;
		my $val = $src->{$key};

		if (!defined ($dst->{$key}))
		{
			$dst->{$key} = $val;
		}
		elsif (!ref ($val))
		{
			if ($val =~ m/\D/)
			{
				# FIXME
				print STDERR $/, __FILE__, ": ``$key'' = ``$val''" if ($::DEBUG);
			}
			else
			{
				$dst->{$key} += $val;
			}
		}
		elsif (ref ($val) ne ref ($dst->{$key}))
		{
			print STDERR $/, __FILE__, ": Destination and source type do not match!" if ($::DEBUG);
		}
		elsif (ref ($val) eq "HASH")
		{
			add_hash ($dst->{$key}, $val);
		}
		elsif (ref ($val) eq "ARRAY")
		{
			my $i = 0;
			for (@$val)
			{
				my $j = $_;
				if ($j =~ m/\D/)
				{
					# FIXME
					print STDERR $/, __FILE__, ": ``", $key, '[', $i, "]'' = ``$j''" if ($::DEBUG);
				}
				else
				{
					$dst->{$key}->[$i] += $j;
				}
				$i++;
			}
		}
		else
		{
			my $type = ref ($val);
			print STDERR $/, __FILE__, ": Reference type ``$type'' is not supported!", $/;
		}
	}
}

=back

=head1 AUTHOR

  Florian octo Forster E<lt>octo at verplant.orgE<gt>

=cut
