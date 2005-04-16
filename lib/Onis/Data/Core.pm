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
use Onis::Config qw(get_config);
use Onis::Users qw(chatter_to_name);
use Onis::Data::Persistent;
use Onis::Parser::Persistent qw(get_absolute_time);

=head1 NAMING CONVENTION

Each and every person in the IRC can be identified by a three-tupel: B<nick>,
B<user> and B<host>, most often seen as I<nick!user@host>.

The combination of B<user> and B<host> is called an B<ident> here and written
I<user@host>. The combination of all three parts is called a B<chatter> here,
though it's rarely used.

A B<name> is the name of the "user" as defined in the F<users.conf>. Therefore,
the F<users.conf> defines a mapping of B<chatter> -E<gt> B<name>.

=cut

our $GeneralCounters  = Onis::Data::Persistent->new ('GeneralCounters', 'key', 'value');
our $NickToIdentCache = Onis::Data::Persistent->new ('NickToIdentCache', 'nick', 'ident');
our $ChatterList  = Onis::Data::Persistent->new ('ChatterList', 'chatter', 'counter');
our $ChannelNames = Onis::Data::Persistent->new ('ChannelNames', 'channel', 'counter');

@Onis::Data::Core::EXPORT_OK =
qw(
	store unsharp calculate_nicks 

	get_all_nicks get_channel get_main_nick
	nick_to_ident ident_to_nick
	nick_to_name ident_to_name
	get_total_lines get_most_recent_time nick_rename print_output register_plugin
);
@Onis::Data::Core::ISA = ('Exporter');

our $LinesThisRun = 0;

our $PluginCallbacks = {};
our $OutputCallbacks = [];
our @AllNicks = ();

our %NickToNick = ();
our %NickToIdent = ();
our %IdentToNick = ();

=head1 CONFIGURATION OPTIONS

=over 4

=item B<unsharp>: I<medium>;

Sets the amount of unsharping onis should do. Valid options are I<none>,
I<light>, I<medium> and I<hard>.

=over 4

=item I<none>

does not do any unsharping.

=item I<light>

Leaves IP-addresses as they are. The deepest subdomains containing numbers have
those numbers removed. So C<dsl-084-056-107-131.arcor-ip.net> becomes
C<dsl-*-*-*-*.arcor-ip.net>.

=item I<medium>

Removes the last byte from IP-adresses. So C<84.56.107.131> becomes
C<84.56.107.*>. Hostnames have the deepest subdomains removed if they contain
numers, so C<dsl-084-056-107-131.arcor-ip.net> becomes C<*.arcor-ip.net> while
C<shell.franken.de> is not modified. This is the default and recommended
behavior.

=item I<hard>

Handles IP-addresses as I<medium>. Hostnames have all subdomains removed, so
C<p5493EC60.dip.t-dialin.net> becomes C<*.t-dialin.net> and C<shell.franken.de>
becomes C<*.franken.de>.

=back

=cut

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

=item B<channel>: I<name>;

Sets the name of the channel. This is mostly automatically figured out, use
this if onis doesn't get it right or you want another name..

=back

=cut

# TODO
# - lastrun

my $VERSION = '$Id$';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

=head1 EXPORTED FUNCTIONS

=over 4

=item B<store> (I<$type>, I<$data>)

Passes I<$data> (a hashref) to all plugins which registered for I<$type>. This
is the actual workhorse when parsing the file since it will be called once for
every line found.

It will fill I<$data> with I<host>, I<user> and I<ident> if these fields are
missing but have been seen for this nick before.

=cut

sub store
{
	my $data = shift;
	my $type = $data->{'type'};
	my ($nick, $user, $host);
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
		my $chatter;
		my $counter;

		($user, $host) = unsharp ($data->{'host'});
		$ident = "$user\@$host";

		$data->{'host'} = $host;
		$data->{'user'} = $user;
		$data->{'ident'} = $ident;
		
		$NickToIdentCache->put ($nick, $ident);

		$chatter = "$nick!$ident";
		($counter) = $ChatterList->get ($chatter);
		$counter ||= 0; $counter++;
		$ChatterList->put ($chatter, $counter);
	}
	elsif (($ident) = $NickToIdentCache->get ($nick))
	{
		my $chatter = "$nick!$ident";
		my $counter;
		($user, $host) = split (m/@/, $ident);

		$data->{'host'} = $host;
		$data->{'user'} = $user;
		$data->{'ident'} = $ident;

		($counter) = $ChatterList->get ($chatter);
		$counter ||= 0; $counter++;
		$ChatterList->put ($chatter, $counter);
	}
	else
	{
		$data->{'host'}  = $host  = '';
		$data->{'user'}  = $user  = '';
		$data->{'ident'} = $ident = '';
	}

	if ($::DEBUG & 0x0100)
	{
		print STDERR $/, __FILE__, ": id ($nick) = ", $ident;
	}

	if (defined ($data->{'channel'}))
	{
		my $chan = lc ($data->{'channel'});
		my ($count) = $ChannelNames->get ($chan);
		$count ||= 0; $count++;
		$ChannelNames->put ($chan, $count);
	}

	if (!defined ($data->{'epoch'}))
	{
		$data->{'epoch'} = get_absolute_time ();
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

	{
		my ($counter) = $GeneralCounters->get ('lines_total');
		$counter ||= 0;
		$counter++;
		$GeneralCounters->put ('lines_total', $counter);

		my ($time) = $GeneralCounters->get ('most_recent_time');
		$time ||= 0;
		$time = $data->{'epoch'} if ($time < $data->{'epoch'});
		$GeneralCounters->put ('most_recent_time', $time);

		$LinesThisRun++;
	}

	if (defined ($PluginCallbacks->{$type}))
	{
		for (@{$PluginCallbacks->{$type}})
		{
			$_->($data);
		}
	}

	return (1);
}

=item (I<$user>, I<$host>) = B<unsharp> (I<$ident>)

Takes an ident (i.e. a user-host-pair, e.g. I<user@host.domain.com> or
I<login@123.123.123.123>) and "unsharps it". The unsharp version is then
returned.

=cut

sub unsharp
{
	my $ident = shift;

	my $user;
	my $host;
	my @parts;
	my $num_parts;
	my $i;

	print STDERR $/, __FILE__, ": Unsharp ``$ident''" if ($::DEBUG & 0x100);
	
	($user, $host) = split (m/@/, $ident, 2);

	@parts = split (m/\./, $host);
	$num_parts = scalar (@parts);
	
	if (($UNSHARP ne 'NONE')
			and ($user =~ m/^[\~\^\-\+\=](.+)$/))
	{
		$user = $1;
	}
	
	if ($UNSHARP eq 'NONE')
	{
		return ($user, $host);
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
	$host =~ s/\*(?:\.\*)+/*/;
	
	print STDERR " -> ``$user\@$host''" if ($::DEBUG & 0x100);
	return ($user, $host);
}

=item B<calculate_nicks> ()

Iterates over all chatters found so far, trying to figure out which belong to
the same person. This function has to be called before any calls to
B<get_all_nicks>, B<get_main_nick>, B<get_print_name> and B<nick_to_ident>.

This is normally the step after having parsed all files and before doing any
output. After this function has been run all the other informative functions
return actually usefull information..

It does the following: First, it iterates over all chatters and splits them up
into nicks and idents. If a (user)name is found for the ident it (the ident) is
replaced with it (the name). 

In the second step we iterate over all nicks that have been found and
determines the most active ident for each nick. After this has been done each
nick is associated with exactly one ident, but B<not> vice versa. 

The final step is to iterate over all idents and determine the most active nick
for each ident. After some thought you will agree that now each ident exists
only once and so does every nick.

=cut

sub calculate_nicks
{
	my $nicks      = {};
	my $idents     = {};
	my $name2nick  = {};
	my $name2ident = {};
	
	for ($ChatterList->keys ())
	{
		my $chatter = $_;
		my ($nick, $ident) = split (m/!/, $chatter);
		my ($counter) = $ChatterList->get ($chatter);

		$nicks->{$nick}{$ident} = 0 unless (defined ($nicks->{$nick}{$ident}));
		$nicks->{$nick}{$ident} += $counter;
	}

	for (keys %$nicks)
	{
		my $this_nick = $_;
		my $this_ident = 'unidentified';
		my $this_name = '';
		my $this_total = 0;
		my $this_max = 0;

		for (keys %{$nicks->{$this_nick}})
		{
			my $ident = $_;
			my $name = chatter_to_name ("$this_nick!$ident");
			my $num = $nicks->{$this_nick}{$ident};
			
			$this_total += $num;

			if ($name)
			{
				if (($num >= $this_max) or !$this_name)
				{
					$this_max = $num;
					$this_ident = $ident;
					$this_name = $name;
				}
			}
			else
			{
				if (($num >= $this_max) and !$this_name)
				{
					$this_max = $num;
					$this_ident = $ident;
				}
			}
		}

		print $/, __FILE__, ": max_ident ($this_nick) = $this_ident" if ($::DEBUG & 0x100);

		if ($this_ident ne 'unidentified')
		{
			if ($this_name)
			{
				$name2nick->{$this_name}{$this_nick} = 0 unless (defined ($name2nick->{$this_name}{$this_nick}));
				$name2nick->{$this_name}{$this_nick} += $this_total;

				$name2ident->{$this_name}{$this_ident} = 0 unless (defined ($name2nick->{$this_name}{$this_ident}));
				$name2ident->{$this_name}{$this_ident} += $this_total;
			}
			else
			{
				$idents->{$this_ident}{$this_nick} = 0 unless (defined ($idents->{$this_ident}{$this_nick}));
				$idents->{$this_ident}{$this_nick} += $this_total;
			}
		}
		elsif ($::DEBUG & 0x100)
		{
			print STDERR $/, __FILE__, ": Ignoring unidentified nick ``$this_nick''";
		}
	}

	for (keys %$idents)
	{
		my $this_ident = $_;
		my $this_nick = '';
		my $this_max = 0;
		my @other_nicks = ();

		my @nicks = keys (%{$idents->{$this_ident}});

		for (@nicks)
		{
			my $nick = $_;
			my $num = $idents->{$this_ident}{$nick};

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
			push (@AllNicks, $_);
			$NickToNick{$_} = $this_nick;
			$NickToIdent{$_} = $this_ident;
		}

		$IdentToNick{$this_ident} = $this_nick;
	}

	for (keys %$name2nick)
	{
		my $name = $_;
		my $max_num = 0;
		my $max_nick = '';
		my $max_ident = '';

		my @other_nicks = ();
		my @other_idents = ();

		for (keys %{$name2nick->{$name}})
		{
			my $nick = $_;
			my $num = $name2nick->{$name}{$nick};

			if ($num > $max_num)
			{
				push (@other_nicks, $max_nick) if ($max_nick);
				$max_nick = $nick;
				$max_num  = $num;
			}
			else
			{
				push (@other_nicks, $nick);
			}
		}

		$max_num = 0;
		for (keys %{$name2ident->{$name}})
		{
			my $ident = $_;
			my $num = $name2ident->{$name}{$ident};

			if ($num > $max_num)
			{
				push (@other_idents, $max_ident) if ($max_ident);
				$max_ident = $ident;
				$max_num  = $num;
			}
			else
			{
				push (@other_idents, $ident);
			}
		}

		for (@other_nicks, $max_nick)
		{
			push (@AllNicks, $_);
			$NickToNick{$_} = $max_nick;
			$NickToIdent{$_} = $max_ident;
		}

		for (@other_idents, $max_ident)
		{
			$IdentToNick{$_} = $max_nick;
		}
	}
}

=item I<@nicks> = B<get_all_nicks> ()

Returns an array of all seen nicks.

=cut

sub get_all_nicks
{
	return (@AllNicks);
}

=item I<$channel> = B<get_channel> ()

Returns the name of the channel we're generating stats for.

=cut

sub get_channel
{
	my $chan = '#unknown';
	if (get_config ('channel'))
	{
		$chan = get_config ('channel');
	}
	else
	{
		my $max = 0;
		for ($ChannelNames->keys ())
		{
			my $c = $_;
			my ($num) = $ChannelNames->get ($c);
			if (defined ($num) and ($num > $max))
			{
				$max = $num;
				$chan = $c;
			}
		}
	}

	# Fix network-safe channel named (RFC 2811)
	if ($chan =~ m/^![A-Z0-9]{5}(.+)/)
	{
		$chan = '!' . $1;
	}

	return ($chan);
}

=item I<$main> = B<get_main_nick> (I<$nick>)

Returns the main nick for I<$nick> or an empty string if the nick is unknown..

=cut

sub get_main_nick
{
	my $nick = shift;
	if (defined ($NickToNick{$nick}))
	{
		return ($NickToNick{$nick});
	}
	else
	{
		return ('');
	}
}

=item I<$ident> = B<nick_to_ident> (I<$nick>)

Returns the ident for this nick or an empty string if unknown. Before
B<calculate_nicks> is run it will use the database to find the most recent
mapping. After B<calculate_nicks> is run the calculated mapping will be used.

=cut

sub nick_to_ident
{
	my $nick = shift;
	my $ident = '';

	if (%NickToIdent)
	{
		if (defined ($NickToIdent{$nick}))
		{
			$ident = $NickToIdent{$nick};
		}
	}
	else
	{
		($ident) = $NickToIdentCache->get ($nick);
		$ident ||= '';
	}

	return ($ident);
}

=item I<$nick> = B<ident_to_nick> (I<$ident>)

Returns the nick for the given ident or an empty string if unknown.

=cut

sub ident_to_nick
{
	my $ident = shift;

	if (defined ($IdentToNick{$ident}))
	{
		return ($IdentToNick{$ident});
	}
	else
	{
		return ('');
	}
}

=item I<$name> = B<nick_to_name> (I<$nick>)

Return the name associated with I<$nick>.

=cut

sub nick_to_name
{
	my $nick = shift;
	my $ident = nick_to_ident ($nick);

	if ($ident)
	{
		return (chatter_to_name ("$nick!$ident"));
	}
	else
	{
		return ('');
	}
}

=item I<$name> = B<ident_to_name> (I<$ident>)

Returns the name associated with I<$ident>.

=cut

sub ident_to_name
{
	my $ident = shift;
	my $nick = ident_to_nick ($ident);

	if ($nick)
	{
		return (chatter_to_name ("$nick!$ident"));
	}
	else
	{
		return ('');
	}
}

=item I<$lines> = B<get_total_lines> ()

Returns the total number of lines parsed so far.

=cut

sub get_total_lines
{
	my ($total) = $GeneralCounters->get ('lines_total');

	return (qw()) unless ($total);
	
	return ($total, $LinesThisRun);
}

=item I<$epoch> = B<get_most_recent_time> ()

Returns the epoch of the most recent line received from the parser.

=cut

sub get_most_recent_time
{
	my ($time) = $GeneralCounters->get ('most_recent_time');
	$time ||= 0;

	return ($time);
}

=item B<nick_rename> (I<$old_nick>, I<$new_nick>)

Keeps track of a nick's hostname if the nick changes.

=cut

sub nick_rename
{
	my $old_nick = shift;
	my $new_nick = shift;
	my $ident;

	($ident) = $NickToIdentCache->get ($old_nick);

	if (defined ($ident) and ($ident))
	{
		$NickToIdentCache->put ($new_nick, $ident);
	}
}

=item B<print_output> ()

Print the output. Should be called only once..

=cut

sub print_output
{
	# FIXME FIXME FIXME
	if (!get_total_lines ())
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

	for (@$OutputCallbacks)
	{
		&$_ ();
	}
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
		push (@$OutputCallbacks, $sub_ref);
	}
	else
	{
		if (!defined ($PluginCallbacks->{$type}))
		{
			$PluginCallbacks->{$type} = [];
		}
	}

	push (@{$PluginCallbacks->{$type}}, $sub_ref);

	print STDERR $/, __FILE__, ': ', scalar (caller ()), " registered for ``$type''." if ($::DEBUG & 0x800);
}

=back

=head1 AUTHOR

Florian octo Forster E<lt>octo at verplant.orgE<gt>

=cut
