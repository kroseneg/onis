package Onis::Plugins::Longterm;

use strict;
use warnings;

use Exporter;

use Onis::Config (qw(get_config));
use Onis::Html (qw(get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(register_plugin get_main_nick get_most_recent_time nick_to_ident nick_to_name));
use Onis::Data::Persistent ();

=head1 NAME

Onis::Plugins::Longterm

=cut

@Onis::Plugins::Longterm::EXPORT_OK = (qw(get_longterm));
@Onis::Plugins::Longterm::ISA = ('Exporter');

register_plugin ('TEXT', \&add);
register_plugin ('ACTION', \&add);
register_plugin ('OUTPUT', \&output);

our $LongtermLastSeen = Onis::Data::Persistent->new ('LongtermLastSeen', 'nick', 'day');
our $LongtermCache    = Onis::Data::Persistent->new ('LongtermCache', 'key', qw(time0 time1 time2 time3));
our $LongtermData     = {};

=head1 CONFIGURATION OPTIONS

=over 4

=item B<vertical_images>: I<image0>, I<image1>, I<image2>, I<image3>;

Sets the images to use for vertical graphs.

=cut

our @VImages = get_config ('vertical_images');
if (scalar (@VImages) != 4)
{
	@VImages = qw#images/ver0n.png images/ver1n.png images/ver2n.png images/ver3n.png#;
}

=item B<longterm_days>: I<31>;

Sets the number of days displayed by this plugin.

=cut

our $DisplayDays = 31;
if (get_config ('longterm_days'))
{
	my $tmp = get_config ('longterm_days');
	$tmp =~ s/\D//g;
	$DisplayDays = $tmp if ($tmp);
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
	my $day   = int ($time / 86400);
	my $index = ($day * 4) + $hour;

	my ($lastseen) = $LongtermLastSeen->get ($nick);
	$lastseen ||= $day;
	
	for (my $i = $lastseen; $i < $day; $i++)
	{
		my $last = $i - $DisplayDays;
		$LongtermCache->del ($nick . ':' . $last);

		if ($i != $lastseen)
		{
			$LongtermCache->put ($nick . ':' . $i, qw(0 0 0 0));
		}
	}

	my @data = $LongtermCache->get ($nick . ':' . $day);
	@data = (qw(0 0 0 0)) unless (@data);
	$data[$hour] += $chars;
	$LongtermCache->put ($nick . ':' . $day, @data);

	$LongtermLastSeen->put ($nick, $day);
}

sub calculate
{
	my $now_epoch = get_most_recent_time ();
	my $now = int ($now_epoch / 86400);
	return unless ($now);

	my $old = 1 + $now - $DisplayDays;

	my $del = {};

	for ($LongtermLastSeen->keys ())
	{
		my $nick = $_;
		my ($last) = $LongtermLastSeen->get ($nick);

		if ($last < $old)
		{
			$del->{$nick} = $last;
			$LongtermLastSeen->del ($nick);
		}
	}
	
	for ($LongtermCache->keys ())
	{
		my $key = $_;
		my ($nick, $day) = split (m/:/, $key);

		if (defined ($del->{$nick}) or ($day < $old))
		{
			$LongtermCache->del ($key);
			next;
		}

		my $idx = $day - $old;
		my $main = get_main_nick ($nick);
		my @data = $LongtermCache->get ($key);
		
		if (!defined ($LongtermData->{$main}))
		{
			$LongtermData->{$main} = [];
			$LongtermData->{$main}[$_] = [0, 0, 0, 0] for (0 .. ($DisplayDays - 1));
		}
		if (!defined ($LongtermData->{'<TOTAL>'}))
		{
			$LongtermData->{'<TOTAL>'} = [];
			$LongtermData->{'<TOTAL>'}[$_] = [0, 0, 0, 0] for (0 .. ($DisplayDays - 1));
		}

		$LongtermData->{$main}[$idx][$_] += $data[$_] for (0 .. 3);
		$LongtermData->{'<TOTAL>'}[$idx][$_] += $data[$_] for (0 .. 3);
	}
}

sub output
{
	calculate ();
	return (undef) unless (%$LongtermData);

	my $now_epoch = get_most_recent_time ();
	my $now = int ($now_epoch / 86400);
	return unless ($now);

	my $old = 1 + $now - $DisplayDays;

	my $data = $LongtermData->{'<TOTAL>'};

	my @weekdays = (qw(sun mon tue wed thu fri sat sun));

	my $fh = get_filehandle ();
	
	my $max = 0;
	my $total = 0;

	for (my $i = 0; $i < $DisplayDays; $i++)
	{
		for (my $j = 0; $j < 4; $j++)
		{
			$max = $data->[$i][$j] if ($max < $data->[$i][$j]);
			$total += $data->[$i][$j];
		}
	}
	
	print $fh qq#<table class="plugin longterm">\n  <tr class="bars">\n#;
	for (my $i = 0; $i < $DisplayDays; $i++)
	{
		for (my $j = 0; $j < 4; $j++)
		{
			my $num = $data->[$i][$j];
			my $height = sprintf ("%.2f", (95 * $num / $max));
			my $img = $VImages[$j];

			print $fh qq#    <td class="bar vertical">#,
			qq(<img src="$img" alt="" class="first last" style="height: ${height}%;" /></td>\n);
		}
	}
	print $fh qq(  </tr>\n  <tr class="counter">\n);
	for (my $i = 0; $i < $DisplayDays; $i++)
	{
		my $sum = $data->[$i][0] + $data->[$i][1] + $data->[$i][2] + $data->[$i][3];
		my $percent = sprintf ("%.1f", 100 * $sum / $total);

		print $fh qq(    <td colspan="4" class="counter">$percent%</td>\n);
	}
	print $fh qq(  </tr>\n  <tr class="numeration">\n);
	for (my $i = 0; $i < $DisplayDays; $i++)
	{
		my $epoch = ($old + $i) * 86400;
		my ($day, $wd) = (localtime ($epoch))[3,6];
		my $class = $weekdays[$wd];
		
		print $fh qq(    <td colspan="4" class="numeration $class">$day.</td>\n);
	}
	print $fh "  </tr>\n</table>\n\n";
}

=head1 EXPORTED FUNCTIONS

=over 4

=item B<get_longterm> (I<$nick>)

Returns the longterm-statistics for I<$nick>. The numbers are array-counters.
The format is as follows:

  [
    [0, 0, 0, 0], # oldest day
    ...,
    [0, 0, 0, 0], # yesterday
    [0, 0, 0, 0]  # today
  ]

=cut

sub get_longterm
{
	my $nick = shift;

	if (!defined ($LongtermData->{$nick}))
	{
		return ([]);
	}

	return ($LongtermData->{$nick});
}

=back

=head1 AUTHOR

Florian octo Forster E<lt>octo at verplant.orgE<gt>

=cut
