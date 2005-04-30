package Onis::Plugins::Core;

use strict;
use warnings;

use Carp (qw(confess));
use Exporter;

=head1 NAME

Onis::Plugins::Core

=head1 DESCRIPTION

Plugin for the main table and the hourly-statistics. This is the most
complicated plugin so far.

=cut

use Onis::Config (qw(get_config));
use Onis::Html (qw(html_escape get_filehandle));
use Onis::Language (qw(translate));
use Onis::Users (qw(get_realname get_link get_image chatter_to_name));
use Onis::Data::Core (qw(get_all_nicks nick_to_ident ident_to_nick get_main_nick register_plugin));
use Onis::Data::Persistent ();

@Onis::Plugins::Core::EXPORT_OK = (qw(get_core_nick_counters get_sorted_nicklist nick_is_in_main_table));
@Onis::Plugins::Core::ISA = ('Exporter');

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

our $QuoteCache = Onis::Data::Persistent->new ('QuoteCache', 'key', qw(epoch text));
our $QuotePtr = Onis::Data::Persistent->new ('QuotePtr', 'nick', qw(pointer));

our $QuoteData = {};  # Is generated before output. Nicks are merged according to Data::Core.
our $NickData = {};  # Same as above, but for nicks rather than quotes.
our $SortedNicklist = [];

our $NicksInMainTable = {};

our @HorizontalImages = qw#dark-theme/h-red.png dark-theme/h-blue.png dark-theme/h-yellow.png dark-theme/h-green.png#;
our $QuoteCacheSize = 10;
our $QuoteMin = 30;
our $QuoteMax = 80;
our $SortBy = 'LINES';
our $DisplayLines = 'BOTH';
our $DisplayWords = 'NONE';
our $DisplayChars = 'NONE';
our $DisplayTimes = 0;
our $DisplayImages = 0;
our $DefaultImage = '';
our $LongLines  = 50;
our $ShortLines = 10;

=head1 CONFIGURATION OPTIONS

=over 4

=item B<quote_cache_size>: I<10>

Sets how many quotes are cached and, at the end, one is chosen at random.

=cut

if (get_config ('quote_cache_size'))
{
	my $tmp = get_config ('quote_cache_size');
	$tmp =~ s/\D//g;
	$QuoteCacheSize = $tmp if ($tmp);
}

=item B<quote_min>: I<30>

Minimum number of characters in a line to be included in the quote-cache.

=cut

if (get_config ('quote_min'))
{
	my $tmp = get_config ('quote_min');
	$tmp =~ s/\D//g;
	$QuoteMin = $tmp if ($tmp);
}
=item B<quote_max>: I<80>

Maximum number of characters in a line to be included in the quote-cache.

=cut

if (get_config ('quote_max'))
{
	my $tmp = get_config ('quote_max');
	$tmp =~ s/\D//g;
	$QuoteMax = $tmp if ($tmp);
}

=item B<display_lines>: I<BOTH>

Choses wether to display B<lines> as I<BAR>, I<NUMBER>, I<BOTH> or not at all
(I<NONE>).

=cut

if (get_config ('display_lines'))
{
	my $tmp = get_config ('display_lines');
	$tmp = uc ($tmp);

	if (($tmp eq 'NONE') or ($tmp eq 'BAR') or ($tmp eq 'NUMBER') or ($tmp eq 'BOTH'))
	{
		$DisplayLines = $tmp;
	}
	else
	{
		$tmp = get_config ('display_lines');
		print STDERR $/, __FILE__, ": ``display_lines'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``none'', ``bar'', ``number'' and ``both''. Using default value ``both''.";
	}
}

=item B<display_words>: I<NONE>

See L<display_lines>

=cut

if (get_config ('display_words'))
{
	my $tmp = get_config ('display_words');
	$tmp = uc ($tmp);

	if (($tmp eq 'NONE') or ($tmp eq 'BAR') or ($tmp eq 'NUMBER') or ($tmp eq 'BOTH'))
	{
		$DisplayWords = $tmp;
	}
	else
	{
		$tmp = get_config ('display_words');
		print STDERR $/, __FILE__, ": ``display_words'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``none'', ``bar'', ``number'' and ``both''. Using default value ``none''.";
	}
}

=item B<display_chars>: I<NONE>

See L<display_lines>

=cut

if (get_config ('display_chars'))
{
	my $tmp = get_config ('display_chars');
	$tmp = uc ($tmp);

	if (($tmp eq 'NONE') or ($tmp eq 'BAR') or ($tmp eq 'NUMBER') or ($tmp eq 'BOTH'))
	{
		$DisplayChars = $tmp;
	}
	else
	{
		$tmp = get_config ('display_chars');
		print STDERR $/, __FILE__, ": ``display_chars'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``none'', ``bar'', ``number'' and ``both''. Using default value ``none''.";
	}
}

=item B<display_times>: I<false>

Wether or not to display a fixed width bar that shows when a user is most
active.

=cut

if (get_config ('display_times'))
{
	my $tmp = get_config ('display_times');

	if ($tmp =~ m/true|on|yes/i)
	{
		$DisplayTimes = 1;
	}
	elsif ($tmp =~ m/false|off|no/i)
	{
		$DisplayTimes = 0;
	}
	else
	{
		print STDERR $/, __FILE__, ": ``display_times'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``true'' and ``false''. Using default value ``false''.";
	}
}

=item B<display_images>: I<false>

Wether or not to display images in the main ranking.

=cut

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

=item B<default_image>: I<http://www.url.org/image.png>

Sets the URL to the default image. This is included as-is in the HTML. You have
to take care of (absolute) paths yourself.

=cut

if (get_config ('default_image'))
{
	$DefaultImage = get_config ('default_image');
}

=item B<sort_by>: I<LINES>

Sets by which field the output has to be sorted. This is completely independent
from B<display_lines>, B<display_words> and B<display_chars>. Valid options are
I<LINES>, I<WORDS> and I<CHARS>.

=cut

if (get_config ('sort_by'))
{
	my $tmp = get_config ('sort_by');
	$tmp = uc ($tmp);

	if (($tmp eq 'LINES') or ($tmp eq 'WORDS') or ($tmp eq 'CHARS'))
	{
		$SortBy = $tmp;
	}
	else
	{
		$tmp = get_config ('sort_by');
		print STDERR $/, __FILE__, ": ``sort_by'' has been set to the invalid value ``$tmp''. ",
		$/, __FILE__, ": Valid values are ``lines'' and ``words''. Using default value ``lines''.";
	}
}

=item B<horizontal_images>: I<image1>, I<image2>, I<image3>, I<image4>

Sets the B<four> images used for horizontal bars/graphs. As above: You have to
take care of correctness of paths yourself.

=cut

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

		$HorizontalImages[$i] = $tmp[$i];
	}
}

=item B<longlines>: I<50>

Sets the number of rows of the main ranking table.

=cut

if (get_config ('longlines'))
{
	my $tmp = get_config ('longlines');
	$tmp =~ s/\D//g;
	$LongLines = $tmp if ($tmp);
}

=item B<shortlines>: I<10>

Sets the number of rows of the "they didn't write so much" table. There are six
persons per line; you set the number of lines.

=over

=cut

if (get_config ('shortlines'))
{
	my $tmp = get_config ('shortlines');
	$tmp =~ s/\D//g;
	if ($tmp or ($tmp == 0))
	{
		$ShortLines = $tmp;
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
	$counter[$hour]++;
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
		my ($pointer) = $QuotePtr->get ($nick);
		$pointer ||= 0;

		my $key = sprintf ("%s:%02i", $nick, $pointer);

		$QuoteCache->put ($key, $time, $text);

		$pointer = ($pointer + 1) % $QuoteCacheSize;
		$QuotePtr->put ($nick, $pointer);
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
				chars => [qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)],
				lines_total => 0,
				words_total => 0,
				chars_total => 0
			};
		}

		my @counter = $NickLinesCounter->get ($nick);
		if (@counter)
		{
			my $sum = 0;
			for (my $i = 0; $i < 24; $i++)
			{
				$NickData->{$main}{'lines'}[$i] += $counter[$i];
				$sum += $counter[$i];
			}
			$NickData->{$main}{'lines_total'} += $sum;
		}

		@counter = $NickWordsCounter->get ($nick);
		if (@counter)
		{
			my $sum = 0;
			for (my $i = 0; $i < 24; $i++)
			{
				$NickData->{$main}{'words'}[$i] += $counter[$i];
				$sum += $counter[$i];
			}
			$NickData->{$main}{'words_total'} += $sum;
		}

		@counter = $NickCharsCounter->get ($nick);
		if (@counter)
		{
			my $sum = 0;
			for (my $i = 0; $i < 24; $i++)
			{
				$NickData->{$main}{'chars'}[$i] += $counter[$i];
				$sum += $counter[$i];
			}
			$NickData->{$main}{'chars_total'} += $sum;
		}

		if (!defined ($QuoteData->{$main}))
		{
			$QuoteData->{$main} = [];
		}
	}

	for ($QuoteCache->keys ())
	{
		my $key = $_;
		my ($nick, $num) = split (m/:/, $key);
		my $main = get_main_nick ($nick);

		my ($epoch, $text) = $QuoteCache->get ($key);
		die unless (defined ($text));

		if (!defined ($QuoteData->{$main}))
		{
			next;
		}
		elsif (scalar (@{$QuoteData->{$main}}) < $QuoteCacheSize)
		{
			push (@{$QuoteData->{$main}}, [$epoch, $text]);
		}
		else
		{
			my $insert = -1;
			my $min = $epoch;

			for (my $i = 0; $i < $QuoteCacheSize; $i++)
			{
				if ($QuoteData->{$main}[$i][0] < $min)
				{
					$insert = $i;
					$min = $QuoteData->{$main}[$i][0];
				}
			}

			if ($insert != -1)
			{
				$QuoteData->{$main}[$insert] = [$epoch, $text];
			}
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

	my @data = qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0);

	my @img_urls = get_config ('vertical_images');
	if (!@img_urls)
	{
		@img_urls = qw#images/ver0n.png images/ver1n.png images/ver2n.png images/ver3n.png#;
	}

	my $fh = get_filehandle () or die;
	
# this for loop looks for the most amount of lines in one hour and sets
# $most_lines
	for (keys %$NickData)
	{
		my $nick = $_;

		for (my $i = 0; $i < 24; $i++)
		{
			$data[$i] += $NickData->{$nick}{'chars'}[$i];
		}
	}

	for (my $i = 0; $i < 24; $i++)
	{
		$max = $data[$i] if ($max < $data[$i]);
		$total += $data[$i];
	}

	if (!$total)
	{
		$total = 1;
		$max = 1;
	}

	my $header = translate ('When do we actually talk here?');
	print $fh "<h2>$header</h2>\n",
	qq#<table class="hours">\n#,
	qq#  <tr class="bars">\n#;

# this for circles through the four colors. Each color represents six hours.
# (4 * 6 hours = 24 hours)
	for (my $i = 0; $i <= 3; $i++)
	{
		for (my $j = 0; $j < 6; $j++)
		{
			my $hour = (($i * 6) + $j);
			if (!defined ($data[$hour]))
			{
				$data[$hour] = 0;
			}

			my $height  = sprintf ("%.2f", 95 * $data[$hour] / $max);
			my $img = $img_urls[$i];
			
			print $fh qq#    <td class="bar vertical"><img src="$img" class="first last" style="height: $height\%;" alt="" /></td>\n#;
		}
	}
	print $fh qq#  </tr>\n  <tr class="counter">\n#;
	for (my $i = 0; $i < 24; $i++)
	{
		my $percent = sprintf ("%.1f", 100 * $data[$i] / $total);
		print $fh qq#    <td class="counter">$percent\%</td>\n#;
	}

	print $fh "  </tr>\n",
	qq#  <tr class="numeration">\n#;
	print $fh map { qq#    <td class="numeration">$_</td>\n# } (0 .. 23);
	print $fh "  </tr>\n",
	"</table>\n\n";
}

sub ranking
{
	my $count = 0;

	my @nicks = keys (%$NickData);

	return unless (@nicks);
	
	my $max_lines = 1;
	my $max_words = 1;
	my $max_chars = 1;
	
	my $linescount = 0;

	my $fh = get_filehandle () or die;

	my $sort_field = lc ($SortBy);

	my $trans;

	my $tmp;
	($tmp) = sort { $NickData->{$b}{'lines_total'} <=> $NickData->{$a}{'lines_total'} } (@nicks);
	$max_lines = $NickData->{$tmp}{'lines_total'} || 0;
	
	($tmp) = sort { $NickData->{$b}{'words_total'} <=> $NickData->{$a}{'words_total'} } (@nicks);
	$max_words = $NickData->{$tmp}{'words_total'} || 0;
	
	($tmp) = sort { $NickData->{$b}{'chars_total'} <=> $NickData->{$a}{'chars_total'} } (@nicks);
	$max_chars = $NickData->{$tmp}{'chars_total'} || 0;
	
	$trans = translate ('Most active nicks');
	
	print $fh "<h2>$trans</h2>\n";
	if ($SortBy eq 'LINES')
	{
		$trans = translate ('Nicks sorted by numbers of lines written');
	}
	elsif ($SortBy eq 'WORDS')
	{
		$trans = translate ('Nicks sorted by numbers of words written');
	}
	else # ($SortBy eq 'CHARS')
	{
		$trans = translate ('Nicks sorted by numbers of characters written');
	}
	print $fh "<p>($trans)</p>\n";

	print $fh <<EOF;

<table class="big_ranking">
  <tr>
    <td class="invis">&nbsp;</td>
EOF
	if ($DisplayImages)
	{
		$trans = translate ('Image');
		print $fh "    <th>$trans</th>\n";
	}
	#if (true)
	{
		$trans = translate ('Nick');
		print $fh "    <th>$trans</th>\n";
	}
	if ($DisplayLines ne 'NONE')
	{
		my $span = $DisplayLines eq 'BOTH' ? ' colspan="2"' : '';
		$trans = translate ('Number of Lines');
		print $fh "    <th$span>$trans</th>\n";
	}
	if ($DisplayWords ne 'NONE')
	{
		my $span = $DisplayWords eq 'BOTH' ? ' colspan="2"' : '';
		$trans = translate ('Number of Words');
		print $fh "    <th$span>$trans</th>\n";
	}
	if ($DisplayChars ne 'NONE')
	{
		my $span = $DisplayChars eq 'BOTH' ? ' colspan="2"' : '';
		$trans = translate ('Number of Characters');
		print $fh "    <th$span>$trans</th>\n";
	}
	if ($DisplayTimes)
	{
		$trans = translate ('When?');
		print $fh "    <th>$trans</th>\n";
	}
	
	$trans = translate ('Random Quote');
	print $fh "    <th>$trans</th>\n",
	"  </tr>\n";

	@$SortedNicklist = sort
	{
		$NickData->{$b}{"${sort_field}_total"} <=> $NickData->{$a}{"${sort_field}_total"}
	} (@nicks);

	@nicks = ();

	for (@$SortedNicklist)
	{
		my $nick = $_;
		my $ident = nick_to_ident ($nick);
		my $name  = chatter_to_name ("$nick!$ident");
		my $print = $name || $nick;

		$linescount++;

		# As long as we didn't hit the 
		# $LongLines-limit we continue
		# our table..
		if ($linescount <= $LongLines)
		{
			$NicksInMainTable->{$nick} = $linescount;
			
			my $quote = translate ('-- no quote available --');

			if (@{$QuoteData->{$nick}})
			{
				my $num = scalar (@{$QuoteData->{$nick}});
				my $rand = int (rand ($num));

				$quote = html_escape ($QuoteData->{$nick}[$rand][1]);
			}

			my $link = '';
			my $image = '';
			my $realname = '';
			if ($name)
			{
				$link     = get_link ($name);
				$image    = get_image ($name);
				$realname = get_realname ($name);
			}
			
			print $fh "  <tr>\n",
			qq#    <td class="numeration"># . $linescount . "</td>\n";

			if ($DisplayImages)
			{
				if ($DefaultImage and !$image)
				{
					$image = $DefaultImage;
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
			
			my $title = $realname;
			if (!$title)
			{
				$title = "User: $name; " if ($name);
				$title .= "Ident: $ident";
			}
			print $fh qq#    <td class="nick" title="$title">#;

			if ($link)
			{
				print $fh qq#<a href="$link">$print</a></td>\n#
			}
			else
			{
				print $fh qq#$print</td>\n#;
			}
		
			if ($DisplayLines ne 'NONE')
			{
				if (($DisplayLines eq 'BOTH') or ($DisplayLines eq 'NUMBER'))
				{
					my $num = $NickData->{$nick}{'lines_total'};
					print $fh qq(    <td class="counter">$num</td>\n);
				}
				if (($DisplayLines eq 'BOTH') or ($DisplayLines eq 'BAR'))
				{
					my $code = bar ($max_lines, $NickData->{$nick}{'lines'});
					print $fh qq(    <td class="bar horizontal">$code</td>\n);
				}
			}

			if ($DisplayWords ne 'NONE')
			{
				if (($DisplayWords eq 'BOTH') or ($DisplayWords eq 'NUMBER'))
				{
					my $num = $NickData->{$nick}{'words_total'};
					print $fh qq(    <td class="counter">$num</td>\n);
				}
				if (($DisplayWords eq 'BOTH') or ($DisplayWords eq 'BAR'))
				{
					my $code = bar ($max_words, $NickData->{$nick}{'words'});
					print $fh qq(    <td class="bar horizontal">$code</td>\n);
				}
			}

			if ($DisplayChars ne 'NONE')
			{
				if (($DisplayChars eq 'BOTH') or ($DisplayChars eq 'NUMBER'))
				{
					my $num = $NickData->{$nick}{'chars_total'};
					print $fh qq(    <td class="counter">$num</td>\n);
				}
				if (($DisplayChars eq 'BOTH') or ($DisplayChars eq 'BAR'))
				{
					my $code = bar ($max_chars, $NickData->{$nick}{'chars'});
					print $fh qq(    <td class="bar horizontal">$code</td>\n);
				}
			}

			if ($DisplayTimes)
			{
				my $code = bar ($NickData->{$nick}{'chars_total'}, $NickData->{$nick}{'chars'});
				print $fh qq#    <td class="bar horizontal">$code</td>\n#;
			}

			print $fh qq#    <td class="quote">$quote</td>\n#,
			qq#  </tr>\n#;
			
			if ($linescount == $LongLines)
			{
				print $fh "</table>\n\n";
			}
		}

		# Ok, we have too many people to
		# list them all so we start a
		# smaller table and just list the
		# names.. (Six names per line..)
		elsif ($linescount <= ($LongLines + 6 * $ShortLines))
		{
			my $row_in_this_table = int (($linescount - $LongLines - 1) / 6);
			my $col_in_this_table = ($linescount - $LongLines - 1) % 6;

			my $total = 0;
			if ($SortBy eq 'LINES')
			{
				$total = $NickData->{$nick}{'lines_total'};
			}
			elsif ($SortBy eq 'WORDS')
			{
				$total = $NickData->{$nick}{'words_total'};
			}
			else # ($SortBy eq 'CHARS')
			{
				$total = $NickData->{$nick}{'chars_total'};
			}

			my $title = $name ? get_realname ($name) : '';
			if (!$title)
			{
				$title = "User: $name; " if ($name);
				$title .= "Ident: $ident";
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
			
			print $fh qq#    <td title="$title">$print ($total)</td>\n#;
			
			if ($row_in_this_table == $ShortLines and $col_in_this_table == 5)
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

	if (($linescount > $LongLines)
			and ($linescount <= ($LongLines + 6 * $ShortLines)))
	{
		my $col = ($linescount - $LongLines - 1) % 6;

		while ($col < 5)
		{
			print $fh qq#    <td>&nbsp;</td>\n#;
			$col++;
		}

		print $fh "  </tr>\n";
	}

	if ($linescount != $LongLines)
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

	confess () unless (ref ($source) eq 'ARRAY');

	my $retval = '';

	my $i;
	my $j;

	for ($i = 0; $i < 4; $i++)
	{
		my $sum = 0;
		my $img = $HorizontalImages[$i];
		my $width;

		for ($j = 0; $j < 6; $j++)
		{
			my $hour = ($i * 6) + $j;
			$sum += $source->[$hour];
		}

		$width = sprintf ("%.2f", 95 * $sum / $max_num);
		
		$retval .= qq#<img src="$img" style="width: $width%;"#;
		if ($i == 0) { $retval .= qq# class="first"#; }
		elsif ($i == 3) { $retval .= qq# class="last"#; }
		$retval .= qq( alt="$sum" />);
	}

	return ($retval);
}

=head1 EXPORTED FUNCTIONS

=over 4

=item B<get_core_nick_counters> (I<$nick>)

Returns a hash-ref that containes all the nick-counters available. It looks
like this:

    {
        lines => [qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)],
	words => [qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)],
	chars => [qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)],
	lines_total => 0,
	words_total => 0,
	chars_total => 0
    }

=cut

sub get_core_nick_counters
{
	my $nick = shift;

	if (!defined ($NickData->{$nick}))
	{
		return ({});
	}

	return ($NickData->{$nick});
}

=item B<get_sorted_nicklist> ()

Returns an array-ref that containes all nicks, sorted by the field given in the
config-file.

=cut

sub get_sorted_nicklist
{
	return ($SortedNicklist);
}

=item B<nick_is_in_main_table> (I<$nick>)

Returns the position of the nick in the main table or zero if it is not in the
main table.

=cut

sub nick_is_in_main_table
{
	my $nick = shift;

	return (defined ($NicksInMainTable->{$nick}) ? $NicksInMainTable->{$nick} : 0);
}

=back

=head1 AUTHOR

Florian octo Forster E<lt>octo at verplant.orgE<gt>

=cut
