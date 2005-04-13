package Onis::Html;

use strict;
use warnings;
use Fcntl qw/:flock/;
use Exporter;
use Onis::Config qw/get_config/;
use Onis::Language qw/translate/;
use Onis::Data::Core qw#get_channel get_total_lines#;

@Onis::Html::EXPORT_OK = qw/open_file close_file get_filehandle html_escape/;
@Onis::Html::ISA = ('Exporter');

our $fh;
our $time_start = time ();

our $WANT_COLOR = 0;
our $PUBLIC_PAGE = 1;

if (get_config ('color_codes'))
{
	my $temp = get_config ('color_codes');
	if (($temp eq 'print') or ($temp eq 'true')
			or ($temp eq 'yes')
			or ($temp eq 'on'))
	{
		$WANT_COLOR = 1;
	}
}
if (get_config ('public_page'))
{
	my $temp = get_config ('public_page');

	if ($temp =~ m/false|off|no/i)
	{
		$PUBLIC_PAGE = 0;
	}
}

# `orange' is not a plain html name.
# The color we want is #FFA500
our @mirc_colors = qw/white black navy green red maroon purple orange
			yellow lime teal aqua blue fuchsia gray silver/;

my $VERSION = '$Id: Html.pm,v 1.20 2004/09/16 10:30:20 octo Exp $';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

sub get_filehandle
{
	return ($fh);
}

sub open_file
{
	my $file = shift;

	if (defined ($fh))
	{
		print STDERR $/, __FILE__, ": Not opening file ``$file'': Another file is already open!";
		return (undef);
	}

	unless (open ($fh, "> $file"))
	{
		print STDERR $/, __FILE__, ": Unable to open file ``$file'': $!";
		return (undef);
	}

	unless (flock ($fh, LOCK_EX))
	{
		print STDERR $/, __FILE__, ": Unable to exclusive lock file ``$file'': $!";
		close ($fh);
		return (undef);
	}

	print_head ();

	return ($fh);
}

# Generates the HTML header including the CSS information.
# Doesn't take any arguments
sub print_head
{
	my $generated_time = scalar (localtime ($time_start));
	my $trans;

	my $stylesheet = 'style.css';
	if (get_config ('stylesheet'))
	{
		$stylesheet = get_config ('stylesheet');
	}

	my $encoding = 'iso-8859-1';
	if (get_config ('encoding'))
	{
		$encoding = get_config ('encoding');
	}

	my $user = 'onis';
	if (get_config ('user'))
	{
		$user = get_config ('user');
	}
	elsif (defined ($ENV{'USER'}))
	{
		$user = $ENV{'USER'};
	}

	my $channel = get_channel ();

	my @images = get_config ('horizontal_images');
	if (!@images)
	{
		@images = qw#images/hor0n.png images/hor1n.png images/hor2n.png images/hor3n.png#;
	}
	
	$trans = translate ('%s statistics created by %s');
	my $title = sprintf ($trans, $channel, $user);


	print $fh <<EOF;
<?xml version="1.0" encoding="$encoding"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
	"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
  <title>$title</title>
  <meta http-equiv="Cache-Control" content="public, must-revalidiate" />
  <link rel="stylesheet" type="text/css" href="$stylesheet" />
</head>

<body>

<div class="msie_hack">
EOF

	$trans = translate ('%s stats by %s');
	$title = sprintf ($trans, $channel, $user);
	
	$trans = translate ('Statistics generated on %s');
	my $time_msg = sprintf ($trans, $generated_time);

	$trans = translate ('Hours');
	
	print $fh <<EOF;
<h1>$title</h1>
<p>$time_msg</p>

<table class="legend">
  <tr>
    <td><img src="$images[0]" alt="Red"   /><br />$trans 0-5</td>
    <td><img src="$images[1]" alt="Green" /><br />$trans 6-11</td>
    <td><img src="$images[2]" alt="Blue"  /><br />$trans 12-17</td>
    <td><img src="$images[3]" alt="Red"   /><br />$trans 18-24</td>
  </tr>
</table>

EOF
}

# this routine adds a box to the end of the html-
# page with onis' homepage URL, the author's name
# and email-address. Feel free to uncomment the
# creation of this box if it's appereance nags
# you..
sub close_file
{
	my $runtime = time () - $time_start;
	my $now = scalar (localtime ());
	my $total_lines = get_total_lines () || 0;
	my $lines_per_sec = 'infinite';

	my $hp    = translate ("onis' homepage");
	my $gen   = translate ('This page was generated <span>on %s</span> <span>with %s</span>');
	my $stats = translate ('%u lines processed in %u seconds (%s lines per second)');
	my $by    = translate ('onis is written %s <span>by %s</span>');
	my $link  = translate ('Get the latest version from %s');
	
	my $lps = translate ('infinite');
	if ($runtime)
	{
		$lps = sprintf ("%.1f", ($total_lines / $runtime));
	}

	print $fh <<EOF;
</div> <!-- class="msie_hack" -->
<!-- This script is under GPL (GNU public license). You may copy and modify it. -->

<table class="copy">
  <tr>
EOF
	print  $fh '    <td class="left">';
	printf $fh ($gen, $now, "onis $::VERSION (&quot;onis not irc stats&quot;)");
	print  $fh "<br />\n      ";
	printf $fh ($stats, $total_lines, $runtime, $lps);
	print  $fh qq#\n    </td>\n    <td class="right">\n      #;
	printf $fh ($by, '2000-2004', '<a href="http://verplant.org/">Florian octo Forster</a></span> <span>&lt;octo@<span class="spam">nospam.</span>verplant.org&gt;');
	print  $fh qq#<img id="smalllogo" src="http://images.verplant.org/onis-small.png" /># if ($PUBLIC_PAGE);
	print  $fh "<br />\n      ";
	printf $fh ($link, sprintf (qq#<a href="http://verplant.org/onis/">%s</a>#, $hp));
	
	print $fh <<EOF;

    </td>
  </tr>
</table>

</body>
</html>
EOF
}

sub html_escape
{
	my @retval = ();

	foreach (@_)
	{
		my $esc = escape_uris ($_);
		push (@retval, $esc);
	}

	if (wantarray ())
	{
		return @retval;
	}
	else
	{
		return join ("\n", @retval);
	}
}

sub escape_uris
{
	my $text = shift;
	my $retval = '';

	return ('') if (!defined ($text));

	#if ($text =~ m#(?:(?:ftp|https?)://|www\.)[\w\.-]+\.[A-Za-z]{2,4}(?::\d+)?(?:/[\w\d\.\%/-~]+)?(?=\W|$)#i)
	if ($text =~ m#(?:(?:ftp|https?)://|www\.)[\w\.-]+\.[A-Za-z]{2,4}(?::\d+)?(?:/[\w\d\.\%\/\-\~]*(?:\?[\+\w\&\%\=]+)?)?(?=\W|$)#i)
	{
		my $orig_match = $&;
		my $prematch = $`;
		my $postmatch = $';

		my $match = $orig_match;
		if ($match =~ /^www/i) { $match = 'http://' . $match; }
		if ($match !~ m#://.+/#) { $match .= '/'; }

		if ((length ($orig_match) > 50) and ($orig_match =~ m#^http://#))
		{
			$orig_match =~ s#^http://##;
		}
		if (length ($orig_match) > 50)
		{
			my $len = length ($orig_match) - 47;
			substr ($orig_match, 47, $len, '...');
		}

		$retval = escape_normal ($prematch);
		$retval .= qq(<a href="$match">$orig_match</a>);
		$retval .= escape_uris ($postmatch);
	}
	else
	{
		$retval = escape_normal ($text);
	}

	return ($retval);
}

sub escape_normal
{
	my $text = shift;

	return ('') if (!defined ($text));
	
	$text =~ s/\&/\&amp;/g;
	$text =~ s/"/\&quot;/g;
	$text =~ s/</\&lt;/g;
	$text =~ s/>/\&gt;/g;

	# german umlauts
	$text =~ s/ä/\&auml;/g;
	$text =~ s/ö/\&ouml;/g;
	$text =~ s/ü/\&uuml;/g;
	$text =~ s/Ä/\&Auml;/g;
	$text =~ s/Ü/\&Ouml;/g;
	$text =~ s/Ö/\&Uuml;/g;
	$text =~ s/ß/\&szlig;/g;

	if ($WANT_COLOR)
	{
		$text = find_colors ($text);
	}
	else
	{
		$text =~ s/[\cB\c_\cV\cO]|\cC(?:\d+(?:,\d+)?)?//g;
	}

	return ($text);
}

sub find_colors
{
	my $string = shift;
	my $open_spans = 0;

	my $code_ref;

	my %flags =
	(
		span_open	=>	0,
		fg_color	=>	-1,
		bg_color	=>	-1,
		bold		=>	0,
		underline	=>	0,
		'reverse'	=>	0
	);

	while ($string =~ m/([\cB\c_\cV\cO])|(\cC)(?:(\d+)(?:,(\d+))?)?/g)
	{
		my $controlchar = $1 ? $1 : $2;
		my $fg = defined ($3) ? $3 : -1;
		my $bg = defined ($4) ? $4 : -1;

		my $prematch  = $`;
		my $postmatch = $';
		
		my $newspan = "";

		# Close open spans first
		if ($flags{'span_open'})
		{
			$newspan .= "</span>";
			$flags{'span_open'} = 0;
		}

		# To catch `\cC' without anything following..
		if (($controlchar eq "\cC") and ($fg == -1) and ($bg == -1))
		{
			$flags{'fg_color'} = -1;
			$flags{'bg_color'} = -1;
		}
		elsif ($controlchar eq "\cC")
		{
			if ($fg != -1)
			{
				$flags{'fg_color'} = $fg % scalar (@mirc_colors);
			}
			if ($bg != -1)
			{
				$flags{'bg_color'} = $bg % scalar (@mirc_colors);
			}
		}
		elsif ($controlchar eq "\cB")
		{
			$flags{'bold'} = 1 - $flags{'bold'};
		}
		elsif ($controlchar eq "\c_")
		{
			$flags{'underline'} = 1 - $flags{'underline'};
		}
		elsif ($controlchar eq "\cV")
		{
			$flags{'reverse'} = 1 - $flags{'reverse'};
		}
		# reset
		elsif ($controlchar eq "\cO")
		{
			$flags{'fg_color'} = -1;
			$flags{'bg_color'} = -1;
			$flags{'bold'} = 0;
			$flags{'underline'} = 0;
			$flags{'reverse'} = 0;
		}

		# build the new span-tag
		if (($flags{'fg_color'} != -1) || ($flags{'bg_color'} != -1)
			|| $flags{'bold'} || $flags{'underline'})
		{
			my $fg = $flags{'fg_color'};
			my $bg = $flags{'bg_color'};
			my @style = ();

			if ($flags{'reverse'} and ($bg != -1))
			{
				$fg = $flags{'bg_color'};
				$bg = $flags{'fg_color'};
			}

			if ($fg != -1)
			{
				push (@style, 'color: ' . $mirc_colors[$fg] . ';');
			}
			if ($bg != -1)
			{
				push (@style, 'background-color: ' . $mirc_colors[$bg] . ';');
			}
			if ($flags{'bold'})
			{
				push (@style, 'font-weight: bold;');
			}
			if ($flags{'underline'})
			{
				push (@style, 'text-decoration: underline;');
			}
			
			$newspan .= '<span style="' . join (' ', @style) . '">';
			$flags{'span_open'} = 1;
		}

		$string = $prematch . $newspan . $postmatch;
	}
	
	if ($flags{'span_open'})
	{
		$string .= "</span>";
		$flags{'span_open'} = 0;
	}
	
	return ($string);
}
