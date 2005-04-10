package Onis::Plugins::Userdetails;

use strict;
use warnings;

use Onis::Config (qw(get_config));
use Onis::Html (qw(html_escape get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(get_main_nick register_plugin));
use Onis::Users (qw(ident_to_name get_link get_image));

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
	my @names = sort
	{
		$DATA->{'byname'}{$b}{$SORT_BY} <=> $DATA->{'byname'}{$a}{$SORT_BY}
	} grep
	{
		defined ($DATA->{'byname'}{$_}{'words'})
	} (keys (%{$DATA->{'byname'}}));

	return (undef) unless (@names);
	
	my $max = $PLUGIN_MAX;
	
	my $fh = get_filehandle ();

	my $trans = translate ('Detailed nick stats');
	my $num;

	my $max_time = 0;
	my $max_conv = 0;

	for (@names)
	{
		my $name = $_;
		
		if (defined ($DATA->{'byname'}{$name}{'chars_time'}))
		{
			for (0..23)
			{
				next unless (defined ($DATA->{'byname'}{$name}{'chars_time'}{$_}));
				if ($DATA->{'byname'}{$name}{'chars_time'}{$_} > $max_time)
				{
					$max_time = $DATA->{'byname'}{$name}{'chars_time'}{$_};
				}
			}
		}
		if (defined ($DATA->{'byname'}{$name}{'conversations'}))
		{
			my @others = keys (%{$DATA->{'byname'}{$name}{'conversations'}});
			for (@others)
			{
				my $o = $_;
				my $num = 0;

				for (0..3)
				{
					$num += $DATA->{'byname'}{$name}{'conversations'}{$o}[$_];
				}

				if ($num > $max_conv)
				{
					$max_conv = $num;
				}
			}
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

	for (@names)
	{
		my $name = $_;

		print $fh qq#  <tr>\n#,
		qq#    <th colspan="#, $DISPLAY_IMAGES ? 3 : 2, qq#" class="nick">$name</th>\n#,
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
				print $fh qq#<img src="$image" alt="$name" />#;
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

		$num = $DATA->{'byname'}{$name}{'lines'};
		$trans = translate ('Has written %u lines');
		printf $fh ("      $trans<br />\n", $num);

		$num = $DATA->{'byname'}{$name}{'words'};
		$trans = translate ('Has written %u words');
		printf $fh ("      $trans<br />\n", $num);

		$num = $DATA->{'byname'}{$name}{'chars'};
		$trans = translate ('Has written %u chars');
		printf $fh ("      $trans<br />\n", $num);

		if ($DATA->{'byname'}{$name}{'lines'})
		{
			$num = $DATA->{'byname'}{$name}{'words'} / $DATA->{'byname'}{$name}{'lines'};
			$trans = translate ('Has written %.1f words per line');
			printf $fh ("      $trans<br />\n", $num);

			$num = $DATA->{'byname'}{$name}{'chars'} / $DATA->{'byname'}{$name}{'lines'};
			$trans = translate ('Has written %.1f characters per line');
			printf $fh ("      $trans<br />\n", $num);
		}

		print $fh qq#    </td>\n    <td class="numbers">\n#;

		if (defined ($DATA->{'byname'}{$name}{'op_given'}))
		{
			$num = $DATA->{'byname'}{$name}{'op_given'};
			$trans = translate ('Has given %u ops');

			printf $fh ("      $trans<br />\n", $num);
		}
		
		if (defined ($DATA->{'byname'}{$name}{'op_taken'}))
		{
			$num = $DATA->{'byname'}{$name}{'op_taken'};
			$trans = translate ('Has taken %u ops');

			printf $fh ("      $trans<br />\n", $num);
		}
		
		if (defined ($DATA->{'byname'}{$name}{'kick_given'}))
		{
			$num = $DATA->{'byname'}{$name}{'kick_given'};
			$trans = translate ('Has kicked out %u people');

			printf $fh ("      $trans<br />\n", $num);
		}
		
		if (defined ($DATA->{'byname'}{$name}{'kick_received'}))
		{
			$num = $DATA->{'byname'}{$name}{'kick_received'};
			$trans = translate ('Has been kicked out %u times');

			printf $fh ("      $trans<br />\n", $num);
		}
		
		if (defined ($DATA->{'byname'}{$name}{'questions'}))
		{
			$num = 100 * $DATA->{'byname'}{$name}{'questions'} / $DATA->{'byname'}{$name}{'lines'};
			$trans = translate ("Question ratio: %.1f%%");

			printf $fh ("      $trans<br />\n", $num);
		}

		if (defined ($DATA->{'byname'}{$name}{'topics'}))
		{
			$num = $DATA->{'byname'}{$name}{'topics'};
			$trans = translate ('Has set %u topics');

			printf $fh ("      $trans<br />\n", $num);
		}

		if (defined ($DATA->{'byname'}{$name}{'actions'}))
		{
			$num = $DATA->{'byname'}{$name}{'actions'};
			$trans = translate ('Has performed %u actions');

			printf $fh ("      $trans<br />\n", $num);
		}

		# actions # TODO
		# exclamation ratio # TODO
		# # of nicks
		#
		# chats with
		# lines per day

		print $fh qq#    </td>\n  </tr>\n  <tr>\n    <td class="houractivity">\n#;
		
		if (defined ($DATA->{'byname'}{$name}{'chars_time'}))
		{
			print $fh qq#      <table class="hours_of_day">\n        <tr>\n#;
			
			for (0..11)
			{
				my $hour = 2 * $_;
				my $num = 0;

				my $img = $V_IMAGES[int ($hour / 6)];
				my $height;

				if (defined ($DATA->{'byname'}{$name}{'chars_time'}{$hour}))
				{
					$num = $DATA->{'byname'}{$name}{'chars_time'}{$hour};
				}
				if (defined ($DATA->{'byname'}{$name}{'chars_time'}{1 + $hour}))
				{
					$num = $DATA->{'byname'}{$name}{'chars_time'}{1 + $hour};
				}

				$height = int (0.5 + ($time_factor * $num));
				if (!$height)
				{
					$height = 1;
				}

				print $fh qq#          <td><img src="$img" alt="$num chars" #,
				qq#style="height: ${height}px;" /></td>\n#;
			}

			print $fh <<EOF;
        </tr>
	<tr class="hour_row">
	  <td colspan="3">0-5</td>
	  <td colspan="3">6-11</td>
	  <td colspan="3">12-17</td>
	  <td colspan="3">18-23</td>
	</tr>
      </table>
EOF
		}
		else
		{
			print $fh '&nbsp;';
		}

		print $fh qq#    </td>\n    <td class="convpartners">\n#;
		
		if (defined ($DATA->{'byname'}{$name}{'conversations'}))
		{
			my $i;
			my $data = $DATA->{'byname'}{$name}{'conversations'};
			my @names = sort
			{
				($data->{$b}[0] + $data->{$b}[1] + $data->{$b}[2] + $data->{$b}[3])
				<=>
				($data->{$a}[0] + $data->{$a}[1] + $data->{$a}[2] + $data->{$a}[3])
			}
			keys (%$data);

			$trans = translate ('Talks to');

			print $fh <<EOF;
      <table>
        <tr>
	  <td colspan="2">$trans:</td>
	</tr>
EOF

			$i = 0;
			for (@names)
			{
				my $this_name = $_;
				my $total = 0;

				print $fh "        <tr>\n",
				qq#          <td class="nick">$this_name</td>\n#,
				qq#          <td class="bar">#;

				for (0..3)
				{
					my $k = $_;
					
					my $img = $H_IMAGES[$k];
					my $width = int (0.5 + ($conv_factor * $data->{$this_name}[$_]));
					if (!$width)
					{
						$width = 1;
					}
					
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

				$i++;

				if ($i >= $PLUGIN_MAX)
				{
					last;
				}
			}

			print $fh "      </table>\n";
		}
		else
		{
			print $fh '&nbsp;';
		}

		$max--;
		if ($max <= 0)
		{
			last;
		}
	}

	print $fh "</table>\n\n";
}
