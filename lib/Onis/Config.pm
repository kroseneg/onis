package Onis::Config;

use strict;
use warnings;
use Exporter;

@Onis::Config::EXPORT_OK = qw/get_config parse_argv read_config get_checksum/;

@Onis::Config::ISA = ('Exporter');

=head1 NAME

Onis::Config - Parsing of configuration files and query method.

=head1 USAGE

  use Config qw#get_config read_config#;

  read_config ("filename");
  read_config ($filehandle);

  get_config ("key");

  get_checksum ();

=head1 SYNTAX

Here are the syntax rules:

=over 4

=item *

An option starts with a keyword, followed by a colon, then the value for
that key and is ended with a semi-colon. Example:

  keyword: value;

=item *

Text in single- or souble quotes is taken literaly. Quotes can not be
escaped. However, singlequotes enclosed in double quotes (and vice versa)
are perfectly ok. Examples:

  teststring: "Yay, it's a string!";
  html: '<span style="color: #fe0000;">';

=item *

Hashes are start comments and are ignored to the end of the line. Hashes
enclosed in quotes are B<not> interpreted as comments.. See html-example
above..

=item *

Linebreaks and spaces (unless when in quotes..) are ignored. Strings may
not span multiple lines. Use something along this lines instead:

  multiplelineoption: "This is a very very long"
    "string that continues in the next line";

=item *

Any key may occur more than once. You can separate two or more values with
commas:

  key: value1, value2, "This, is ONE value..";
  key: value4;

=back

=cut

our $config = {};

my $VERSION = '$Id: Config.pm,v 1.10 2004/09/16 10:30:00 octo Exp $';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

=head1 EXPORTED FUNCTIONS

=over 4

=item B<get_config> (I<$key>)

Queries the config structure for the given key and returns the value(s). In
list context all values are returned, in scalar context only the most recent
one.

=cut

sub get_config
{
	my $key = shift;
	my $val;

	if (!defined ($config->{$key}))
	{
		return (wantarray () ? () : '');
	}

	$val = $config->{$key};

	if (wantarray ())
	{
		return (@$val);
	}
	else
	{
		return ($val->[0]);
	}
}

=item B<parse_argv> (I<@argv>)

Parses ARGV and adds command-line options to the internal config structure.

=cut

sub parse_argv
{
	my @argv = @_;

	while (@argv)
	{
		my $item = shift (@argv);

		if ($item =~ m/^--?(\S+)/)
		{
			my $key = lc ($1);

			if (!@argv)
			{
				print STDERR $/, __FILE__, ": No value for key '$key'",
					'present.';
				next;
			}

			my $val = shift (@argv);

			push (@{$config->{$key}}, $val);
		}
		elsif ($item)
		{
			push (@{$config->{'input'}}, $item);
		}
		else
		{
			print STDERR $/, __FILE__, ': Ignoring empty argument.';
		}
	}

	return (1);
}

sub parse_config
{
	my $text = shift;
	my $tmp = '';
	my @rep;
	my $rep = 0;

	local ($/) = "\n";
	
	$text =~ s/\r//sg;

	for (split (m/\n+/s, $text))
	{
		my $line = $_;
		chomp ($line);

		# escape quoted text
		while ($line =~ m/^[^#]*(['"]).*?\1/)
		{
			$line =~ s/(['"])(.*?)\1/<:$rep:>/;
			push (@rep, $2);
			$rep++;
		}

		$line =~ s/#.*$//;
		$line =~ s/\s*//g;
		
		$tmp .= $line;
	}

	$text = lc ($tmp);

	while ($text =~ m/(\w+):([^;]+);/g)
	{
		my $key = $1;
		my @val = split (m/,/, $2);

		s/<:(\d+):>/$rep[$1]/eg for (@val);

		push (@{$config->{$key}}, @val);
	}

	return (1);
}

=item B<read_config> (I<$file>)

Reads the configuration file. $file must either be a filename, a reference to
one or a reference to a filehandle. Complains, is file does not exist.

=cut

sub read_config
{
	my $arg = shift;
	my $fh;
	my $text;
	my $need_close = 0;
	local ($/) = undef; # slurp mode ;)

	if (ref ($arg) eq 'GLOB')
	{
		$fh = $arg->{'IO'};
	}
	elsif (!ref ($arg) || ref ($arg) eq 'SCALAR')
	{
		my $scalar_arg;
		if (ref ($arg)) { $scalar_arg = $$arg; }
		else { $scalar_arg = $arg; }
		
		if (!-e $scalar_arg)
		{
			print STDERR $/, __FILE__, ': Configuration file ',
				"'$scalar_arg' does not exist";
			return (0);
		}

		unless (open ($fh, "< $scalar_arg"))
		{
			print STDERR $/, __FILE__, ': Unable to open ',
				"'$scalar_arg': $!";
			return (0);
		}

		$need_close++;
	}
	else
	{
		my $type = ref ($arg);

		print STDERR $/, __FILE__, ": Reference type $type not ",
			'valid';
		return (0);
	}

	# By now we should have a valid filehandle in $fh

	$text = <$fh>;

	close ($fh) if ($need_close);

	parse_config ($text);

	return (1);
}

=back

=head1 AUTHOR

Florian octo Forster E<lt>octo at verplant.orgE<gt>
