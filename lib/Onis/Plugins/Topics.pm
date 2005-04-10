package Onis::Plugins::Topics;

use strict;
use warnings;

use Onis::Config (qw(get_config));
use Onis::Html (qw(html_escape get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(register_plugin));
use Onis::Data::Persistent ();

our $TopicCache = Onis::Data::Persistent->new ('TopicCache', 'time', qw(text nick));
our $TopicData = [];

register_plugin ('TOPIC', \&add);
register_plugin ('OUTPUT', \&output);

our $MAX = 10;
if (get_config ('plugin_max'))
{
	my $tmp = get_config ('plugin_max');
	$tmp =~ s/\D//g;

	$MAX = $tmp if ($tmp);
}

my $VERSION = '$Id$';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

sub add
{
	my $data = shift;
	my $text = $data->{'text'};
	my $nick = $data->{'nick'};
	my $time = $data->{'epoch'};

	$TopicCache->put ($time, $text, $nick);
}

sub calculate
{
	my $i = 0;
	for (sort { $b <=> $a } ($TopicCache->keys ()))
	{
		my $time = $_;
		last if ($i++ >= $MAX);
		
		my ($text, $nick) = $TopicCache->get ($time);
		die unless (defined ($nick));

		$nick = get_main_nick ($nick);
		push (@$TopicData, [$text, $nick, $time]);
	}
}

sub output
{
	calculate ();
	
	my $fh = get_filehandle ();
	
	my $topic = translate ('Topic');
	my $setby = translate ('Set by');

	print $fh <<EOF;
<table class="plugin topics">
  <tr>
    <td class="invis">&nbsp;</td>
    <th>$topic</th>
    <th>$setby</th>
  </tr>
EOF

	my $i = 0;
	for (@$TopicData)
	{
		$i++;
		my ($topic, $nick) = @$_;
		my $name = nick_to_name ($nick) || $nick;

		$topic = html_escape ($topic);
		
		print $fh "  <tr>\n",
		qq#    <td class="numeration">$i</td>\n#,
		qq#    <td>$topic</td>\n#,
		qq#    <td class="nick">$name</td>\n#,
		qq#  </tr>\n#;
	}

	print $fh "</table>\n\n";
}
