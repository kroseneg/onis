package Onis::Plugins::Userdetails;

use strict;
use warnings;

use Onis::Config (qw(get_config));
use Onis::Html (qw(html_escape get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(get_main_nick register_plugin nick_to_name));
use Onis::Users (qw(ident_to_name get_link get_image));

use Onis::Plugins::Core (qw(get_core_nick_counters get_sorted_nicklist));
use Onis::Plugins::Conversations (qw(get_conversations));
use Onis::Plugins::Bignumbers (qw(get_bignumbers));
use Onis::Plugins::Interestingnumbers (qw(get_interestingnumbers));

our $DISPLAY_IMAGES = 0;
our $DEFAULT_IMAGE = '';

register_plugin ('OUTPUT', \&output);

our $SORT_BY = 'lines';
if (get_config ('sort_by'))
{
	my $tmp = get_config ('sort_by');
	$tmp = lc ($tmp);

	if (($tmp eq 'lines') or ($tmp eq 'words') or ($tmp eq 'chars'))
	{
		$SORT_BY = $tmp;
	}
	else
	{
		# The Core plugin already complained about this..
	}
}
our $PLUGIN_MAX = 10;
if (get_config ('plugin_max'))
{
	my $tmp = get_config ('plugin_max');
	$tmp =~ s/\D//g;
	$PLUGIN_MAX = $tmp if ($tmp);
}
if (get_config ('display_images'))
{
	my $tmp = get_config ('display_images');

	if ($tmp =~ m/true|on|yes/i)
	{
		$DISPLAY_IMAGES = 1;
	}
	elsif ($tmp =~ m/false|off|no/i)
	{
		$DISPLAY_IMAGES = 0;
	}
	else
	{
		print STDERR $/, __FILE__, ": ``display_times'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``true'' and ``false''. Using default value ``false''.";
	}
}
if (get_config ('default_image'))
{
	$DEFAULT_IMAGE = get_config ('default_image');
}

our @H_IMAGES = qw#dark-theme/h-red.png dark-theme/h-blue.png dark-theme/h-yellow.png dark-theme/h-green.png#;
if (get_config ('horizontal_images'))
{
	my @tmp = get_config ('horizontal_images');
	my $i;
	
	if (scalar (@tmp) != 4)
	{
		# Do nothing:
		# The core-pligin already complained about this..
	}

	for ($i = 0; $i < 4; $i++)
	{
		if (!defined ($tmp[$i]))
		{
			next;
		}

		$H_IMAGES[$i] = $tmp[$i];
	}
}

our @V_IMAGES = qw#images/ver0n.png images/ver1n.png images/ver2n.png images/ver3n.png#;
if (get_config ('vertical_images'))
{
	my @tmp = get_config ('vertical_images');
	my $i;
	
	if (scalar (@tmp) != 4)
	{
		# Do nothing:
		# Hopefully someone complained by now..
	}

	for ($i = 0; $i < 4; $i++)
	{
		if (!defined ($tmp[$i]))
		{
			next;
		}

		$V_IMAGES[$i] = $tmp[$i];
	}
}

our $BAR_HEIGHT = 130;
if (get_config ('bar_height'))
{
	my $tmp = get_config ('bar_height');
	$tmp =~ s/\D//g;
	$BAR_HEIGHT = $tmp if ($tmp >= 10);
}
#$BAR_HEIGHT = int ($BAR_HEIGHT / 2);

our $BAR_WIDTH  = 100;
if (get_config ('bar_width'))
{
	my $tmp = get_config ('bar_width');
	$tmp =~ s/\D//g;
	$BAR_WIDTH = $tmp if ($tmp >= 10);
}

my $VERSION = '$Id: Userdetails.pm,v 1.5 2005/03/14 18:40:25 octo Exp $';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

sub output
{
	my $nicks_ref = get_sorted_nicklist ();
	
	my $max = $PLUGIN_MAX;
	
	my $fh = get_filehandle ();

	my $trans = translate ('Detailed nick stats');
	my $num;

	my $max_time = 0;
	my $max_conv = 0;

	my @nicks = @$nicks_ref;
	my $nick_data = {};

	splice (@nicks, $max) if (scalar (@nicks) > $max);

	for (@nicks)
	{
		my $nick = $_;

		$nick_data->{$nick} = get_core_nick_counters ($nick);
		$nick_data->{$nick}{'conversations'} = get_conversations ($nick);
		$nick_data->{$nick}{'bignumbers'} = get_bignumbers ($nick);
		$nick_data->{$nick}{'interestingnumbers'} = get_interestingnumbers ($nick);
		
		for (my $i = 0; $i < 24; $i++)
		{
			$num = $nick_data->{$nick}{'chars'}[$i];
			$max_time = $num if ($max_time < $num);
		}

		for (keys %{$nick_data->{$nick}{'conversations'}})
		{
			my $other = $_;
			my $ptr = $nick_data->{$nick}{'conversations'}{$other}{'nicks'}{$nick};
			$num = $ptr->[0] + $ptr->[1] + $ptr->[2] + $ptr->[3];
			$max_conv = $num if ($max_conv < $num);
		}
	}

	my $time_factor = 0;
	my $conv_factor = 0;

	if ($max_time)
	{
		$time_factor = $BAR_HEIGHT / $max_time;
	}

	if ($max_conv)
	{
		$conv_factor = $BAR_WIDTH / $max_conv;
	}
	
	print $fh qq#<table class="plugin userdetails">\n#,
	qq#  <tr>\n#,
	qq#    <th colspan="#, $DISPLAY_IMAGES ? 3 : 2, qq#">$trans</th>\n#,
	qq#  </tr>\n#;

	for (@nicks)
	{
		my $nick = $_;
		my $name = nick_to_name ($nick);
		my $print = $name ? $name : $nick;
		my $ptr = $nick_data->{$nick};

		print $fh qq#  <tr>\n#,
		qq#    <th colspan="#, $DISPLAY_IMAGES ? 3 : 2, qq#" class="nick">$print</th>\n#,
		qq#  </tr>\n#,
		qq#  <tr>\n#;

		if ($DISPLAY_IMAGES)
		{
			my $link = get_link ($name);
			my $image = get_image ($name);
			
			if ($DEFAULT_IMAGE and !$image)
			{
				$image = $DEFAULT_IMAGE;
			}

			print $fh qq#    <td class="image" rowspan="2">#;
			if ($image)
			{
				if ($link)
				{
					print $fh qq#<a href="$link">#;
				}
				print $fh qq#<img src="$image" alt="$print" />#;
				if ($link)
				{
					print $fh "</a>";
				}
			}
			else
			{
				print $fh '&nbsp;';
			}
			print $fh "</td>\n";
		}

		print $fh qq#    <td class="counters">\n#;

		{
			my $lines;
			my $words;
			my $chars;

			$lines = $ptr->{'lines_total'};
			$trans = translate ('Has written %u lines');
			printf $fh ("      $trans<br />\n", $lines);

			$words = $ptr->{'words_total'};
			$trans = translate ('Has written %u words');
			printf $fh ("      $trans<br />\n", $words);

			$chars = $ptr->{'chars_total'};
			$trans = translate ('Has written %u chars');
			printf $fh ("      $trans<br />\n", $chars);

			$lines ||= 1;

			$num = $words / $lines;
			$trans = translate ('Has written %.1f words per line');
			printf $fh ("      $trans<br />\n", $num);

			$num = $chars / $lines;
			$trans = translate ('Has written %.1f characters per line');
			printf $fh ("      $trans<br />\n", $num);
		}

		print $fh qq#    </td>\n    <td class="numbers">\n#;

		if (%{$ptr->{'interestingnumbers'}})
		{
			$trans = translate ('Has given %u ops');
			printf $fh ("      $trans<br />\n", $ptr->{'interestingnumbers'}{'op_given'});
		
			$trans = translate ('Has taken %u ops');
			printf $fh ("      $trans<br />\n", $ptr->{'interestingnumbers'}{'op_taken'});

			$trans = translate ('Has kicked out %u people');
			printf $fh ("      $trans<br />\n", $ptr->{'interestingnumbers'}{'kick_given'});
		
			$trans = translate ('Has been kicked out %u times');
			printf $fh ("      $trans<br />\n", $ptr->{'interestingnumbers'}{'kick_received'});

			$trans = translate ('Has performed %u actions');
			printf $fh ("      $trans<br />\n", $ptr->{'interestingnumbers'}{'actions'});
		}

		if (%{$ptr->{'bignumbers'}})
		{
			$num = 100 * $ptr->{'bignumbers'}{'questions'} / $ptr->{'lines_total'};
			$trans = translate ("Question ratio: %.1f%%");
			printf $fh ("      $trans<br />\n", $num);

			$num = 100 * $ptr->{'bignumbers'}{'uppercase'} / $ptr->{'lines_total'};
			$trans = translate ("Uppercase ratio: %.1f%%");
			printf $fh ("      $trans<br />\n", $num);

			$num = 100 * $ptr->{'bignumbers'}{'smiley_happy'} / $ptr->{'lines_total'};
			$trans = translate ("Happy smiley ratio: %.1f%%");
			printf $fh ("      $trans<br />\n", $num);

			$num = 100 * $ptr->{'bignumbers'}{'smiley_sad'} / $ptr->{'lines_total'};
			$trans = translate ("Sad smiley ratio: %.1f%%");
			printf $fh ("      $trans<br />\n", $num);
		}

		# actions # TODO
		# exclamation ratio # TODO
		# # of nicks
		#
		# chats with
		# lines per day

		print $fh qq#    </td>\n  </tr>\n  <tr>\n    <td class="houractivity">\n#;
		
		if (defined ($ptr->{'chars'}))
		{
			print $fh qq#      <table class="hours">\n        <tr class="bars">\n#;
			
			for (my $i = 0; $i < 24; $i++)
			{
				$num = 0;

				my $img = $V_IMAGES[int ($i / 6)];
				my $height;

				$num  = $ptr->{'chars'}[$i];

				$height = sprintf ("%.2f", 95 * $num / $max_time);

				print $fh qq#          <td class="bar vertical"><img src="$img" alt="$num chars" #,
				qq#class="first last" style="height: $height\%;" /></td>\n#;
			}

			print $fh <<EOF;
        </tr>
	<tr class="numeration">
	  <td colspan="6" class="numeration">0-5</td>
	  <td colspan="6" class="numeration">6-11</td>
	  <td colspan="6" class="numeration">12-17</td>
	  <td colspan="6" class="numeration">18-23</td>
	</tr>
      </table>
EOF
		}
		else
		{
			print '&nbsp;';
		}

		print $fh qq#    </td>\n    <td class="convpartners">\n#;
		
		if (%{$ptr->{'conversations'}})
		{
			my $i;
			my @others = sort
			{
				($ptr->{'conversations'}{$b}{'nicks'}{$nick}[0]
					+ $ptr->{'conversations'}{$b}{'nicks'}{$nick}[1]
					+ $ptr->{'conversations'}{$b}{'nicks'}{$nick}[2]
					+ $ptr->{'conversations'}{$b}{'nicks'}{$nick}[3])
				<=>
				($ptr->{'conversations'}{$a}{'nicks'}{$nick}[0]
					+ $ptr->{'conversations'}{$a}{'nicks'}{$nick}[1]
					+ $ptr->{'conversations'}{$a}{'nicks'}{$nick}[2]
					+ $ptr->{'conversations'}{$a}{'nicks'}{$nick}[3])
			}
			(keys %{$ptr->{'conversations'}});

			$trans = translate ('Talks to');

			print $fh <<EOF;
      <table>
        <tr>
	  <td colspan="2">$trans:</td>
	</tr>
EOF

			for (my $i = 0; $i < $PLUGIN_MAX and $i < scalar (@others); $i++)
			{
				my $other = $others[$i];
				my $other_name = nick_to_name ($other) || $other;
				my $total = 0;

				print $fh "        <tr>\n",
				qq#          <td class="nick">$other_name</td>\n#,
				qq#          <td class="bar">#;

				for (my $k = 0; $k < 4; $k++)
				{
					my $img = $H_IMAGES[$k];
					my $width = int (0.5 + ($conv_factor * $ptr->{'conversations'}{$other}{'nicks'}{$nick}[$k])) || 1;
					
					print $fh qq#<img src="$img" alt="" #;
					if ($k == 0)
					{
						print $fh qq#class="first" #;
					}
					elsif ($k == 3)
					{
						print $fh qq#class="last" #;
					}
					print $fh qq#style="width: ${width}px;" />#;
				}
				
				print $fh "</td>\n        </tr>\n";
			}

			print $fh "      </table>\n";
		}
		else
		{
			print $fh '&nbsp;';
		}
	}

	print $fh "</table>\n\n";
}
