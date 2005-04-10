package Onis::Plugins::Nicks;

use strict;
use warnings;

use Onis::Html (qw(get_filehandle));
use Onis::Language (qw(translate));
use Onis::Data::Core (qw(register_plugin));
use Onis::Data::Persistent ();
use Onis::Users (qw(nick_to_name));

register_plugin ('TEXT', \&add);
register_plugin ('ACTION', \&add);
register_plugin ('OUTPUT', \&output);

our $MentionedNicksCache = Onis::Data::Persistent->new ('MentionedNicksCache', 'nick', qw(counter lastusedtime lastusedby));
our $MentionedNicksData = [];

my $VERSION = '$Id$';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

sub add
{
	my $data = shift;

	my $nick = $data->{'nick'};
	my $text = $data->{'text'};
	my $time = $data->{'epoch'};

	# All allowed chars according to RFC2812
	my @potential_nicks = split (/[^a-zA-Z0-9\[\]\\`_^{|}]+/, $text);

	for (@potential_nicks)
	{
		my $pot_nick = $_;

		# Not allowed according to RFC2812
		if ($pot_nick =~ m/^[0-9\-]/)
		{
			next;
		}

		if (nick_to_ident ($pot_nick))
		{
			my ($counter) = $MentionedNicksCache->get ($pot_nick);
			$counter ||= 0;
			$counter++;
			$MentionedNicksCache->put ($pot_nick, $counter, $time, $nick);
		}
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

	for ($MentionedNicksData->keys ())
	{
		my $nick = $_;
		my ($counter, $lastusedtime, $lastusedby) = $MentionedNicksData->get ($nick);
		die unless (defined ($lastusedby));
		
		$lastusedby = get_main_nick ($lastusedby);
		push (@data, [$nick, $counter, $lastusedby, $lastusedtime]);
	}

	@$MentionedNicksData = sort { $b->[1] <=> $a->[1] } (@data);
	splice (@$MentionedNicksData, $max);
}

sub output
{
	calculate ();

	my $fh = get_filehandle ();

	my $nick = translate ('Nick');
	my $times = translate ('Times used');
	my $last = translate ('Last used by');
	
	print $fh <<EOF;
<table class="plugin">
  <tr>
    <td class="invis">&nbsp;</td>
    <th>$nick</th>
    <th>$times</th>
    <th>$last</th>
  </tr>
EOF
	my $i = 0;
	foreach (@$MentionedNicksData)
	{
		$i++;
		my ($nick, $count, $usedby) = @$_;
		my $usedby_name = nick_to_name ($usedby) || $usedby;

		print $fh "  <tr>\n",
		qq#    <td class="numeration">$i</td>\n#,
		qq#    <td>$nick</td>\n#,
		qq#    <td>$count</td>\n#,
		qq#    <td>$usedby_name</td>\n#,
		qq#  </tr>\n#;
	}

	print $fh "</table>\n\n";
}
