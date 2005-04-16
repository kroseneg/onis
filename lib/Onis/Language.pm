package Onis::Language;

use strict;
use warnings;

use Exporter;

use Onis::Config (qw(get_config));

=head1 NAME

Onis::Language - Translate strings to a user-defined language.

=cut

@Onis::Language::EXPORT_OK = qw/translate/;
@Onis::Language::ISA = ('Exporter');

our %Translations = ();

my $VERSION = '$Id$';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

read_language_file ();

return (1);

=head1 CONFIGURATION OPTIONS

=over 4

=item B<language_file>: I<german.lang>;

Tries to open and read the language-definitions from this file. If it fails
(file does not exist, is not readable, uses an unknown syntax and the like) the
default-language, english, will be used.

=back

=cut

sub read_language_file
{
	my $line;
	my $fh;
	my $file = get_config ('language_file');
	
	if (!$file)
	{
		return (1);
	}

	unless (open ($fh, "< $file"))
	{
		print STDERR $/, __FILE__, ": Unable to open language file ``$file''. Will use default-language english.", $/;
		return (0);
	}

	while ($line = <$fh>)
	{
		my @strings = ();

		chomp ($line);

		if ($line =~ m/^((?:"(?:[^\\"]|\\.)*"|[^#])*)#/)
		{
			$line = $1;
		}

		while ($line =~ m/"((?:[^\\"]|\\.)+)"/g)
		{
			push (@strings, $1);
		}

		if (scalar (@strings) < 2)
		{
			next;
		}

		my $key = shift (@strings);
		$Translations{$key} = \@strings;
	}

	close ($fh);
	return (1);
}

=head1 EXPORTED FUNCTIONS

=over 4

=item B<translate> (I<$string>)

Translates the given string using the language file loaded. If no translation
is found returns the original string.

=cut

sub translate
{
	my $string = shift;
	my $retval;

	if (defined ($Translations{$string}))
	{
		my $array = $Translations{$string};

		if (scalar (@$array) == 1)
		{
			$retval = $array->[0];
		}
		else
		{
			my $num = scalar (@$array);
			my $pick = int (rand ($num));

			$retval = $array->[$pick];
		}
	}
	else
	{
		if ($::DEBUG & 0x10)
		{
			$retval = '<span style="color: red; background-color: yellow;">'
			.	$string . '</span>';
		}
		else
		{
			$retval = $string;
		}
	}

	return ($retval);
}

=back

=head1 AUTHOR

Florian octo Forster E<lt>octo at verplant.orgE<gt>

=cut
