package Onis::Plugins::Weekdays;

use strict;
use warnings;

use Onis::Config (qw(get_config));
use Onis::Html (qw(get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(register_plugin get_main_nick nick_to_ident nick_to_name));
use Onis::Data::Persistent ();

register_plugin ('TEXT', \&add);
register_plugin ('ACTION', \&add);
register_plugin ('OUTPUT', \&output);

our $WeekdayCache = Onis::Data::Persistent->new ('WeekdayCache', 'nick',
qw(
	sun0 sun1 sun2 sun3
	mon0 mon1 mon2 mon3
	tue0 tue1 tue2 tue3
	wed0 wed1 wed2 wed3
	thu0 thu1 thu2 thu3
	fri0 fri1 fri2 fri3
	sat0 sat1 sat2 sat3
));
our $WeekdayData = {};
our @Weekdays = (qw(sun mon tue wed thu fri sat));

our $BarHeight = 130;
if (get_config ('bar_height'))
{
	my $tmp = get_config ('bar_height');
	$tmp =~ s/\D//g;
	$BarHeight = $tmp if ($tmp >= 10);
}

our @VImages = get_config ('vertical_images');
if (scalar (@VImages) != 4)
{
	@VImages = qw#images/ver0n.png images/ver1n.png images/ver2n.png images/ver3n.png#;
}

my $VERSION = '$Id$';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

sub add
{
	my $data = shift;
	my $nick = $data->{'nick'};
	my $time = $data->{'epoch'};
	my $hour = int ($data->{'hour'} / 6);
	my $chars = length ($data->{'text'});
	my $day   = (localtime ($time))[6];
	my $index = ($day * 4) + $hour;

	my @data = $WeekdayCache->get ($nick) || (qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0));
	$data[$index] += $chars;
	$WeekdayCache->put ($nick, @data);
	
	@data = $WeekdayCache->get ('<TOTAL>') || (qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0));
	$data[$index] += $chars;
	$WeekdayCache->put ('<TOTAL>', @data);
}

sub calculate
{
	for ($WeekdayCache->keys ())
	{
		my $nick = $_;
		my $main = $nick eq '<TOTAL>' ? '<TOTAL>' : get_main_nick ($nick);
		my @data = $WeekdayCache->get ($nick);

		if (!defined ($WeekdayData->{$main}))
		{
			$WeekdayData->{$main} =
			{
				sun => [0, 0, 0, 0],
				mon => [0, 0, 0, 0],
				tue => [0, 0, 0, 0],
				wed => [0, 0, 0, 0],
				thu => [0, 0, 0, 0],
				fri => [0, 0, 0, 0],
				sat => [0, 0, 0, 0]
			};
		}

		for (my $i = 0; $i < 7; $i++)
		{
			my $day = $Weekdays[$i];
			for (my $j = 0; $j < 4; $j++)
			{
				my $idx = ($i * 4) + $j;
				$WeekdayData->{$main}{$day}[$j] += $data[$idx];
			}
		}
	}
}

sub output
{
	calculate ();
	return (undef) unless (%$WeekdayData);

	my @order =
	(
		[1, 'mon', 'Monday'],
		[2, 'tue', 'Tuesday'],
		[3, 'wed', 'Wednesday'],
		[4, 'thu', 'Thursday'],
		[5, 'fri', 'Friday'],
		[6, 'sat', 'Saturday'],
		[0, 'sun', 'Sunday']
	);

	my $data = $WeekdayData->{'<TOTAL>'};

	my $fh = get_filehandle ();
	
	my $max = 0;
	my $bar_factor = 0;

	for (@order)
	{
		my ($num, $abbr, $name) = @$_;
		my $sum = $data->{$abbr}[0] + $data->{$abbr}[1] + $data->{$abbr}[2] + $data->{$abbr}[3];

		$max = $sum if ($max < $sum);
	}
	
	$bar_factor = $BarHeight / $max;
	
	print $fh qq#<table class="plugin weekdays">\n  <tr class="bars">\n#;
	for (@order)
	{
		my ($num, $abbr, $name) = @$_;
		my $sum = $data->{$abbr}[0] + $data->{$abbr}[1] + $data->{$abbr}[2] + $data->{$abbr}[3];

		print $fh qq#    <td class="bar $abbr">$sum<br />\n      #;
		for (my $i = 0; $i < 4; $i++)
		{
			my $num = $data->{$abbr}[$i];
			my $height = int (0.5 + $num * $bar_factor) || 1;
			my $img = $VImages[$i];
			
			print $fh qq(<img src="$img" alt="" style="height: ${height}px;" />);
		}
		print $fh "\n    </td>\n";
	}
	print $fh qq(  </tr>\n  <tr class="numeration">\n);
	for (@order)
	{
		my ($num, $abbr, $name) = @$_;
		print $fh qq(    <td class="numeration $abbr">$name</td>\n);
	}
	print $fh "  </tr>\n</table>\n\n";
}
