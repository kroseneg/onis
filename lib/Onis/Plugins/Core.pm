package Onis::Plugins::Core;

use strict;
use warnings;

=head1 NAME

Onis::Plugins::Core

=head1 DESCRIPTION

Plugin for the main table and the hourly-statistics. This is the most
complicated plugin so far.

=cut

use Onis::Config qw/get_config/;
use Onis::Html qw/html_escape get_filehandle/;
use Onis::Language qw/translate/;
use Onis::Users qw/get_name get_link get_image nick_to_username/;
use Onis::Data::Core qw#get_all_nicks nick_to_ident ident_to_nick get_main_nick register_plugin#;
use Onis::Data::Persistent;

our $NickLinesCounter = Onis::Data::Persistent->new ('NickLinesCounter', 'nick',
	qw(
		lines00 lines01 lines02 lines03 lines04 lines05 lines06 lines07 lines08 lines09 lines10 lines11
		lines12 lines13 lines14 lines15 lines16 lines17 lines18 lines19 lines20 lines21 lines22 lines23
	)
);
our $NickWordsCounter = Onis::Data::Persistent->new ('NickWordsCounter', 'nick',
	qw(
		words00 words01 words02 words03 words04 words05 words06 words07 words08 words09 words10 words11
		words12 words13 words14 words15 words16 words17 words18 words19 words20 words21 words22 words23
	)
);
our $NickCharsCounter = Onis::Data::Persistent->new ('NickCharsCounter', 'nick',
	qw(
		chars00 chars01 chars02 chars03 chars04 chars05 chars06 chars07 chars08 chars09 chars10 chars11
		chars12 chars13 chars14 chars15 chars16 chars17 chars18 chars19 chars20 chars21 chars22 chars23
	)
);

our $QuoteCache = {}; # Saves per-nick information without any modification
our $QuoteData = {};  # Is generated before output. Nicks are merged according to Data::Core.

our @H_IMAGES = qw#dark-theme/h-red.png dark-theme/h-blue.png dark-theme/h-yellow.png dark-theme/h-green.png#;
our $QuoteCache_SIZE = 10;
our $QuoteMin = 30;
our $QuoteMax = 80;
our $WORD_LENGTH = 5;
our $SORT_BY = 'LINES';
our $DISPLAY_LINES = 'BOTH';
our $DISPLAY_WORDS = 'NONE';
our $DISPLAY_CHARS = 'NONE';
our $DISPLAY_TIMES = 0;
our $DISPLAY_IMAGES = 0;
our $DEFAULT_IMAGE = '';
our $BAR_HEIGHT = 130;
our $BAR_WIDTH  = 100;
our $LONGLINES  = 50;
our $SHORTLINES = 10;

if (get_config ('quote_cache_size'))
{
	my $tmp = get_config ('quote_cache_size');
	$tmp =~ s/\D//g;
	$QuoteCache_SIZE = $tmp if ($tmp);
}
if (get_config ('quote_min'))
{
	my $tmp = get_config ('quote_min');
	$tmp =~ s/\D//g;
	$QuoteMin = $tmp if ($tmp);
}
if (get_config ('quote_max'))
{
	my $tmp = get_config ('quote_max');
	$tmp =~ s/\D//g;
	$QuoteMax = $tmp if ($tmp);
}
if (get_config ('min_word_length'))
{
	my $tmp = get_config ('min_word_length');
	$tmp =~ s/\D//g;
	$WORD_LENGTH = $tmp if ($tmp);
}
if (get_config ('display_lines'))
{
	my $tmp = get_config ('display_lines');
	$tmp = uc ($tmp);

	if (($tmp eq 'NONE') or ($tmp eq 'BAR') or ($tmp eq 'NUMBER') or ($tmp eq 'BOTH'))
	{
		$DISPLAY_LINES = $tmp;
	}
	else
	{
		$tmp = get_config ('display_lines');
		print STDERR $/, __FILE__, ": ``display_lines'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``none'', ``bar'', ``number'' and ``both''. Using default value ``both''.";
	}
}
if (get_config ('display_words'))
{
	my $tmp = get_config ('display_words');
	$tmp = uc ($tmp);

	if (($tmp eq 'NONE') or ($tmp eq 'BAR') or ($tmp eq 'NUMBER') or ($tmp eq 'BOTH'))
	{
		$DISPLAY_WORDS = $tmp;
	}
	else
	{
		$tmp = get_config ('display_words');
		print STDERR $/, __FILE__, ": ``display_words'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``none'', ``bar'', ``number'' and ``both''. Using default value ``none''.";
	}
}
if (get_config ('display_chars'))
{
	my $tmp = get_config ('display_chars');
	$tmp = uc ($tmp);

	if (($tmp eq 'NONE') or ($tmp eq 'BAR') or ($tmp eq 'NUMBER') or ($tmp eq 'BOTH'))
	{
		$DISPLAY_CHARS = $tmp;
	}
	else
	{
		$tmp = get_config ('display_chars');
		print STDERR $/, __FILE__, ": ``display_chars'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``none'', ``bar'', ``number'' and ``both''. Using default value ``none''.";
	}
}
if (get_config ('display_times'))
{
	my $tmp = get_config ('display_times');

	if ($tmp =~ m/true|on|yes/i)
	{
		$DISPLAY_TIMES = 1;
	}
	elsif ($tmp =~ m/false|off|no/i)
	{
		$DISPLAY_TIMES = 0;
	}
	else
	{
		print STDERR $/, __FILE__, ": ``display_times'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``true'' and ``false''. Using default value ``false''.";
	}
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
if (get_config ('sort_by'))
{
	my $tmp = get_config ('sort_by');
	$tmp = uc ($tmp);

	if (($tmp eq 'LINES') or ($tmp eq 'WORDS') or ($tmp eq 'CHARS'))
	{
		$SORT_BY = $tmp;
	}
	else
	{
		$tmp = get_config ('sort_by');
		print STDERR $/, __FILE__, ": ``sort_by'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``lines'' and ``words''. Using default value ``lines''.";
	}
}
if (get_config ('horizontal_images'))
{
	my @tmp = get_config ('horizontal_images');
	my $i;
	
	if (scalar (@tmp) != 4)
	{
		print STDERR $/, __FILE__, ": The number of horizontal images is not four. The output might look weird.", $/;
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
if (get_config ('bar_height'))
{
	my $tmp = get_config ('bar_height');
	$tmp =~ s/\D//g;
	$BAR_HEIGHT = $tmp if ($tmp >= 10);
}
if (get_config ('bar_width'))
{
	my $tmp = get_config ('bar_width');
	$tmp =~ s/\D//g;
	$BAR_WIDTH = $tmp if ($tmp >= 10);
}
if (get_config ('longlines'))
{
	my $tmp = get_config ('longlines');
	$tmp =~ s/\D//g;
	$LONGLINES = $tmp if ($tmp);
}
if (get_config ('shortlines'))
{
	my $tmp = get_config ('shortlines');
	$tmp =~ s/\D//g;
	if ($tmp or ($tmp == 0))
	{
		$SHORTLINES = $tmp;
	}
}

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
	my $ident = $data->{'ident'};
	my $hour = int ($data->{'hour'});
	my $host = $data->{'host'};
	my $text = $data->{'text'};
	my $type = $data->{'type'};
	my $time = $data->{'epoch'};

	my $words = scalar (@{$data->{'words'}});
	my $chars = length ($text);

	if ($type eq 'ACTION')
	{
		$chars -= (length ($nick) + 3);
	}

	my @counter = $NickLinesCounter->get ($nick);
	if (!@counter)
	{
		@counter = qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0);
	}
	$counter[$hour]++
	$NickLinesCounter->put ($nick, @counter);

	@counter = $NickWordsCounter->get ($nick);
	if (!@counter)
	{
		@counter = qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0);
	}
	$counter[$hour] += $words;
	$NickWordsCounter->put ($nick, @counter);

	@counter = $NickCharsCounter->get ($nick);
	if (!@counter)
	{
		@counter = qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0);
	}
	$counter[$hour] += $chars;
	$NickCharsCounter->put ($nick, @counter);

	if ((length ($text) >= $QuoteMin)
				and (length ($text) <= $QuoteMax))
	{
		if (!defined ($QuoteCache->{$nick}))
		{
			$QuoteCache->{$nick} = [];
		}
		push (@{$QuoteCache->{$nick}}, [$time, $text]);
	}

	if (defined ($QuoteCache->{$nick}))
	{
		while (scalar (@{$QuoteCache->{$nick}}) > $QuoteCache_SIZE)
		{
			shift (@{$QuoteCache->{$nick}});
		}
	}

	return (1);
}

sub calculate
{
	for (get_all_nicks ())
	{
		my $nick = $_;
		my $main = get_main_nick ($nick);

		if (!defined ($NickData->{$main}))
		{
			$NickData->{$main} =
			{
				lines => [qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)],
				words => [qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)],
				chars => [qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)]
			};
		}

		my @counter = $NickLinesCounter->get ($nick);
		if (@counter)
		{
			for (my $i = 0; $i < 24; $i++)
			{
				$NickData->{$main}{'lines'}[$i] += $counter[$i];
			}
		}

		@counter = $NickWordsCounter->get ($nick);
		if (@counter)
		{
			for (my $i = 0; $i < 24; $i++)
			{
				$NickData->{$main}{'words'}[$i] += $counter[$i];
			}
		}

		@counter = $NickWordsCounter->get ($nick);
		if (@counter)
		{
			for (my $i = 0; $i < 24; $i++)
			{
				$NickData->{$main}{'words'}[$i] += $counter[$i];
			}
		}

		if (!defined ($QuoteData->{$main}))
		{
			$QuoteData->{$main} = [];
		}
		if (defined ($QuoteCache->{$nick}))
		{
			my @new = sort (sub { $b->[0] <=> $a->[0] }, @{$QuoteCache->{$nick}}, @{$QuoteData->{$main}});
			splice (@new, $QuoteCache_SIZE) if (scalar (@new) > $QuoteCache_SIZE);
			$QuoteData->{$main} = \@new;
		}
	}
}

sub output
{
	calculate ();
	activetimes ();
	ranking ();
}
	
sub activetimes
{
	my $max = 0;		# the most lines that were written in one hour..
	my $total = 0;		# the total amount of lines we wrote..
	my ($i, $j);		# used in for-loops
	my $factor = 0;		# used to find a bar's height
	my $newline = '';	# buffer variable..

	my @data = @{$DATA->{'byhour'}};

	my @img_urls = get_config ('vertical_images');
	if (!@img_urls)
	{
		@img_urls = qw#images/ver0n.png images/ver1n.png images/ver2n.png images/ver3n.png#;
	}

	my $fh = get_filehandle () or die;
	
# this for loop looks for the most amount of lines in one hour and sets
# $most_lines
	for ($i = 0; $i < 24; $i++)
	{
		if (!defined ($data[$i]))
		{
			next;
		}

		$total += $data[$i];

		if ($data[$i] > $max)
		{
			$max = $data[$i];
		}
	}

	if (!$total)
	{
		$total = 1;
		$max = 1;
	}

	$factor = (($BAR_HEIGHT - 1) / $max);

	my $header = translate ('When do we actually talk here?');
	print $fh "<h2>$header</h2>\n",
	qq#<table class="hours_of_day">\n#,
	qq#  <tr>\n#;

# this for circles through the four colors. Each color represents six hours.
# (4 * 6 hours = 24 hours)
	for ($i = 0; $i <= 3; $i++)
	{
		for ($j = 0; $j <= 5; $j++)
		{
			my $hour = (($i * 6) + $j);
			if (!defined ($data[$hour]))
			{
				$data[$hour] = 0;
			}

			my $percent = 100 * ($data[$hour] / $total);
			my $height = int ($data[$hour] * $factor) + 1;
			my $img_url = $img_urls[$i];
			
			print $fh '    <td>', sprintf ("%2.1f", $percent),
			qq#%<br /><img src="$img_url" style="height: $height#,
			qq#px;" alt="" /></td>\n#;
		}
	}

	print $fh "  </tr>\n",
	qq#  <tr class="hour_row">\n#;
	print $fh map { "    <td>$_</td>\n" } (0 .. 23);
	print $fh "  </tr>\n",
	"</table>\n\n";
}

sub ranking
{
	my $count = 0;

	my @names = grep
	{
		defined ($DATA->{'byname'}{$_}{'words'})
	} (keys (%{$DATA->{'byname'}}));
	
	my $max_lines = 1;
	my $max_words = 1;
	my $max_chars = 1;
	
	my $linescount = 0;

	my $fh = get_filehandle () or die;

	my $sort_field = lc ($SORT_BY);

	my $trans;

	my $tmp;
	($tmp) = sort { $DATA->{'byname'}{$b}{'lines'} <=> $DATA->{'byname'}{$a}{'lines'} } (@names);
	$max_lines = $DATA->{'byname'}{$tmp}{'lines'} || 0;
	
	($tmp) = sort { $DATA->{'byname'}{$b}{'words'} <=> $DATA->{'byname'}{$a}{'words'} } (@names);
	$max_words = $DATA->{'byname'}{$tmp}{'words'} || 0;
	
	($tmp) = sort { $DATA->{'byname'}{$b}{'chars'} <=> $DATA->{'byname'}{$a}{'chars'} } (@names);
	$max_chars = $DATA->{'byname'}{$tmp}{'chars'} || 0;

	$trans = translate ('Most active nicks');
	
	print $fh "<h2>$trans</h2>\n";
	if ($SORT_BY eq 'LINES')
	{
		$trans = translate ('Nicks sorted by numbers of lines written');
	}
	elsif ($SORT_BY eq 'WORDS')
	{
		$trans = translate ('Nicks sorted by numbers of words written');
	}
	else # ($SORT_BY eq 'CHARS')
	{
		$trans = translate ('Nicks sorted by numbers of characters written');
	}
	print $fh "<p>($trans)</p>\n";

	print $fh <<EOF;

<table class="big_ranking">
  <tr>
    <td class="invis">&nbsp;</td>
EOF
	if ($DISPLAY_IMAGES)
	{
		$trans = translate ('Image');
		print $fh "    <th>$trans</th>\n";
	}
	#if (true)
	{
		$trans = translate ('Nick');
		print $fh "    <th>$trans</th>\n";
	}
	if ($DISPLAY_LINES ne 'NONE')
	{
		$trans = translate ('Number of Lines');
		print $fh "    <th>$trans</th>\n";
	}
	if ($DISPLAY_WORDS ne 'NONE')
	{
		$trans = translate ('Number of Words');
		print $fh "    <th>$trans</th>\n";
	}
	if ($DISPLAY_CHARS ne 'NONE')
	{
		$trans = translate ('Number of Characters');
		print $fh "    <th>$trans</th>\n";
	}
	if ($DISPLAY_TIMES)
	{
		$trans = translate ('When?');
		print $fh "    <th>$trans</th>\n";
	}
	
	$trans = translate ('Random Quote');
	print $fh "    <th>$trans</th>\n",
	"  </tr>\n";

	for (sort
	{
		$DATA->{'byname'}{$b}{$sort_field} <=> $DATA->{'byname'}{$a}{$sort_field}
	} (@names))
	{
		my $name = $_;
		my $ident = $name;
		my $nick = $name;

		if (ident_to_nick ($name))
		{
			$nick = ident_to_nick ($name);
		}
		else
		{
			$ident = nick_to_ident ($name);
		}
		
		$linescount++;

		# As long as we didn't hit the 
		# $LONGLINES-limit we continue
		# our table..
		if ($linescount <= $LONGLINES)
		{
			my $quote = translate ('-- no quote available --');

			if (defined ($QuoteCache->{$nick}))
			{
				my $num = scalar (@{$QuoteCache->{$nick}});
				my $rand = int (rand ($num));
				$quote = html_escape ($QuoteCache->{$nick}[$rand]);
			}

			my $link = '';
			my $image = '';
			my $title = '';
			if ($name eq $ident)
			{
				$link = get_link ($name);
				$image = get_image ($name);
				$title = get_name ($name);
			}
			
			print $fh "  <tr>\n",
			qq#    <td class="numeration"># . $linescount . "</td>\n";

			if ($DISPLAY_IMAGES)
			{
				if ($DEFAULT_IMAGE and !$image)
				{
					$image = $DEFAULT_IMAGE;
				}
				
				print $fh qq#    <td class="image">#;
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
			
			if (!$title)
			{
				$title = "Ident: $ident";
			}
			print $fh qq#    <td class="nick" title="$title">#;

			if ($link)
			{
				print $fh qq#<a href="$link">$name</a></td>\n#
			}
			else
			{
				print $fh qq#$name</td>\n#;
			}
		
			if ($DISPLAY_LINES ne 'NONE')
			{
				print $fh qq#    <td class="bar">#;
				if (($DISPLAY_LINES eq 'BOTH') or ($DISPLAY_LINES eq 'BAR'))
				{
					my $code = bar ($max_lines, $DATA->{'byname'}{$name}{'lines_time'});
					print $fh $code;
				}
				print $fh '&nbsp;' if ($DISPLAY_LINES eq 'BOTH');
				if (($DISPLAY_LINES eq 'BOTH') or ($DISPLAY_LINES eq 'NUMBER'))
				{
					print $fh $DATA->{'byname'}{$name}{'lines'};
				}
				print $fh "</td>\n";
			}

			if ($DISPLAY_WORDS ne 'NONE')
			{
				print $fh qq#    <td class="bar">#;
				if (($DISPLAY_WORDS eq 'BOTH') or ($DISPLAY_WORDS eq 'BAR'))
				{
					my $code = bar ($max_words, $DATA->{'byname'}{$name}{'words_time'});
					print $fh $code;
				}
				print $fh '&nbsp;' if ($DISPLAY_WORDS eq 'BOTH');
				if (($DISPLAY_WORDS eq 'BOTH') or ($DISPLAY_WORDS eq 'NUMBER'))
				{
					print $fh $DATA->{'byname'}{$name}{'words'};
				}
				print $fh "</td>\n";
			}

			if ($DISPLAY_CHARS ne 'NONE')
			{
				print $fh qq#    <td class="bar">#;
				if (($DISPLAY_CHARS eq 'BOTH') or ($DISPLAY_CHARS eq 'BAR'))
				{
					my $code = bar ($max_chars, $DATA->{'byname'}{$name}{'chars_time'});
					print $fh $code;
				}
				print $fh '&nbsp;' if ($DISPLAY_CHARS eq 'BOTH');
				if (($DISPLAY_CHARS eq 'BOTH') or ($DISPLAY_CHARS eq 'NUMBER'))
				{
					print $fh $DATA->{'byname'}{$name}{'chars'};
				}
				print $fh "</td>\n";
			}

			if ($DISPLAY_TIMES)
			{
				my $chars = $DATA->{'byname'}{$name}{'chars'};
				my $code = bar ($chars, $DATA->{'byname'}{$name}{'chars_time'});
				
				print $fh qq#    <td class="bar">$code</td>\n#;
			}

			print $fh qq#    <td class="quote">$quote</td>\n#,
			qq#  </tr>\n#;
			
			if ($linescount == $LONGLINES)
			{
				print $fh "</table>\n\n";
			}
		}

		# Ok, we have too many people to
		# list them all so we start a
		# smaller table and just list the
		# names.. (Six names per line..)
		elsif ($linescount <= ($LONGLINES + 6 * $SHORTLINES))
		{
			my $row_in_this_table = int (($linescount - $LONGLINES - 1) / 6);
			my $col_in_this_table = ($linescount - $LONGLINES - 1) % 6;

			my $total = 0;
			if ($SORT_BY eq 'LINES')
			{
				$total = $DATA->{'byname'}{$name}{'lines'};
			}
			elsif ($SORT_BY eq 'WORDS')
			{
				$total = $DATA->{'byname'}{$name}{'words'};
			}
			else # ($SORT_BY eq 'CHARS')
			{
				$total = $DATA->{'byname'}{$name}{'chars'};
			}
			
			if ($row_in_this_table == 0 and $col_in_this_table == 0)
			{
				$trans = translate ("They didn't write so much");
				print $fh "<h2>$trans</h2>\n",
				qq#<table class="small_ranking">\n#,
				qq#  <tr>\n#;
			}
			
			if ($col_in_this_table == 0 and $row_in_this_table != 0)
			{
				print $fh "  </tr>\n",
				qq#  <tr>\n#;
			}
			
			print $fh "    <td>$name ($total)</td>\n";
			
			if ($row_in_this_table == $SHORTLINES and $col_in_this_table == 5)
			{
				print $fh "  </tr>\n",
				qq#</table>\n\n#;
			}
		}

		# There is no else. There are
		# just too many people around.
		# I might add a "There are xyz
		# unmentioned nicks"-line..
	}

	if (($linescount > $LONGLINES)
			and ($linescount <= ($LONGLINES + 6 * $SHORTLINES)))
	{
		my $col = ($linescount - $LONGLINES - 1) % 6;

		while ($col < 5)
		{
			print $fh qq#    <td>&nbsp;</td>\n#;
			$col++;
		}

		print $fh "  </tr>\n";
	}

	if ($linescount != $LONGLINES)
	{
		print $fh "</table>\n\n";
	}
}

# this is called by "&ranking ();" and prints the horizontal usage-bar in the
# detailed nick-table
sub bar
{
	my $max_num = shift;

	my $source = shift;

	# BAR_WIDTH is a least 10
	my $max_width = $BAR_WIDTH - 4;
	my $factor = 1;
	my $retval = '';

	my $i;
	my $j;

	if (!$max_num) { return ($retval); }
	$factor = $max_width / $max_num;

	for ($i = 0; $i < 4; $i++)
	{
		my $sum = 0;
		my $width = 1;
		my $img = $H_IMAGES[$i];

		for ($j = 0; $j < 6; $j++)
		{
			my $hour = ($i * 6) + $j;

			if (defined ($source->{$hour}))
			{
				$sum += $source->{$hour};
			}
		}

		$width += int (0.5 + ($sum * $factor));
		
		$retval .= qq#<img src="$img" style="width: # . $width . q#px"#;
		if ($i == 0) { $retval .= qq# class="first"#; }
		elsif ($i == 3) { $retval .= qq# class="last"#; }
		$retval .= ' alt="" />';
	}

	return ($retval);
}

=head1 AUTHOR

Florian octo Forster, E<lt>octo at verplant.orgE<gt>

=cut
