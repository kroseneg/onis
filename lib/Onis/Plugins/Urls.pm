package Onis::Plugins::Urls;

use strict;
use warnings;

use Onis::Config (qw(get_config));
use Onis::Html (qw(html_escape get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(register_plugin get_main_nick));
use Onis::Data::Persistent ();
use Onis::Users (qw(nick_to_name));

register_plugin ('TEXT', \&add);
register_plugin ('ACTION', \&add);
register_plugin ('TOPIC', \&add);
register_plugin ('OUTPUT', \&output);

our $URLCache = Onis::Data::Persistent->new ('URLCache', 'url', qw(counter lastusedtime lastusedby));
our $URLData = [];

my $VERSION = '$Id$';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

sub add
{
	my $data = shift;
	my $text = $data->{'text'};
	my $nick = $data->{'nick'};
	my $time = $data->{'epoch'};
	
	while ($text =~ m#(?:(?:ftp|https?)://|www\.)[\w\.-]+\.[A-Za-z]{2,4}(?::\d+)?(?:/[\w\d\.\%\/\-\~]*(?:\?[\+\w\&\%\=]+)?)?(?=\W|$)#ig)
	{
		my $match = $&;

		if ($match =~ m/^www/) { $match = 'http://' . $match; }
		if ($match !~ m#://[^/]+/#) { $match .= '/'; }
		
		my ($counter) = $URLCache->get ($match);
		$counter ||= 0;
		$counter++;
		$URLCache->put ($match, $counter, $time, $nick);
	}
}

sub calculate
{
	my $max = 10;
	my @data = ();
	if (get_config ('plugin_max'))
	{
		my $tmp = get_config ('plugin_max');
		$tmp =~ s/\D//g;

		$max = $tmp if ($tmp);
	}

	for ($URLCache->keys ())
	{
		my $url = $_;
		my ($counter, $lastusedtime, $lastusedby) = $URLCache->get ($url);
		die unless (defined ($lastusedby));

		$lastusedby = get_main_nick ($lastusedby);
		push (@data, [$url, $counter, $lastusedby, $lastusedtime]);
	}

	@$URLData = sort { $b->[1] <=> $a->[1] } (@data);
	splice (@$URLData, $max);
}

sub output
{
	calculate ();

	my $fh = get_filehandle ();

	my $url = translate ('URL');
	my $times = translate ('Times used');
	my $last = translate ('Last used by');
	
	print $fh <<EOF;
<table class="plugin urls">
  <tr>
    <td class="invis">&nbsp;</td>
    <th>$url</th>
    <th>$times</th>
    <th>$last</th>
  </tr>
EOF
	my $i = 0;
	foreach (@$URLData)
	{
		$i++;
		my ($url, $count, $usedby) = @$_;
		my $name = nick_to_name ($usedby) || $usedby;

		$url = html_escape ($url);
		
		print $fh "  <tr>\n",
		qq#    <td class="numeration">$i</td>\n#,
		qq#    <td>$url</td>\n#,
		qq#    <td>$count</td>\n#,
		qq#    <td>$usedby</td>\n#,
		qq#  </tr>\n#;
	}

	print $fh "</table>\n\n";
}
