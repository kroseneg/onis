package Onis::Plugins::Bignumbers;

use strict;
use warnings;

use Exporter;

use Onis::Html (qw(get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(get_main_nick register_plugin));
use Onis::Data::Persistent ();
use Onis::Users (qw(nick_to_name));
use Onis::Plugins::Core (qw(get_core_nick_counters));

@Onis::Plugins::Bignumbers::EXPORT_OK = (qw(get_bignumbers));
@Onis::Plugins::Bignumbers::ISA = ('Exporter');

our $BigNumbers = Onis::Data::Persistent->new ('BigNumbers', 'nick', qw(questions uppercase smiley_happy smiley_sad));
our $CalcData = {};

register_plugin ('TEXT', \&add);
register_plugin ('ACTION', \&add);
register_plugin ('OUTPUT', \&output);

my $VERSION = '$Id$';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

sub add
{
	my $data = shift;

	my $nick = $data->{'nick'};
	my $text = $data->{'text'};

	my $mod = 0;

	my @nums = $BigNumbers->get ($nick);
	if (!@nums)
	{
		@nums = (0, 0, 0, 0);
		$mod++;
	}

	if ($text =~ m/\b\?/)
	{
		$nums[0]++;
		$mod++;
	}

	if ((uc ($text) eq $text) and ($text =~ m/[A-Z]/))
	{
		$nums[1]++;
		$mod++;
	}

	if ($text =~ m/( |^)[;:]-?\)( |$)/)
	{
		$nums[2]++;
		$mod++;
	}

	if ($text =~ m/( |^):-?\(( |$)/)
	{
		$nums[3]++;
		$mod++;
	}

	if ($mod)
	{
		$BigNumbers->put ($nick, @nums);
	}

	return (1);
}

sub calculate
{
	for ($BigNumbers->keys ())
	{
		my $nick = $_;
		my $main = get_main_nick ($nick);
		my ($questions, $uppercase, $smiley_happy, $smiley_sad) = $BigNumbers->get ($nick);

		next unless (defined ($smiley_sad));
		
		if (!defined ($CalcData->{$main}))
		{
			my $core_data = get_core_nick_counters ($main);
			next unless (%$core_data);

			$CalcData->{$main} =
			{
				lines => $core_data->{'lines_total'},
				words => $core_data->{'words_total'},
				chars => $core_data->{'chars_total'},
				questions    => 0,
				uppercase    => 0,
				smiley_happy => 0,
				smiley_sad   => 0
			};
		}

		$CalcData->{$main}{'questions'}    += $questions;
		$CalcData->{$main}{'uppercase'}    += $uppercase;
		$CalcData->{$main}{'smiley_happy'} += $smiley_happy;
		$CalcData->{$main}{'smiley_sad'}   += $smiley_sad;
	}
}

sub output
{
	my $first_nick;
	my $first_name;
	my $second_nick;
	my $second_name;
	my $trans;

	my $fh = get_filehandle ();
	
	$trans = translate ('Big Numbers');
	print $fh <<EOF;
<table class="plugin bignumbers">
  <tr>
    <th>$trans</th>
  </tr>
EOF
	($first_nick, $second_nick) = sort_by_field ('questions');
	if ($first_nick)
	{
		my $percent = 100 * $CalcData->{$first_nick}{'questions'} / $CalcData->{$first_nick}{'lines'};
		my $trans = translate ('questions0: %s %2.1f%%');
		$first_name = nick_to_name ($first_nick) || $first_nick;

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first_name, $percent);
		
		if ($second_nick)
		{
			$percent = 100 * $CalcData->{$second_nick}{'questions'} / $CalcData->{$second_nick}{'lines'};
			$trans = translate ('questions1: %s %2.1f%%');
			$second_name = nick_to_name ($second_nick) || $second_nick;

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second_name, $percent);
			print $fh '</span>';
		}
		
		print $fh "</td>\n  </tr>\n";
	}

	($first_nick, $second_nick) = sort_by_field ('uppercase');
	if ($first_nick)
	{
		my $percent = 100 * $CalcData->{$first_nick}{'uppercase'} / $CalcData->{$first_nick}{'lines'};
		my $trans = translate ('yells0: %s %2.1f%%');
		$first_name = nick_to_name ($first_nick) || $first_nick;

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first_name, $percent);

		if ($second_nick)
		{
			$percent = 100 * $CalcData->{$second_nick}{'uppercase'} / $CalcData->{$second_nick}{'lines'};
			$trans = translate ('yells1: %s %2.1f%%');
			$second_name = nick_to_name ($second_nick) || $second_nick;

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second_name, $percent);
			print $fh "</span>";
		}

		print $fh "</td>\n  </tr>\n";
	}

	($first_nick, $second_nick) = sort_by_field ('smiley_happy');
	if ($first_nick)
	{
		my $percent = 100 * $CalcData->{$first_nick}{'smiley_happy'} / $CalcData->{$first_nick}{'lines'};
		my $trans = translate ('happy0: %s %2.1f%%');
		$first_name = nick_to_name ($first_nick) || $first_nick;

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first_name, $percent);
		
		if ($second_nick)
		{
			$percent = 100 * $CalcData->{$second_nick}{'smiley_happy'} / $CalcData->{$second_nick}{'lines'};
			$trans = translate ('happy1: %s %2.1f%%');
			$second_name = nick_to_name ($second_nick) || $second_nick;

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second_name, $percent);
			print $fh "</span>";
		}
		
		print $fh "</td>\n  </tr>\n";
	}

	($first_nick, $second_nick) = sort_by_field ('smiley_sad');
	if ($first_nick)
	{
		my $percent = 100 * $CalcData->{$first_nick}{'smiley_sad'} / $CalcData->{$first_nick}{'lines'};
		my $trans = translate ('sad0: %s %2.1f%%');
		$first_name = nick_to_name ($first_nick) || $first_nick;

		print $fh "  <tr>\n    <td>";
		printf $fh ($trans, $first_name, $percent);
		
		if ($second_nick)
		{
			$percent = 100 * $CalcData->{$second_nick}{'smiley_sad'} / $CalcData->{$second_nick}{'lines'};
			$trans = translate ('sad1: %s %2.1f%%');
			$second_name = nick_to_name ($second_nick) || $second_nick;

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $second_name, $percent);
			print $fh "</span>";
		}
		
		print $fh "</td>\n  </tr>\n";
	}

	{
		my @names = sort_by_field ('chars');
		
		my $longest = '';
		my $longest2 = '';
		my $shortest = '';
		my $shortest2 = '';
		
		my $chan_chars = 0;
		my $chan_lines = 0;
		
		for (@names)
		{
			$chan_chars += $CalcData->{$_}{'chars'} || 0;
			$chan_lines += $CalcData->{$_}{'lines'} || 0;
		}

		if (@names)
		{
			$longest = shift (@names);
		}
		if (@names)
		{
			$longest2 = shift (@names);
		}
		if (@names)
		{
			$shortest = pop (@names);
		}
		if (@names)
		{
			$shortest2 = pop (@names);
		}
		
		if ($longest)
		{
			my $avg = $CalcData->{$longest}{'chars'} / $CalcData->{$longest}{'lines'};
			my $trans = translate ('max chars0: %s %1.1f');
			$first_name = nick_to_name ($longest) || $longest;
			
			print $fh "  <tr>\n    <td>";
			printf $fh ($trans, $first_name, $avg);
			
			if ($longest2)
			{
				$avg = $CalcData->{$longest2}{'chars'} / $CalcData->{$longest2}{'lines'};
				$trans = translate ('max chars1: %s %1.1f');
				$second_name = nick_to_name ($longest2) || $longest2;

				print $fh "<br />\n",
				qq#      <span class="small">#;
				printf $fh ($trans, $second_name, $avg);
				print $fh "</span>";
			}

			$avg = $chan_chars / $chan_lines;
			$trans = translate ('chars avg: %1.1f');

			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $avg);
			print $fh "</span></td>\n  </tr>\n";
		}

		if ($shortest)
		{
			my $avg = $CalcData->{$shortest}{'chars'} / $CalcData->{$shortest}{'lines'};
			my $trans = translate ('min chars0: %s %1.1f');
			$first_name = nick_to_name ($shortest) || $shortest;
			
			print $fh "  <tr>\n    <td>";
			printf $fh ($trans, $first_name, $avg);
			
			if ($shortest2)
			{
				$avg = $CalcData->{$shortest2}{'chars'} / $CalcData->{$shortest2}{'lines'};
				$trans = translate ('min chars1: %s %1.1f');
				$second_name = nick_to_name ($shortest2) || $shortest2;

				print $fh "<br />\n",
				qq#      <span class="small">#;
				printf $fh ($trans, $second_name, $avg);
				print $fh "</span>";
			}
			print $fh "</td>\n  </tr>\n";
		}
	}
	
	{
		my @names = sort_by_field ('words');

		$first_nick = '';
		$second_nick = '';

		my $chan_words = 0;
		my $chan_lines = 0;
		
		for (@names)
		{
			$chan_words += $CalcData->{$_}{'words'} || 0;
			$chan_lines += $CalcData->{$_}{'lines'} || 0;
		}
		
		if (@names)
		{
			$first_nick = shift (@names);
		}
		if (@names)
		{
			$second_nick = shift (@names);
		}

		if ($first_nick)
		{
			my $avg = $CalcData->{$first_nick}{'words'} / $CalcData->{$first_nick}{'lines'};
			my $trans = translate ('max words0: %s %1.1f');
			$first_name = nick_to_name ($first_nick) || $first_nick;
			
			print $fh "  <tr>\n    <td>";
			printf $fh ($trans, $first_name, $avg);

			if ($second_nick)
			{
				$avg = $CalcData->{$second_nick}{'words'} / $CalcData->{$second_nick}{'lines'};
				$trans = translate ('max words1: %s %1.1f');
				$second_name = nick_to_name ($second_nick) || $second_nick;

				print $fh "<br />\n",
				qq#      <span class="small">#;
				printf $fh ($trans, $second_name, $avg);
				print $fh "</span>";
			}

			$avg = $chan_words / $chan_lines;
			$trans = translate ('words avg: %1.1f');
			
			print $fh "<br />\n",
			qq#      <span class="small">#;
			printf $fh ($trans, $avg);
			print $fh "</span></td>\n  </tr>\n";
		}
	}

	print $fh "</table>\n\n";
}

sub sort_by_field
{
	my $field = shift;

	my @retval = sort
	{
		($CalcData->{$b}{$field} / $CalcData->{$b}{'lines'})
		<=>
		($CalcData->{$a}{$field} / $CalcData->{$a}{'lines'})
	} grep
	{
		defined ($CalcData->{$_}{'lines'})
			and ($CalcData->{$_}{'lines'} != 0)
			and defined ($CalcData->{$_}{$field})
	}
	(keys (%$CalcData));
	
	while (scalar (@retval) < 2)
	{
		push (@retval, '');
	}

	return (@retval);
}

sub get_bignumbers
{
	my $nick = shift;

	if (!defined ($CalcData->{$nick}))
	{
		return ({});
	}

	return ($CalcData->{$nick});
}
