package Onis::Plugins::Words;

use strict;
use warnings;

use Onis::Config (qw(get_config));
use Onis::Html (qw(get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(register_plugin));
use Onis::Data::Persistent ();

register_plugin ('TEXT', \&add);
register_plugin ('ACTION', \&add);
register_plugin ('OUTPUT', \&output);

our $WordCache = Onis::Data::Persistent->new ('WordCache', 'word', qw(counter lastusedtime lastusedby));
our $WordData = [];

our $MIN_LENGTH = 5;

if (get_config ('ignore_words'))
{
	my $tmp = get_config ('ignore_words');
	$tmp =~ s/\D//g;

	$MIN_LENGTH = $tmp if ($tmp);
}

my $VERSION = '$Id$';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

sub add
{
	my $data = shift;
	my $text = $data->{'text'};
	my $nick = $data->{'nick'};
	my $words = $data->{'words'};
	my $time = $data->{'epoch'};
	
	for (@$words)
	{
		my $word = lc ($_);
		
		next if (length ($word) < $MIN_LENGTH);

		my ($counter) = $WordCache->get ($word);
		$counter ||= 0;
		$counter++;
		
		$WordCache->put ($word, $counter, $time, $nick);
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

	for ($WordCache->keys ())
	{
		my $word = $_;
		my $ident = nick_to_ident ($word);

		if ($ident)
		{
			$WordCache->del ($word);
			next;
		}
		
		my ($counter, $lastusedtime, $lastusedby) = $WordCache->get ($word);
		die unless (defined ($lastusedby));

		my $nick = get_main_nick ($lastusedby);
		push (@data, [$word, $counter, $nick, $lastusedtime]);
	}

	@$WordData = sort { $b->[0] <=> $a->[0] } (@data);
	splice (@$WordData, $max);
}

sub output
{
	calculate ();
	return (undef) unless (@$WordData);

	my $fh = get_filehandle ();
	
	my $word = translate ('Word');
	my $times = translate ('Times used');
	my $last = translate ('Last used by');
	
	print $fh <<EOF;
<table class="plugin">
  <tr>
    <td class="invis">&nbsp;</td>
    <th>$word</th>
    <th>$times</th>
    <th>$last</th>
  </tr>
EOF

	my $i = 0;
	for (@$WordData)
	{
		$i++;

		my ($word, $count, $nick) = @$_;
		
		print $fh "  <tr>\n",
		qq#    <td class="numeration">$i</td>\n#,
		qq#    <td>$word</td>\n#,
		qq#    <td>$count</td>\n#,
		qq#    <td class="nick">$nick</td>\n#,
		qq#  </tr>\n#;
	}
	print $fh "</table>\n\n";

	return (1);
}
