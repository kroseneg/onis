package Onis::Plugins::Conversations;

use strict;
use warnings;

use Exporter;

use Onis::Config qw(get_config);
use Onis::Html qw(get_filehandle);
use Onis::Language qw(translate);
use Onis::Data::Core qw(register_plugin get_main_nick nick_to_ident nick_to_name);
use Onis::Data::Persistent ();

=head1 NAME

Onis::Plugins::Conversations - Who talks with who

=head1 DESCRIPTION

This plugins tries to recignise conversations and counts the amount that people
talk to each other.

=cut

@Onis::Plugins::Conversations::EXPORT_OK = (qw(get_conversations));
@Onis::Plugins::Conversations::ISA = ('Exporter');

our $ConversationCache = Onis::Data::Persistent->new ('ConversationCache', 'partners', qw(time0 time1 time2 time3));
our $ConversationData = {};

our @HorizontalImages = qw#dark-theme/h-red.png dark-theme/h-blue.png dark-theme/h-yellow.png dark-theme/h-green.png#;

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
		next unless (defined ($tmp[$i]));
		$HorizontalImages[$i] = $tmp[$i];
	}
}

our $NumConversations = 10;
if (get_config ('conversations_number'))
{
	my $tmp = get_config ('conversations_number');
	$tmp =~ s/\D//g;
	$NumConversations = $tmp if ($tmp);
}

register_plugin ('TEXT', \&add);
register_plugin ('OUTPUT', \&output);

my $VERSION = '$Id: Conversations.pm,v 1.7 2004/09/15 19:42:04 octo Exp $';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

sub add
{
	my $data = shift;
	my $text = $data->{'text'};
	my $nick = $data->{'nick'};
	my $ident = $data->{'ident'};

	my $time = int ($data->{'hour'} / 6);

	# <taken from lib/Onis/Plugins/Nicks.pm>
	my @potential_nicks = split (/[^\w\`\~\^\-\|\[\]]+/, $text);
	my $talk_to = '';
	
	for (@potential_nicks)
	{
		my $other_nick = $_;
		my $other_ident = nick_to_ident ($other_nick);
		
		if ($other_ident)
		{
			$talk_to = $other_nick;
			last;
		}
	}
	# </taken>
	
	if ($talk_to)
	{
		my $key = "$nick:$talk_to";
		my @data = $ConversationCache->get ($key);
		@data = (0, 0, 0, 0) unless (@data);

		my $chars = length ($text);

		$data[$time] += $chars;
		
		$ConversationCache->put ($key, @data);
	}
}

sub calculate
{
	for ($ConversationCache->keys ())
	{
		my $key = $_;
		my ($nick_from, $nick_to) = split (m/:/, $key);
		my @data = $ConversationCache->get ($key);

		$nick_from = get_main_nick ($nick_from);
		$nick_to   = get_main_nick ($nick_to);

		next if (!$nick_from or !$nick_to);
		next if ($nick_from eq $nick_to);

		if (!defined ($ConversationData->{$nick_from}{$nick_to}))
		{
			$ConversationData->{$nick_from}{$nick_to} =
			{
				total => 0,
				nicks =>
				{
					$nick_from => [0, 0, 0, 0],
					$nick_to   => [0, 0, 0, 0]
				}
			};
			$ConversationData->{$nick_to}{$nick_from} = $ConversationData->{$nick_from}{$nick_to};
		}

		for (my $i = 0; $i < 4; $i++)
		{
			$ConversationData->{$nick_from}{$nick_to}{'nicks'}{$nick_from}[$i] += $data[$i];
			$ConversationData->{$nick_from}{$nick_to}{'total'} += $data[$i];
		}
	}
}

sub get_top
{
	my $num = shift;
	my @data = ();

	for (keys %$ConversationData)
	{
		my $nick0 = $_;

		for (keys %{$ConversationData->{$nick0}})
		{
			my $nick1 = $_;
			next unless ($nick0 lt $nick1);

			push (@data, [$ConversationData->{$nick0}{$nick1}{'total'}, $nick0, $nick1]);
		}
	}

	@data = sort { $b->[0] <=> $a->[0] } (@data);
	splice (@data, $num) if (scalar (@data) > $num);

	return (@data);
}

sub output
{
	calculate ();

	my $fh = get_filehandle ();
	my $title = translate ('Conversation partners');

	my $max_num = 0;

	my @data = get_top ($NumConversations);
	return (undef) unless (@data);

	for (@data)
	{
		my $nick0 = $_->[1];
		my $nick1 = $_->[2];
		my $rec = $ConversationData->{$nick0}{$nick1};

		my $sum0 = 0;
		my $sum1 = 0;

		for (my $i = 0; $i < 4; $i++)
		{
			$sum0 += $rec->{'nicks'}{$nick0}[$i];
			$sum1 += $rec->{'nicks'}{$nick1}[$i];
		}

		$max_num = $sum0 if ($max_num < $sum0);
		$max_num = $sum1 if ($max_num < $sum1);
	}
	
	print $fh <<EOF;
<table class="plugin conversations">
  <tr>
    <th colspan="2">$title</th>
  </tr>
EOF
	foreach (@data)
	{
		my $nick0 = $_->[1];
		my $nick1 = $_->[2];
		my $name0 = nick_to_name ($nick0) || $nick0;
		my $name1 = nick_to_name ($nick1) || $nick1;
		my $rec = $ConversationData->{$nick0}{$nick1};

		print $fh <<EOF;
  <tr>
    <td class="nick left">$name0</td>
    <td class="nick right">$name1</td>
  </tr>
  <tr>
EOF

		print $fh '    <td class="bar horizontal left">';
		for (my $i = 3; $i >= 0; $i--)
		{
			my $width = sprintf ("%.2f", 95 * $rec->{'nicks'}{$nick0}[$i] / $max_num);
			my $image = $HorizontalImages[$i];
			my $class = '';

			if    ($i == 3) { $class = qq# class="first"#; }
			elsif ($i == 0) { $class = qq# class="last"#;  }

			print $fh qq#<img src="$image" style="width: $width%;"$class alt="" />#;
		}
		print $fh qq#</td>\n    <td class="bar horizontal right">#;
		for (my $i = 0; $i < 4; $i++)
		{
			my $width = sprintf ("%.2f", 95 * $rec->{'nicks'}{$nick1}[$i] / $max_num);
			my $image = $HorizontalImages[$i];
			my $class = '';

			if    ($i == 0) { $class = qq# class="first"#; }
			elsif ($i == 3) { $class = qq# class="last"#;  }

			print $fh qq#<img src="$image" style="width: $width%;"$class alt="" />#;
		}
		print $fh "</td>\n  </tr>\n";
	}

	print $fh "</table>\n\n";
}

=head1 EXPORTED FUNCTIONS

=over 4

=item B<get_conversations> (I<$nick>)

Returns a hashref to the conversations this nick was involved with. The layout
is the following. I<$other> is the nick of the person I<$nick> chattet with.
The arrays hold the number of characters written by the nick used as the key.
The first field contains the characters for the hours 0-5, the second field
holds 6-11 and so on.

  {
    $other =>
    {
      total => 0,
      nicks =>
      {
        $nick  => [0, 0, 0, 0],
        $other => [0, 0, 0, 0]
      }
    },
    ...
  }

=cut

sub get_conversations
{
	my $nick = shift;

	if (!defined ($ConversationData->{$nick}))
	{
		return ({});
	}
	else
	{
		return ($ConversationData->{$nick});
	}
}

=back

=head1 AUTHOR

Florian octo Forster, E<lt>octo at verplant.orgE<gt>

=cut
