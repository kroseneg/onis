package Onis::Users;

use strict;
use warnings;
use Exporter;
use Onis::Config qw#get_config#;
use Onis::Data::Core qw(nick_to_ident);
use Onis::Data::Persistent;

@Onis::Users::EXPORT_OK = qw#host_to_username nick_to_username get_link get_image get_realname#;
@Onis::Users::ISA = ('Exporter');

=head1 NAME

Onis::Users - Management of configures users, so called "names".

=head1 DESCRIPTION

Parses user-info and provides query-routines. The definition of "name" can be found in L<Onis::Data::Core>.

=head1 USAGE

    use Onis::Users qw#ident_to_name chatter_to_name nick_to_name get_realname get_link get_image#;

    # Functions to query the name
    $name = ident_to_name ($ident);
    $name = chatter_to_name ($chatter);
    $name = nick_to_name ($nick);

    # Functions to query a name's properties
    my $realname  = get_realname ($name);
    my $link      = get_link     ($name);
    my $image     = get_image    ($name);

=head1 DIAGNOSTIGS

Set $::DEBUG to ``0x1000'' to get extra debug messages.

=cut

our $Users = {};
# FIXME
our $HostmaskCache = init ('$HostmaskCache', 'hash');

my $VERSION = '$Id: Users.pm,v 1.2 2004/08/01 13:45:27 octo Exp $';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

read_config ();

return (1);

sub read_config
{
	my $config_file = 'users.conf';
	my $content;
	my $fh;
	
	if (get_config ('users_config'))
	{
		my $temp = get_config ('users_config');
		if (-e $temp and -r $temp)
		{
			$config_file = $temp;
		}
		elsif (-e $temp)
		{
			print STDERR $/, __FILE__, ": Unable to read users_config ``$temp'': ",
				"File not readable. Check your permissions.";
		}
		else
		{
			print STDERR $/, __FILE__, ": Unable to read users_config ``$temp'': ",
				"File does not exist.";
		}
	}

	# Fail silently, if fle does not exist..
	if (!-e $config_file) { return (0); }

	print STDERR $/, __FILE__, ": Reading config file ``$config_file''" if ($::DEBUG & 0x1000);

	# read the file
	unless (open ($fh, "< $config_file"))
	{
		print STDERR $/, __FILE__, ": Unable to open ``$config_file'' for reading: $!";
		return (0);
	}

	{
		local ($/) = undef;
		$content = <$fh>;
	}

	close ($fh);

	# parse the file
	#$content =~ s/[\n\r\s]+//gs;
	$content =~ s/#.*$//gm;
	$content =~ s/[\n\r]+//gs;
	
	#while ($content =~ m/([^{]+){([^}]+)}/g)
	while ($content =~ m/([^\s{]+)\s*{([^}]+)}/g)
	{
		my $user = $1;
		my $line = $2;

		print STDERR $/, __FILE__, ": User ``$user''" if ($::DEBUG & 0x1000);

		while ($line =~ m/([^\s:]+)\s*:([^;]+);/g)
		{
			my $key = lc ($1);
			my $val = $2;
			$val =~ s/^\s+|\s+$//g;

			print STDERR $/, __FILE__, ": + $key = ``$val''" if ($::DEBUG & 0x1000);

			if (($key eq 'image') or ($key eq 'link')
					or ($key eq 'name'))
			{
				if (!defined ($Users->{$user}{$key}))
				{
					$Users->{$user}{$key} = [];
				}
				push (@{$Users->{$user}{$key}}, $val);
			}
			elsif (($key eq 'host') or ($key eq 'hostmask'))
			{
				my $this_nick;
				my $this_user;
				my $this_host;

				if ($val =~ m/^([^!]+)!([^@]+)@(.+)$/)
				{
					$this_nick = quotemeta (lc ($1));
					$this_user = quotemeta (lc ($2));
					$this_host = quotemeta (lc ($3));
				}
				else
				{
					print STDERR $/, __FILE__, ": Invalid hostmask for user $user: ``$val''";
					next;
				}

				$this_nick =~ s/\\\*/[^!]*/g;
				$this_nick =~ s/\\\?/[^!]/g;

				$this_user =~ s/\\\*/[^@]*/g;
				$this_user =~ s/\\\?/[^@]/g;

				$this_host =~ s/\\\*/.*/g;
				$this_host =~ s/\\\?/./g;

				$val = "$this_nick!$this_user\@$this_host";

				if (!defined ($Users->{$user}{'host'}))
				{
					$Users->{$user}{'host'} = [];
				}

				print STDERR " --> m/^$val\$/i" if ($::DEBUG & 0x1000);
				
				push (@{$Users->{$user}{'host'}}, qr/^$val$/i);
			}
			else
			{
				print STDERR $/, __FILE__, ": Invalid key in users_config: ``$key''";
			}
		}

		if (!defined ($Users->{$user}{'host'}))
		{
			print STDERR $/, __FILE__, ": No hostmask given for user $user. Ignoring him/her.";
			delete ($Users->{$user});
		}
	}

	return (1);
}

=head1 EXPORTED FUNCTIONS

=over 4

=item B<ident_to_name> (I<$ident>)

Matches the ident against the configured hostmasks. Uses caching to
speed up execution. Returns the name or an empty string if not found.

=cut

sub ident_to_name
{
	my $ident = shift;
	my $name = '';

	if (defined ($HostmaskCache->{$ident}))
	{
		$name = $HostmaskCache->{$ident};
	}
	else
	{
		USER: for (keys (%$Users))
		{
			my $this_name = $_;
			for (@{$Users->{$this_name}{'host'}})
			{
				my $host_re = $_;

				if ($ident =~ $host_re)
				{
					$name = $this_name;
					last (USER);
				}
			}
		}

		if (($::DEBUG & 0x1000) and $name)
		{
			print STDERR $/, __FILE__, ": Host ``$ident'' belongs to ``$name''";
		}
	}
	
	$HostmaskCache->{$ident} = $name;
	return ($name);
}

=item B<chatter_to_name> (I<$chatter>)

Passes the ident-part of I<$chatter> to B<ident_to_name>.

=cut

sub chatter_to_name
{
	my $chatter = shift;
	my ($nick, $ident) = split (m/!/, $chatter);

	return (ident_to_name ($ident));
}

=item B<nick_to_name> (I<$nick>)

Return the name associated with I<$nick>. This function uses B<nick_to_ident>
(see L<Onis::Data::Core>) to convert I<$nick> to an ident and then calls
B<ident_to_name>.

=cut

sub nick_to_name
{
	my $nick = shift;
	my $ident = nick_to_ident ($nick);

	if ($ident)
	{
		return (ident_to_name ($ident));
	}
	else
	{
		return ('');
	}
}

=item B<get_realname> (I<$name>)

Returns the B<real name> for this (user)name as defined in the config. Sorry
for the confusing terms.

=cut

sub get_realname
{
	my $name = shift;
	my $retval = '';

	if (defined ($Users->{$name}{'name'}))
	{
		my $tmp = int (rand (scalar (@{$Users->{$name}{'name'}})));
		$retval = $Users->{$name}{'name'}[$tmp];
	}

	return ($retval);
}

=item B<get_link> (I<$name>)

Returns the URL defined for this name in the config.

=cut

sub get_link
{
	my $name = shift;
	my $retval = '';

	if (defined ($Users->{$name}{'link'}))
	{
		my $tmp = int (rand (scalar (@{$Users->{$name}{'link'}})));
		$retval = $Users->{$name}{'link'}[$tmp];
	}

	return ($retval);
}

=item B<get_image> (I<$name>)

Returns the URL of the (user)name's image, if one is configured.

=cut

sub get_image
{
	my $name = shift;
	my $retval = '';

	if (defined ($Users->{$name}{'image'}))
	{
		my $tmp = int (rand (scalar (@{$Users->{$name}{'image'}})));
		$retval = $Users->{$name}{'image'}[$tmp];
	}

	return ($retval);
}

=back

=head1 AUTHOR

Florian octo Forster E<lt>octo at verplant.orgE<gt>
