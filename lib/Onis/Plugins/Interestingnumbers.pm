package Onis::Plugins::Interestingnumbers;

use strict;
use warnings;

use Onis::Config (qw(get_config));
use Onis::Html (qw(html_escape get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(nick_to_ident register_plugin));

our $SOLILOQUIES = {};

register_plugin ('ACTION', \&add_action);
register_plugin ('JOIN', \&add_join);
register_plugin ('KICK', \&add_kick);
register_plugin ('MODE', \&add_mode);
register_plugin ('TEXT', \&add_text);
register_plugin ('OUTPUT', \&output);

our $InterestingNumbersCache = ('InterestingNumbersCache', 'nick', qw(actions joins kicks_given kicks_received modes soliloquies));

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

sub add_action
{
	my $data = shift;
	my $nick = $data->{'nick'};

	my $ident = $data->{'ident'};
	
	$DATA->{'byident'}{$ident}{'actions'}++;
	
	return (1);
}

sub add_join
{
	my $data = shift;

	my $ident = $data->{'ident'};
	
	$DATA->{'byident'}{$ident}{'joins'}++;
	
	return (1);
}

sub add_kick
{
	my $data = shift;

	my $ident_give = $data->{'ident'};
	my $ident_rcvt = nick_to_ident ($data->{'nick_received'});

	$DATA->{'byident'}{$ident_give}{'kick_given'}++;

	if ($ident_rcvt)
	{
		$DATA->{'byident'}{$ident_rcvt}{'kick_received'}++;
	}
	
	return (1);
}

sub add_mode
{
	my $data = shift;

	my $ident = $data->{'ident'};
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
		elsif (!$modifier)
		{
			next;
		}

		if ($tmp eq 'o')
		{
			if ($modifier eq '-')
			{
				$DATA->{'byident'}{$ident}{'op_taken'}++;
			}
			else # ($modifier eq '+')
			{
				$DATA->{'byident'}{$ident}{'op_given'}++;
			}
		}
	}

	return (1);
}

sub add_text
{
	my $data = shift;

	my $ident = $data->{'ident'};

	if (!defined ($SOLILOQUIES->{'ident'}))
	{
		$SOLILOQUIES->{'ident'} = $ident;
		$SOLILOQUIES->{'count'} = 1;
	}
	else
	{
		if ($SOLILOQUIES->{'ident'} eq $ident)
		{
			my $count = ++$SOLILOQUIES->{'count'};
			if ($count == $SOLILOQUIES_COUNT)
			{
				$DATA->{'byident'}{$ident}{'soliloquies'}++;
			}
		}
		else
		{
			$SOLILOQUIES->{'ident'} = $ident;
			$SOLILOQUIES->{'count'} = 1;
		}
	}

	return (1);
}

sub output
{
	my $first;
	my $second;

	my $fh = get_filehandle ();

	my $trans = translate ('Interesting Numbers');
	
	print $fh <<EOF;
<table class="plugin interestingnumbers">
  <tr>
    <th>$trans</th>
  </tr>
EOF
	($first, $second) = sort_by_field ('kick_received');
	if ($first)
	{
		my $num = $DATA->{'byname'}{$first}{'kick_received'};
		$trans = translate ('kick_received0: %s %u');

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first, $num);
		
		if ($second)
		{
			$num = $DATA->{'byname'}{$second}{'kick_received'};
			$trans = translate ('kick_received1: %s %u');

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second, $num);
			print $fh '</span>';
		}
		
		print $fh "</td>\n  </tr>\n";
	}

	($first, $second) = sort_by_field ('kick_given');
	if ($first)
	{
		my $num = $DATA->{'byname'}{$first}{'kick_given'};
		$trans = translate ('kick_given0: %s %u');

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first, $num);

		if ($second)
		{
			$num = $DATA->{'byname'}{$second}{'kick_given'};
			$trans = translate ('kick_given1: %s %u');

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second, $num);
			print $fh '</span>';
		}

		print $fh "</td>\n  </tr>\n";
	}

	($first, $second) = sort_by_field ('op_given');
	if ($first)
	{
		my $num = $DATA->{'byname'}{$first}{'op_given'};
		$trans = translate ('op_given0: %s %u');

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first, $num);
		
		if ($second)
		{
			$num = $DATA->{'byname'}{$second}{'op_given'};
			$trans = translate ('op_given1: %s %u');

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second, $num);
			print $fh '</span>';
		}
		
		print $fh "</td>\n  </tr>\n";
	}

	($first, $second) = sort_by_field ('op_taken');
	if ($first)
	{
		my $num = $DATA->{'byname'}{$first}{'op_taken'};
		$trans = translate ('op_taken0: %s %u');

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first, $num);
		
		if ($second)
		{
			$num = $DATA->{'byname'}{$second}{'op_taken'};
			$trans = translate ('op_taken1: %s %u');

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second, $num);
			print $fh '</span>';
		}
		
		print $fh "</td>\n  </tr>\n";
	}

	($first, $second) = sort_by_field ('actions');
	if ($first)
	{
		my $num = $DATA->{'byname'}{$first}{'actions'};
		$trans = translate ('action0: %s %u');

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first, $num);
		
		if ($second)
		{
			$num = $DATA->{'byname'}{$second}{'actions'};
			$trans = translate ('action1: %s %u');

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second, $num);
			print $fh '</span>';
		}

		print $fh "</td>\n  </tr>\n";
	}
	
	($first, $second) = sort_by_field ('soliloquies');
	if ($first)
	{
		my $num = $DATA->{'byname'}{$first}{'soliloquies'};
		$trans = translate ('soliloquies0: %s %u');

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first, $num);
		
		if ($second)
		{
			$num = $DATA->{'byname'}{$second}{'soliloquies'};
			$trans = translate ('soliloquies1: %s %u');

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second, $num);
			print $fh '</span>';
		}

		print $fh "</td>\n  </tr>\n";
	}
	
	($first, $second) = sort_by_field ('joins');
	if ($first)
	{
		my $num = $DATA->{'byname'}{$first}{'joins'};
		$trans = translate ('joins0: %s %u');

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first, $num);
		
		if ($second)
		{
			$num = $DATA->{'byname'}{$second}{'joins'};
			$trans = translate ('joins1: %s %u');

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second, $num);
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
		$DATA->{'byname'}{$b}{$field}
		<=>
		$DATA->{'byname'}{$a}{$field}
	} grep
	{
		defined ($DATA->{'byname'}{$_}{$field})
			and defined ($DATA->{'byname'}{$_}{'lines'})
			and ($DATA->{'byname'}{$_}{'lines'} >= 100)
	} (keys (%{$DATA->{'byname'}}));

	while (scalar (@retval) < 2)
	{
		push (@retval, '');
	}
	
	return (@retval);
}
