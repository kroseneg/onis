package Onis::Plugins::Interestingnumbers;

use strict;
use warnings;

use Onis::Config (qw(get_config));
use Onis::Html (qw(html_escape get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(register_plugin));
use Onis::Data::Persistent;
use Onis::Users (qw(nick_to_name));

register_plugin ('ACTION', \&add_action);
register_plugin ('JOIN', \&add_join);
register_plugin ('KICK', \&add_kick);
register_plugin ('MODE', \&add_mode);
register_plugin ('TEXT', \&add_text);
register_plugin ('OUTPUT', \&output);

our $InterestingNumbersCache = Onis::Data::Persistent->new ('InterestingNumbersCache', 'nick', qw(actions joins kicks_given kicks_received ops_given ops_taken soliloquies));
our $InterestingNumbersData = {};

our $SoliloquiesNick = '';
our $SoliloquiesCount = 0;

our $SOLILOQUIES_COUNT = 5;
if (get_config ('soliloquies_count'))
{
	my $tmp = get_config ('soliloquies_count');
	$tmp =~ s/\D//g;

	$SOLILOQUIES_COUNT = $tmp if ($tmp);
}
		
my $VERSION = '$Id$';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

sub get_or_empty
{
	my $nick = shift;
	my @data = $InterestingNumbersCache->get ($nick);
	@data = (0, 0, 0, 0, 0, 0) unless (@data);
	return (@data);
}

sub add_action
{
	my $data = shift;
	my $nick = $data->{'nick'};

	my @data = get_or_empty ($nick);
	$data[0]++;
	$InterestingNumbersCache->put ($nick, @data);
}

sub add_join
{
	my $data = shift;
	my $nick = $data->{'nick'};

	my @data = get_or_empty ($nick);
	$data[1]++;
	$InterestingNumbersCache->put ($nick, @data);
}

sub add_kick
{
	my $data = shift;

	my $nick_g = $data->{'nick'};
	my $nick_r = $data->{'nick_received'};

	my @data = get_or_empty ($nick_g);
	$data[2]++;
	$InterestingNumbersCache->put ($nick_g, @data);

	@data = get_or_empty ($nick_r);
	$data[3]++;
	$InterestingNumbersCache->put ($nick_r, @data);
}

sub add_mode
{
	my $data = shift;

	my $nick = $data->{'nick'};
	my $text = $data->{'mode'};
	
	my ($mode) = split (m/\s+/, $text);
	my $modifier = '';

	for (split (m//, $mode))
	{
		my $tmp = $_;
		if (($tmp eq '-') or ($tmp eq '+'))
		{
			$modifier = $tmp;
			next;
		}

		next unless ($modifier);
		
		if ($tmp eq 'o')
		{
			my @data = get_or_empty ($nick);
			if ($modifier eq '-')
			{
				$data[5]++;
			}
			else # ($modifier eq '+')
			{
				$data[4]++;
			}
		}
	}

	return (1);
}

sub add_text
{
	my $data = shift;

	my $nick = $data->{'nick'};

	if ($nick eq $SoliloquiesNick)
	{
		$SoliloquiesCount++;

		if ($SoliloquiesCount == $SOLILOQUIES_COUNT)
		{
			my @data = get_or_empty ($nick);
			$data[6]++;
			$InterestingNumbersCache->put ($nick, @data);
		}
	}
	else
	{
		$SoliloquiesNick = $nick;
		$SoliloquiesCount = 1;
	}
}

sub calculate
{
	for ($InterestingNumbersCache->keys ())
	{
		my $nick = $_;
		my ($actions, $joins,
			$kicks_given, $kicks_received,
			$ops_given, $ops_taken,
			$soliloquies) = $InterestingNumbersCache->get ($nick);
		my $main = get_main_nick ($nick);

		die unless ($main);

		if (!defined ($InterestingNumbersData->{$main}))
		{
			$InterestingNumbersData->{$main} =
			{
				actions		=> 0,
				joins		=> 0,
				kicks_given	=> 0,
				kicks_received	=> 0,
				ops_given	=> 0,
				ops_taken	=> 0,
				soliloquies	=> 0
			};
		}

		$InterestingNumbersData->{$main}{'actions'}        += $actions;
		$InterestingNumbersData->{$main}{'joins'}          += $joins;
		$InterestingNumbersData->{$main}{'kicks_given'}    += $kicks_given;
		$InterestingNumbersData->{$main}{'kicks_received'} += $kicks_received;
		$InterestingNumbersData->{$main}{'ops_given'}      += $ops_given;
		$InterestingNumbersData->{$main}{'ops_taken'}      += $ops_taken;
		$InterestingNumbersData->{$main}{'soliloquies'}    += $soliloquies;
	}
}




sub output
{
	calculate ();
	
	my $first_nick;
	my $first_name;
	my $second_nick;
	my $second_name;

	my $fh = get_filehandle ();

	my $trans = translate ('Interesting Numbers');
	
	print $fh <<EOF;
<table class="plugin interestingnumbers">
  <tr>
    <th>$trans</th>
  </tr>
EOF
	($first_nick, $second_nick) = sort_by_field ('kick_received');
	if ($first_nick)
	{
		my $num = $InterestingNumbersData->{$first_nick}{'kick_received'};
		$trans = translate ('kick_received0: %s %u');
		$first_name = nick_to_name ($first_nick) || $first_nick;

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first_nick, $num);
		
		if ($second_nick)
		{
			$num = $InterestingNumbersData->{$second_nick}{'kick_received'};
			$trans = translate ('kick_received1: %s %u');
			$second_name = nick_to_name ($second_nick) || $second_nick;

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second_nick, $num);
			print $fh '</span>';
		}
		
		print $fh "</td>\n  </tr>\n";
	}

	($first_nick, $second_nick) = sort_by_field ('kick_given');
	if ($first_nick)
	{
		my $num = $InterestingNumbersData->{$first_nick}{'kick_given'};
		$trans = translate ('kick_given0: %s %u');
		$first_name = nick_to_name ($first_nick) || $first_nick;

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first_name, $num);

		if ($second_nick)
		{
			$num = $InterestingNumbersData->{$second_nick}{'kick_given'};
			$trans = translate ('kick_given1: %s %u');
			$second_name = nick_to_name ($second_nick) || $second_nick;

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second_name, $num);
			print $fh '</span>';
		}

		print $fh "</td>\n  </tr>\n";
	}

	($first_nick, $second_nick) = sort_by_field ('op_given');
	if ($first_nick)
	{
		my $num = $InterestingNumbersData->{$first_nick}{'op_given'};
		$trans = translate ('op_given0: %s %u');
		$first_name = nick_to_name ($first_nick) || $first_nick;

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first_name, $num);
		
		if ($second_nick)
		{
			$num = $InterestingNumbersData->{$second_nick}{'op_given'};
			$trans = translate ('op_given1: %s %u');
			$second_name = nick_to_name ($second_nick) || $second_nick;

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second_name, $num);
			print $fh '</span>';
		}
		
		print $fh "</td>\n  </tr>\n";
	}

	($first_nick, $second_nick) = sort_by_field ('op_taken');
	if ($first_nick)
	{
		my $num = $InterestingNumbersData->{$first_nick}{'op_taken'};
		$trans = translate ('op_taken0: %s %u');
		$first_name = nick_to_name ($first_nick) || $first_nick;

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first_name, $num);
		
		if ($second_nick)
		{
			$num = $InterestingNumbersData->{$second_nick}{'op_taken'};
			$trans = translate ('op_taken1: %s %u');
			$second_name = nick_to_name ($second_nick) || $second_nick;

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second_name, $num);
			print $fh '</span>';
		}
		
		print $fh "</td>\n  </tr>\n";
	}

	($first_nick, $second_nick) = sort_by_field ('actions');
	if ($first_nick)
	{
		my $num = $InterestingNumbersData->{$first_nick}{'actions'};
		$trans = translate ('action0: %s %u');
		$first_name = nick_to_name ($first_nick) || $first_nick;

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first_name, $num);
		
		if ($second_nick)
		{
			$num = $InterestingNumbersData->{$second_nick}{'actions'};
			$trans = translate ('action1: %s %u');
			$second_name = nick_to_name ($second_nick) || $second_nick;

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second_name, $num);
			print $fh '</span>';
		}

		print $fh "</td>\n  </tr>\n";
	}
	
	($first_nick, $second_nick) = sort_by_field ('soliloquies');
	if ($first_nick)
	{
		my $num = $InterestingNumbersData->{$first_nick}{'soliloquies'};
		$trans = translate ('soliloquies0: %s %u');
		$first_name = nick_to_name ($first_nick) || $first_nick;

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first_name, $num);
		
		if ($second_nick)
		{
			$num = $InterestingNumbersData->{$second_nick}{'soliloquies'};
			$trans = translate ('soliloquies1: %s %u');
			$second_name = nick_to_name ($second_nick) || $second_nick;

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second_name, $num);
			print $fh '</span>';
		}

		print $fh "</td>\n  </tr>\n";
	}
	
	($first_nick, $second_nick) = sort_by_field ('joins');
	if ($first_nick)
	{
		my $num = $InterestingNumbersData->{$first_nick}{'joins'};
		$trans = translate ('joins0: %s %u');
		$first_name = nick_to_name ($first_nick) || $first_nick;

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first_name, $num);
		
		if ($second_nick)
		{
			$num = $InterestingNumbersData->{$second_nick}{'joins'};
			$trans = translate ('joins1: %s %u');
			$second_name = nick_to_name ($second_nick) || $second_nick;

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second_name, $num);
			print $fh '</span>';
		}

		print $fh "</td>\n  </tr>\n";
	}

	print $fh "</table>\n\n";
}

sub sort_by_field
{
	my $field = shift;
	
	my @retval = sort
	{
		$InterestingNumbersData->{$b}{$field}
		<=>
		$InterestingNumbersData->{$a}{$field}
	} (keys (%$InterestingNumbersData));

	while (scalar (@retval) < 2)
	{
		push (@retval, '');
	}
	
	return (@retval);
}
