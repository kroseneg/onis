package Onis::Parser;

use strict;
use warnings;

use Exporter;
use Onis::Config qw#get_config#;
use Onis::Data::Core qw#nick_rename store#;
use Onis::Parser::Persistent qw/set_absolute_time get_absolute_time add_relative_time get_state %MONTHNAMES @MONTHNUMS/;

@Onis::Parser::EXPORT_OK = qw/parse last_date/;
@Onis::Parser::ISA = ('Exporter');

our $WORD_LENGTH = 5;

if (get_config ('min_word_length'))
{
	my $tmp = get_config ('min_word_length');
	$tmp =~ s/\D//g;
	$WORD_LENGTH = $tmp if ($tmp);
}

my $VERSION = '$Id: Irssi.pm,v 1.4 2003/12/16 09:22:28 octo Exp $';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

# Return values:
# 0 == rewind file
# 1 == line parsed
# 2 == unable to parse
# 3 == line old
# 4 == don't have date
sub parse
{
	my $line = shift;
	my $state;

	if ($line =~ m/^(\d\d):(\d\d) /)
	{
		add_relative_time ($1, $2);
	}
	elsif ($line =~ m/^--- /)
	{
		if ($line =~ m/(\w\w\w) (\d\d) (\d\d):(\d\d):(\d\d) (\d{4})/)
		{
			if (!defined ($MONTHNAMES{$1})) { return (4); }
			set_absolute_time ($6, $MONTHNAMES{$1}, $2, $3, $4, $5);
		}
	}

	$state = get_state ();
	if ($state != 1)
	{
		return ($state);
	}

	# 12:45 < impy> aufstand im forum..wurde niedergeschlagen
	# 12:47 <@octo> mahlzeit :)
	if ($line =~ m/^(\d\d):(\d\d) <(.)([^>]+)> (.+)/)
	{
		my $data =
		{
			hour	=> $1,
			minute	=> $2,
			nick	=> $4,
			text	=> $5,
			type	=> 'TEXT'
		};
		
		my @words = grep { length ($_) >= $WORD_LENGTH } (split (m/\W+/, $5));
		$data->{'words'} = \@words;
		
		store ($data);
	}

	# 12:48 * octo kommt grad vom einschreiben zurueck :)
	# 00:20 * octo bricht grad voll ab vor lachen..
	elsif ($line =~ m/^(\d\d):(\d\d) (\* (\S+) .+)$/)
	{
		my $data =
		{
			hour	=> $1,
			minute	=> $2,
			nick	=> $4,
			text	=> $3,
			type	=> 'ACTION'
		};
		
		my @words = grep { length ($_) >= $WORD_LENGTH } (split (m/\W+/, $3));
		$data->{'words'} = \@words;
		
		store ($data);
	}

	# 07:03 *** |Kodachi| [~kodachi@pD9505323.dip.t-dialin.net] has joined #schlegl
	# 14:08 *** t_sunrise [t_sunrise@pD9E53413.dip.t-dialin.net] has joined #schlegl
	elsif ($line =~ m/^(\d\d):(\d\d) \*\*\* (\S+) \[([^\]]+)\] has joined ([#!+&]\S+)/)
	{
		my $data =
		{
			hour	=> $1,
			minute	=> $2,
			nick	=> $3,
			host	=> $4,
			channel	=> $5,
			type	=> 'JOIN'
		};
		store ($data);
	}

	# 15:52 *** mode/#schlegl [+o martin-] by Sajdan
	# 11:25 *** mode/#schlegl [+ooo Impy_ kyreon Sajdan] by octo
	elsif ($line =~ m/^(\d\d):(\d\d) \*\*\* mode\/([#!+&]\S+) \[([^\]]+)\] by (\S+)/)
	{
		my $data =
		{
			hour	=> $1,
			minute	=> $2,
			channel	=> $3,
			mode	=> $4,
			nick	=> $5,
			type	=> 'MODE'
		};
		store ($data);
	}
	
	# 15:08 *** stoffi- is now known as foobar-
	# 13:48 *** Lucky-17 is now known as Lucky17
	elsif ($line =~ m/^(\d\d):(\d\d) \*\*\* (\S+) is now known as (\S+)/)
	{
		nick_rename ($1, $2);
	}

	# 14:00 *** kyreon changed the topic of #schlegl to: 100 Jahre Ball... kommt alle :)
	# 15:03 *** martin- changed the topic of #schlegl to: http://martin.ipv6.cc/austellung.txt / Hat jmd Interesse?
	elsif ($line =~ m/^(\d\d):(\d\d) \*\*\* (\S+) changed the topic of ([#!+&]\S+) to: (.+)/)
	{
		my $data =
		{
			hour	=> $1,
			minute	=> $2,
			nick	=> $3,
			channel	=> $4,
			text	=> $5,
			type	=> 'TOPIC'
		};
		store ($data);
	}

	# 23:31 *** |Kodachi| [~kodachi@pD9505104.dip.t-dialin.net] has quit [sleepinf]
	# 00:18 *** miracle- [~SandraNeu@pD9E531C9.dip.t-dialin.net] has quit [Ping timeout]
	elsif ($line =~ m/^(\d\d):(\d\d) \*\*\* (\S+) \[([^\]]+)\] has quit \[([^\]]*)\]/)
	{
		my $data =
		{
			hour	=> $1,
			minute	=> $2,
			nick	=> $3,
			host	=> $4,
			text	=> $5,
			type	=> 'QUIT'
		};
		store ($data);
	}

	# 15:08 *** t_sunrise [t_sunrise@p508472D6.dip.t-dialin.net] has left #schlegl [t_sunrise]
	# 12:59 *** impy__ [impy@huhu.franken.de] has left #schlegl [impy__]
	elsif ($line =~ m/^(\d\d):(\d\d) \*\*\* (\S+) \[([^\]]+)\] has left ([#!+&]\S+) \[([^\]]*)\]/)
	{
		my $data =
		{
			hour	=> $1,
			minute	=> $2,
			nick	=> $3,
			host	=> $4,
			channel	=> $5,
			text	=> $6,
			type	=> 'LEAVE'
		};
		store ($data);
	}
	
	# 21:54 *** stoffi- was kicked from #schlegl by martin- [bye]
	# 12:37 *** miracle- was kicked from #schlegl by kyreon [kyreon]
	elsif ($line =~ m/^(\d\d):(\d\d) \*\*\* (\S+) was kicked from ([#!+&]\S+) by (\S+) \[([^\]]+)\]/)
	{
		my $data =
		{
			hour	=> $1,
			minute	=> $2,
			channel	=> $4,
			nick_received	=> $3,
			nick	=> $5,
			text	=> $6,
			type	=> 'KICK'
		};
		store ($data);
	}

	else
	{
		print STDERR $/, __FILE__, ": Not parsed: ``$line''" if ($::DEBUG & 0x20);
		return (2);
	}

	return (1);
}

sub last_date
{
	# $line =~ m/(\w\w\w) (\d\d) (\d\d):(\d\d):(\d\d) (\d{4})/
	my $time = get_absolute_time ();
	my ($sec, $min, $hour, $day, $month_num, $year) = (localtime ($time))[0 .. 5];
	my $month_name = $MONTHNUMS[$month_num];

	$year += 1900;

	my $retval = sprintf ("%s %02u %02u:%02u:%02u %04u\n",
		$month_name, $day, $hour, $min, $sec, $year);

	return ($retval);
}
