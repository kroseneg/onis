package Onis::Parser::Persistent;

=head1 Parser::Persistent

This module provides routines used for ``statefull parsing'' or however
you want to call what's going on. It is used to find an absolute time in
the logfile and rewind the file or seek further, whichever is neccessary.

=head1 Usage

use Parser::Persistent qw#set_absolute_time add_relative_time get_state
newfile %MONTHNAMES#;

set_absolute_time ($year, $month, $day, $hour, $min, $sec);
add_relative_time ($hour, $minute);
get_state ();
newfile ();

=cut

# This module was quite hard to write, so I guess it's hard to understand,
# too. I'll try to explain as much as possible, but it twisted my mind
# more than once since it actually worked. Good luck :)

use strict;
use warnings;

use vars qw#%MONTHNAMES @MONTHNUMS#;

use Exporter;
use Time::Local;
use Onis::Data::Persistent;

@Onis::Parser::Persistent::EXPORT_OK = qw/set_absolute_time get_absolute_time add_relative_time get_state newfile %MONTHNAMES @MONTHNUMS/;
@Onis::Parser::Persistent::ISA = ('Exporter');

%MONTHNAMES =
(
	Jan	=> 0,
	Feb	=> 1,
	Mar	=> 2,
	Apr	=> 3,
	May	=> 4,
	Jun	=> 5,
	Jul	=> 6,
	Aug	=> 7,
	Sep	=> 8,
	Oct	=> 9,
	Nov	=> 10,
	Dec	=> 11
);

@MONTHNUMS = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;

our $TimeNewest = Onis::Data::Persistent->new ('TimeNewest', 'inode', 'time');
our $AbsoluteTime = 0;
our $TimeData =
{
	Seeking		=> 1,
	NeedsRewind	=> 1,
	Duration	=> 0
};
our $CurFile = 0;

my $VERSION = '$Id: Persistent.pm,v 1.7 2004/01/07 20:31:17 octo Exp $';
print STDERR $/, __FILE__, ": $VERSION" if ($::DEBUG);

return (1);

=head1 Exported routines

=head2 get_state ();

This routine decides between four states: ``don't have time'', ``line is
old'', ``parse this line'' and ``rewind file and begin again''. The last
three imply that the time has been set.

B<rewind file and begin again>: The parser should tell the main routine to
rewind the file and start reading at the beginning again. This is
neccessay if we went past the point where we left off during the last run.
In this case zero is returned.

B<parse this line>: If the parser should parse the line and call I<store>
with the results this routine returns one.

B<line is old>: If the parser should simply ignore this line and
continue with the next one this routine returns three.

B<don't have time>: No time is set. Ignore lines until a date is found.

The desire is to pass the return code back to the main routine, unless it
is equal to one. The parser should then return one upon success, two upon
failure.

=cut

# Return values:
# 0 == rewind file
# 1 == line parsed
# 2 == unable to parse
# 3 == line old
# 4 == don't have date
sub get_state
{
	my ($newest) = $TimeNewest->get ($CurFile);
	$newest ||= 0;

	# We're seeking for an absolute date.
	if ($TimeData->{'Seeking'})
	{
		# We're still seeking for a date..
		if (!$AbsoluteTime)
		{
			return (4);
		}

		# we're seeking past this date
		elsif ($newest)
		{
			# We have a date and it's before the date we're seeking for.
			# So we continue seeking..
			if ($AbsoluteTime <= $newest)
			{
				if ($::DEBUG & 0x40)
				{
					print STDERR $/, __FILE__, ": Absolute time found. Is earlier than the newest time. Disabling ``NeedsRewind''.";
				}
				$TimeData->{'NeedsRewind'} = 0;
				
				# line old. ignore it
				return (3);
			}

			# We went too far, so we have to go back.
			# We substract the duration since the beginning
			# of the file and tell the main routine to rewind
			# the file.
			elsif ($TimeData->{'NeedsRewind'})
			{
				my $found;
				my $set;
				my $diff = $TimeData->{'Duration'};
			
				$found = localtime ($AbsoluteTime) if ($::DEBUG & 0x40);

				$AbsoluteTime -= $diff;

				if ($::DEBUG & 0x40)
				{
					$set = localtime ($AbsoluteTime);
					print STDERR $/, __FILE__, ": Absolute time ``$found'' found. Setting back $diff seconds to ``$set''" if ($::DEBUG & 0x40);
				}

				$TimeData->{'NeedsRewind'} = 0;
				delete ($TimeData->{'LastHourSeen'});
				delete ($TimeData->{'LastMinuteSeen'});

				# rewind file
				return (0);
			}

			# This is the line we were looking for.
			# It's past $newest, but not the first absolute time found.
			else
			{
				print STDERR $/, __FILE__, ": Seeking done." if ($::DEBUG & 0x40);
				$TimeData->{'Seeking'} = 0;
			}
		}
				
		# $newest is not set but we have an absolute date.
		else
		{
			print STDERR $/, __FILE__, ": \$newest not set. Setting it to \$AbsoluteTime." if ($::DEBUG & 0x40);
			
			$TimeData->{'Seeking'} = 0;

			# We had to read some lines to get an absolute date.
			# Lets go back.
			if ($TimeData->{'Duration'})
			{
				my $diff = $TimeData->{'Duration'};
				if ($::DEBUG & 0x40)
				{
					my $time = localtime ($AbsoluteTime);
					print STDERR $/, __FILE__, ": AbsolutTime found is ``$time'', but we are $diff seconds into the file.";
				}
				
				$AbsoluteTime -= $TimeData->{'Duration'};
				
				if ($::DEBUG & 0x40)
				{
					my $time = localtime ($AbsoluteTime);
					print STDERR $/, __FILE__, ": Corrected AbsolutTime (set back $diff seconds) is ``$time''";
				}

				delete ($TimeData->{'LastHourSeen'});
				delete ($TimeData->{'LastMinuteSeen'});

				# tell parser to rewind file
				return (0);
			}

			# We didn't miss anything, so we don't need to rewind the file.
			else
			{
				$newest = $AbsoluteTime;
				$TimeNewest->put ($CurFile, $newest);
				return (1);
			}
		}
	}

	# Ok, we're in the past. Let's skip that line..
	# This is NOT supposed to happen. If it does, it's a bug!
	elsif ($AbsoluteTime < $newest)
	{
		my $now =  localtime ($AbsoluteTime);
		my $then = localtime ($newest);
		print STDERR $/, __FILE__, ": Absolute time set, but we're in the past. Skipping. ($now < $then)" if ($::DEBUG & 0x40);
		return (3);
	}

	# We're up to date. $TimeNewest needs to be set accordingly..
	elsif ($AbsoluteTime != $newest)
	{
		if ($::DEBUG & 0x40)
		{
			my $time = localtime ($AbsoluteTime);
			print STDERR $/, __FILE__, ": Updating. Newest time is now ``$time''";
		}

		$newest = $AbsoluteTime;
		$TimeNewest->put ($CurFile, $newest);
	}

	return (1);
}

=head2 add_relative_time ($hour, $min);

This routine does two different things, depending on wether or not the
absolute time is known.

If the absolute time is not known, it will add up the seconds since the
start of the file. When we know the absolute time later we can subtract
that value to get the absolute time of the beginning of the file.

If the absolute time is known it simply adds to it to keep it up to date.

=cut

sub add_relative_time
{
	my $this_hour = shift;
	my $this_minute = shift;

	my $this_seconds = ($this_hour * 3600) + ($this_minute * 60);
	
	if ((defined ($TimeData->{'LastHourSeen'}))
			and (defined ($TimeData->{'LastMinuteSeen'})))
	{
		my $diff = 0;
		my $last_hour = $TimeData->{'LastHourSeen'};
		my $last_minute = $TimeData->{'LastMinuteSeen'};
		my $last_seconds = ($last_hour * 3600) + ($last_minute * 60);
		
		if ($last_seconds > $this_seconds)
		{
			$this_seconds += 86400; # one day
		}

		$diff = $this_seconds - $last_seconds;

		if ($::DEBUG & 0x40)
		{
			print STDERR $/, __FILE__, ': ';
			printf STDERR ("diff ('%02u:%02u', '%02u:%02u') = %u seconds",
				$last_hour, $last_minute,
				$this_hour, $this_minute,
				$diff);
		}
		
		# FIXME needs testing!
		if (!$AbsoluteTime)
		{
			$TimeData->{'Duration'} += $diff;
		}
		else
		{
			$AbsoluteTime += $diff;
		}
	}

	$TimeData->{'LastHourSeen'} = $this_hour;
	$TimeData->{'LastMinuteSeen'} = $this_minute;
}

=head2 set_absolute_time ($year, $month, $day, $hour, $min, $sec);

As the name suggests this routine sets the absolute time.

=cut

sub set_absolute_time
{
	my $year  = shift;
	my $month = shift;
	my $day   = shift;
	my $hour  = shift;
	my $min   = shift;
	my $sec   = shift;

	$year -= 1900;

	my $time = timelocal ($sec, $min, $hour, $day, $month, $year);
	print STDERR $/, __FILE__, ": Set absolute time to ", scalar (localtime ($time)) if ($::DEBUG & 0x40);

	# Add diff if this is the first 
	if (!$AbsoluteTime)
	{
		add_relative_time ($hour, $min);
	}
	else
	{
		# FIXME neccessary?
		$TimeData->{'LastHourSeen'}   = $hour;
		$TimeData->{'LastMinuteSeen'} = $min;
	}
	
	$AbsoluteTime = $time;
}

sub get_absolute_time
{
	return ($AbsoluteTime);
}

=head2 newfile ();

Resets the internal counters to be ready for another file.

=cut

sub newfile
{
	my $inode = shift;

	my ($time) = $TimeNewest->get ($inode);
	$time ||= 0;
	$TimeNewest->put ($inode, $time);
	
	$AbsoluteTime = 0;
	$TimeData->{'Duration'} = 0;
	$TimeData->{'NeedsRewind'} = 1;
	$TimeData->{'Seeking'} = 1;
	delete ($TimeData->{'LastHourSeen'});
	delete ($TimeData->{'LastMinuteSeen'});
}
