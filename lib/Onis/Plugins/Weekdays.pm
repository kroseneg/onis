package Onis::Plugins::Weekdays;

use strict;
use warnings;

use Exporter;

use Onis::Config (qw(get_config));
use Onis::Html (qw(get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(register_plugin get_main_nick nick_to_ident nick_to_name));
use Onis::Data::Persistent ();

=head1 NAME

Onis::Plugins::Weekdays - Activity based on weekdays

=cut

@Onis::Plugins::Weekdays::EXPORT_OK = (qw(get_weekdays));
@Onis::Plugins::Weekdays::ISA = ('Exporter');

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

=head1 CONFIGURATION OPTIONS

=over 4

=item B<vertical_images>: I<image0>, I<image1>, I<image2>, I<image3>;

Sets the images used for vertical bars.

=cut

our @VImages = get_config ('vertical_images');
if (scalar (@VImages) != 4)
{
	@VImages = qw#images/ver0n.png images/ver1n.png images/ver2n.png images/ver3n.png#;
}

=back

=cut

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

	my @data = $WeekdayCache->get ($nick);
	@data = (qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)) unless (@data);
	$data[$index] += $chars;
	$WeekdayCache->put ($nick, @data);
	
	@data = $WeekdayCache->get ('<TOTAL>');
	@data = (qw(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)) unless (@data);
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
	my $total = 0;

	for (@order)
	{
		my ($num, $abbr, $name) = @$_;

		for (my $i = 0; $i < 4; $i++)
		{
			$max = $data->{$abbr}[$i] if ($max < $data->{$abbr}[$i]);
			$total += $data->{$abbr}[$i];
		}
	}
	
	print $fh qq#<table class="plugin weekdays">\n  <tr class="bars">\n#;
	for (@order)
	{
		my ($num, $abbr, $name) = @$_;
		for (my $i = 0; $i < 4; $i++)
		{
			my $num = $data->{$abbr}[$i];
			my $height = sprintf ("%.2f", (95 * $num / $max));
			my $img = $VImages[$i];

			print $fh qq#    <td class="bar vertical $abbr">#,
			qq(<img src="$img" alt="" class="first last" style="height: ${height}%;" /></td>\n);
		}
	}
	print $fh qq(  </tr>\n  <tr class="counter">\n);
	for (@order)
	{
		my ($num, $abbr, $name) = @$_;
		my $sum = $data->{$abbr}[0] + $data->{$abbr}[1] + $data->{$abbr}[2] + $data->{$abbr}[3];
		my $pct = sprintf ("%.1f", (100 * $sum / $total));
		print $fh qq(    <td colspan="4" class="counter $abbr">$pct%</td>\n);
	}
	print $fh qq(  </tr>\n  <tr class="numeration">\n);
	for (@order)
	{
		my ($num, $abbr, $name) = @$_;
		print $fh qq(    <td colspan="4" class="numeration $abbr">$name</td>\n);
	}
	print $fh "  </tr>\n</table>\n\n";
}

=head1 EXPORTED FUNCTIONS

=over 4

=item B<get_weekdays> (I<$nick>)

Returns a hashref with the weekday information for I<$nick>. Numbers are
character counters. The returned data has the following format:

  {
    sun => [0, 0, 0, 0],
    mon => [0, 0, 0, 0],
    tue => [0, 0, 0, 0],
    wed => [0, 0, 0, 0],
    thu => [0, 0, 0, 0],
    fri => [0, 0, 0, 0],
    sat => [0, 0, 0, 0]
  }

=cut

sub get_weekdays
{
	my $nick = shift;

	if (!defined ($WeekdayData->{$nick}))
	{
		return ({});
	}

	return ($WeekdayData->{$nick});
}

=back

=head1 AUTHOR

Florian octo Forster E<lt>octo at verplant.orgE<gt>

=cut
