package Onis::Plugins::Userdetails;

use strict;
use warnings;

use Onis::Config (qw(get_config));
use Onis::Html (qw(html_escape get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(get_main_nick register_plugin nick_to_name get_most_recent_time));
use Onis::Users (qw(get_link get_image));

use Onis::Plugins::Core (qw(get_core_nick_counters get_sorted_nicklist));
use Onis::Plugins::Weekdays (qw(get_weekdays));
use Onis::Plugins::Longterm (qw(get_longterm));
use Onis::Plugins::Conversations (qw(get_conversations));
use Onis::Plugins::Bignumbers (qw(get_bignumbers));
use Onis::Plugins::Interestingnumbers (qw(get_interestingnumbers));

our $DisplayImages = 0;
our $DefaultImage = '';

register_plugin ('OUTPUT', \&output);

our $NumUserdetails = 10;
if (get_config ('userdetails_number'))
{
	my $tmp = get_config ('userdetails_number');
	$tmp =~ s/\D//g;
	$NumUserdetails = $tmp if ($tmp);
}

if (get_config ('display_images'))
{
	my $tmp = get_config ('display_images');

	if ($tmp =~ m/true|on|yes/i)
	{
		$DisplayImages = 1;
	}
	elsif ($tmp =~ m/false|off|no/i)
	{
		$DisplayImages = 0;
	}
	else
	{
		print STDERR $/, __FILE__, ": ``display_times'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``true'' and ``false''. Using default value ``false''.";
	}
}
if (get_config ('default_image'))
{
	$DefaultImage = get_config ('default_image');
}

our @HorizontalImages = qw#dark-theme/h-red.png dark-theme/h-blue.png dark-theme/h-yellow.png dark-theme/h-green.png#;
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

		$HorizontalImages[$i] = $tmp[$i];
	}
}

our @VerticalImages = qw#images/ver0n.png images/ver1n.png images/ver2n.png images/ver3n.png#;
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

		$VerticalImages[$i] = $tmp[$i];
	}
}

our $ConversationsNumber = 10;
if (get_config ('userdetails_conversations_number'))
{
	my $tmp = get_config ('userdetails_conversations_number');
	$tmp =~ s/\D//g;
	$ConversationsNumber = $tmp if ($tmp);
}

our $LongtermDays = 7;
if (get_config ('userdetails_longterm_days'))
{
	my $tmp = get_config ('userdetails_longterm_days');
	$tmp =~ s/\D//g;
	$LongtermDays = $tmp if ($tmp);
}

my $VERSION = '$Id: Userdetails.pm,v 1.5 2005/03/14 18:40:25 octo Exp $';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

sub output
{
	my $nicks_ref = get_sorted_nicklist ();
	
	my $fh = get_filehandle ();

	my $trans = translate ('Detailed nick stats');
	my $num;

	my $max_time = 0;
	my $max_conv = 0;
	my $max_weekdays = 0;
	my $max_longterm = 0;

	my @nicks = @$nicks_ref;
	my $nick_data = {};

	splice (@nicks, $NumUserdetails) if (scalar (@nicks) > $NumUserdetails);

	for (@nicks)
	{
		my $nick = $_;

		$nick_data->{$nick} = get_core_nick_counters ($nick);
		$nick_data->{$nick}{'weekdays'} = get_weekdays ($nick);
		$nick_data->{$nick}{'longterm'} = get_longterm ($nick);
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

		for (keys %{$nick_data->{$nick}{'weekdays'}})
		{
			my $ptr = $nick_data->{$nick}{'weekdays'}{$_};
			for (my $i = 0; $i < 4; $i++)
			{
				$max_weekdays = $ptr->[$i] if ($max_weekdays < $ptr->[$i]);
			}
		}

		if (@{$nick_data->{$nick}{'longterm'}})
		{
			my $num = scalar (@{$nick_data->{$nick}{'longterm'}});
			$LongtermDays = $num if ($LongtermDays > $num);

			for (my $i = $num - $LongtermDays; $i < $num; $i++)
			{
				my $ptr = $nick_data->{$nick}{'longterm'}[$i];

				for (my $j = 0; $j < 4; $j++)
				{
					$max_longterm = $ptr->[$j] if ($max_longterm < $ptr->[$j]);
				}
			}
		}
	}

	print $fh qq#<table class="plugin userdetails">\n#,
	qq#  <tr>\n#,
	qq#    <th colspan="#, $DisplayImages ? 4 : 3, qq#">$trans</th>\n#,
	qq#  </tr>\n#;

	for (@nicks)
	{
		my $nick = $_;
		my $name = nick_to_name ($nick);
		my $print = $name ? $name : $nick;
		my $ptr = $nick_data->{$nick};

		print $fh qq#  <tr>\n#,
		qq#    <th colspan="#, $DisplayImages ? 4 : 3, qq#" class="nick">$print</th>\n#,
		qq#  </tr>\n#,
		qq#  <tr>\n#;

		if ($DisplayImages)
		{
			my $link = get_link ($name);
			my $image = get_image ($name);
			
			if ($DefaultImage and !$image)
			{
				$image = $DefaultImage;
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

		print $fh qq#    </td>\n    <td>\n#;
		
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
      <table class="conversations">
        <tr>
	  <td colspan="2">$trans:</td>
	</tr>
EOF

			for (my $i = 0; $i < $ConversationsNumber and $i < scalar (@others); $i++)
			{
				my $other = $others[$i];
				my $other_name = nick_to_name ($other) || $other;
				my $total = 0;

				print $fh "        <tr>\n",
				qq#          <td class="nick right">$other_name</td>\n#,
				qq#          <td class="bar horizontal right">#;

				for (my $k = 0; $k < 4; $k++)
				{
					my $img = $HorizontalImages[$k];
					my $num = $ptr->{'conversations'}{$other}{'nicks'}{$nick}[$k];
					my $width = sprintf ("%.2f", 95 * $num / $max_conv);
					
					print $fh qq#<img src="$img" alt="" #;
					if ($k == 0)
					{
						print $fh qq#class="first" #;
					}
					elsif ($k == 3)
					{
						print $fh qq#class="last" #;
					}
					print $fh qq#style="width: $width\%;" />#;
				}
				
				print $fh "</td>\n        </tr>\n";
			}

			print $fh "      </table>\n";
		}
		else
		{
			print $fh '&nbsp;';
		}
		print $fh qq#    </td>\n  </tr>\n#,
		qq#  <tr>\n    <td>\n#;
		
		if (defined ($ptr->{'chars'}))
		{
			print $fh qq#      <table class="hours">\n        <tr class="bars">\n#;
			
			for (my $i = 0; $i < 24; $i++)
			{
				$num = 0;

				my $img = $VerticalImages[int ($i / 6)];
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
			print $fh "      &nbsp;\n";
		}

		print $fh qq#    </td>\n    <td>\n#;

		#weekly
		if (%{$nick_data->{$nick}{'weekdays'}})
		{
			my $data = $nick_data->{$nick}{'weekdays'};
			my @days = (qw(mon tue wed thu fri sat sun));

			print $fh qq#      <table class="weekdays">\n#,
			qq#        <tr class="bars">\n#;

			for (@days)
			{
				my $day = $_;
				for (my $i = 0; $i < 4; $i++)
				{
					my $num = $nick_data->{$nick}{'weekdays'}{$day}[$i];
					my $height = sprintf ("%.2f", 95 * $num / $max_weekdays);
					my $img = $VerticalImages[$i];

					print $fh qq#          <td class="bar vertical">#,
					qq#<img src="$img" alt="" class="first last" style="height: $height\%;" />#,
					qq#</td>\n#;
				}
			}

			print $fh qq#        </tr>\n#,
			qq#        <tr class="numeration">\n#;

			for (@days)
			{
				my $day = $_;
				my $trans = translate ($day);
				
				print $fh qq#          <td colspan="4" class="numeration $day">$trans</td>\n#;
			}

			print $fh qq#        </tr>\n#,
			qq#      </table>\n#;
		}
		else
		{
			print $fh "      &nbsp;\n";
		}

		print $fh qq#    </td>\n    <td>\n#;

		#longterm
		if (@{$nick_data->{$nick}{'longterm'}})
		{
			my $num_fields = scalar (@{$nick_data->{$nick}{'longterm'}});
			my $now_epoch = get_most_recent_time ();
			my $now_day = int ($now_epoch / 86400);
			my $last_day;

			my @weekdays = (qw(sun mon tue wed thu fri sat));

			$LongtermDays = $num_fields if ($LongtermDays > $num_fields);
			$last_day = 1 + $now_day - $LongtermDays;
			
			print $fh qq#      <table class="longterm">\n#,
			qq#        <tr class="bars">\n#;

			for (my $i = $num_fields - $LongtermDays; $i < $num_fields; $i++)
			{
				for (my $j = 0; $j < 4; $j++)
				{
					my $num = $nick_data->{$nick}{'longterm'}[$i][$j];
					my $height = sprintf ("%.2f", 95 * $num / $max_longterm);
					my $img = $VerticalImages[$j];
					
					print $fh qq#          <td class="bar vertical">#,
					qq#<img src="$img" alt="" class="first last" style="height: $height\%;" />#,
					qq#</td>\n#;
				}
			}
			
			print $fh qq#        </tr>\n#,
			qq#        <tr class="numeration">\n#;

			for (my $i = 0; $i < $LongtermDays; $i++)
			{
				my $epoch = ($last_day + $i) * 86400;
				my ($day, $wd) = (localtime ($epoch))[3,6];
				$wd = $weekdays[$wd];

				print $fh qq#          <td colspan="4" class="numeration $wd">$day.</td>\n#;
			}

			print $fh qq#        </tr>\n#,
			qq#      </table>\n#;
		}
		else
		{
			print $fh "      &nbsp;\n";
		}

		print $fh qq#    </td>\n  </tr>\n#;
	}

	print $fh "</table>\n\n";
}
