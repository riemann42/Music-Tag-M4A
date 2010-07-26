package Music::Tag::M4A;
use strict;
use warnings;
our $VERSION = .40_01;

# Copyright (c) 2007,2010 Edward Allen III. Some rights reserved.

#
# You may distribute under the terms of either the GNU General Public
# License or the Artistic License, as specified in the README file.
#


use Music::Tag::Generic;
use Music::Tag;
use Audio::M4P::QuickTime;
use MP4::Info;
use base qw(Music::Tag::Generic);

sub _default_options {
	{ write_m4a => 0 }
}

sub set_values {
	return qw(  album artist bitrate comment compilation composer
				copyright disc duration encoder filename frequency genre
				lyrics picture releasedate tempo title
				totaldiscs totaltracks track year);
}

sub saved_values {
	return qw(  album artist bitrate comment compilation composer
				disc encoder frequency genre get_info lyrics 
				releasedate tempo title totaldiscs totaltracks track year);
}

sub get_tag {
	my $self = shift;
	#$self->get_tag_mp4_info;
	$self->get_tag_qt_info;
	return $self;
}

sub qt {
	my $self = shift;
	unless (exists $self->{_qt}) {
		$self->{_qt} =  Audio::M4P::QuickTime->new(file => $self->info->filename());
	}
	return $self->{_qt};
}
		


sub get_tag_qt_info {
    my $self     = shift;
    my $filename = $self->info->filename();
	unless ($self->qt) {
		$self->status("Failed to create Audio::M4P::QuickTime object");
		return $self;
	}
    my $tinfo    = $self->qt->iTMS_MetaInfo;
	my $minfo    = $self->qt->GetMP4Info;
	my $ginfo    = $self->qt->GetMetaInfo;
	
    $self->info->album( $ginfo->{ALBUM} );
    $self->info->artist( $ginfo->{ARTIST} );
	my $date = $tinfo->{year} || $ginfo->{DAY};
	$date =~ s/T.*$//;

	$self->info->releasedate($date);

	$self->info->disc( $tinfo->{discNumber});
	$self->info->totaldiscs( $tinfo->{discCount});
	$self->info->copyright( $tinfo->{copyright} );

    $self->info->tempo( $ginfo->{TMPO} );
    $self->info->encoder( $ginfo->{TOO} || "iTMS");
	$self->info->genre( $self->qt->genre_as_text );
	$self->info->title( $ginfo->{NAM} );
    $self->info->composer( $ginfo->{WRT} );
	$self->info->track( $self->qt->track);
	$self->info->totaltracks( $self->qt->total);
	$self->info->comment($ginfo->{COMMENT});
	$self->info->lyrics($ginfo->{LYRICS});

    $self->info->bitrate( $minfo->{BITRATE} );
    $self->info->duration( $minfo->{SECONDS} * 1000 );
	if (not $self->info->picture_exists) {
	  my $picture = $self->qt->GetCoverArt;
	  if ((ref $picture) && (@{$picture}) && ($picture->[0])) {
		$self->info->picture( { "MIME type" => "image/jpg", "_Data" => $picture->[0] } );
	  }
	}
    return $self;
}

sub get_tag_mp4_info {
    my $self     = shift;
    my $filename = $self->info->filename();
    my $tinfo    = get_mp4tag($filename);
    my $ftinfo   = get_mp4info($filename);
    $self->info->album( $tinfo->{ALB} );
    $self->info->artist( $tinfo->{ART} );
    $self->info->year( $tinfo->{DAY} );
    $self->info->disc( $tinfo->{DISK}->[0] );
    $self->info->totaldiscs( $tinfo->{DISK}->[1] );
    $self->info->genre( $tinfo->{GNRE} );
    $self->info->title( $tinfo->{NAM} );
    $self->info->compilation( $tinfo->{CPIL} );
    $self->info->copyright( $tinfo->{CPRT} );
    $self->info->tempo( $tinfo->{TMPO} );
    $self->info->encoder( $tinfo->{TOO} || "iTMS");
    $self->info->composer( $tinfo->{WRT} );
    $self->info->track( $tinfo->{TRKN}->[0] );
    $self->info->totaltracks( $tinfo->{TRKN}->[1] );
    $self->info->comment($tinfo->{CMT});
    $self->info->duration( $ftinfo->{SECS} * 1000 );
    $self->info->bitrate( $ftinfo->{BITRATE} );
    $self->info->frequency( $ftinfo->{FREQUENCY} );
    return $self;
}

sub set_tag {
    my $self     = shift;
    my $filename = $self->info->filename();
	unless ($self->qt) {
		$self->status("Failed to create Audio::M4P::QuickTime object");
		return $self;
	}
    my $tinfo    = $self->qt->iTMS_MetaInfo;
	my $minfo    = $self->qt->GetMP4Info;
	my $ginfo    = $self->qt->GetMetaInfo;
	my $changed = 0;

	if ($self->options->{write_m4a}) {
		$self->status("Writing M4A files is in development and dangerous if you use iTunes. Only some tags supported.");
	}
	else {
		$self->status("Writing M4A files is dangerous.  Set write_m4a to true if you want to try.");
		return $self;
	}

	my %simple_map = (
		album => 'album',
		artist => 'artist',
		title => 'title',
		comment => 'comment',
		genre => 'genre_as_text',
		track => 'track',
		totaltracks => 'total',
		year => 'year',
	);

	while (my ($mtm,$qtm) = each %simple_map) {
		unless ($self->qt->$qtm eq $self->info->$mtm) {
			$self->status("Storing new tag info for $mtm");
			$self->qt->$qtm($self->info->$mtm);
			$changed++;
		}
	}
	unless ($ginfo->{TMPO} eq $self->info->tempo) {
		$self->status("Storing new tag info for tempo");
		$self->qt->SetMetaInfo(TMPO => $self->info->tempo, 1);
		$changed++;
    }
	unless ($ginfo->{TOO} eq $self->info->encoder) {
		$self->status("Storing new tag info for encoder");
		$self->qt->SetMetaInfo(TOO => $self->info->encoder, 1);
		$changed++;
    }
	unless ($ginfo->{WRT} eq $self->info->composer) {
		$self->status("Storing new tag info for composer");
		$self->qt->SetMetaInfo(WRT => $self->info->composer, 1);
		$changed++;
    }
	unless ($ginfo->{LYRICS} eq $self->info->lyrics) {
		$self->status("Storing new tag info for lyrics");
		my $lyrics = $self->info->lyrics;
		$lyrics =~ s/\r?\n/\r/g;
		$self->qt->SetMetaInfo(LYRICS => $self->info->lyrics, 1);
		$changed++;
    }
	if ($changed) {
		$self->status("Writing to $filename...");
		$self->qt->WriteFile($filename);
	}
    return $self;
}

sub close {
	my $self = shift;
	undef $self->{_qt};
	delete $self->{_qt};
}


1;

# vim: tabstop=4
__END__
=pod

=head1 NAME

Music::Tag::M4A - Plugin module for Music::Tag to get information from Apple QuickTime headers. 

=head1 SYNOPSIS

	use Music::Tag

	my $filename = "/var/lib/music/artist/album/track.m4a";

	my $info = Music::Tag->new($filename, { quiet => 1 }, "M4A");

	$info->get_info();
	   
	print "Artist is ", $info->artist;

=head1 DESCRIPTION

Music::Tag::M4A is used to read header information from QuickTime MP4 containers. It uses Audio::M4P::QuickTime and MP4::Info.

It is not currently able to write M4A tags (safely). Audio::M4P::QuickTime can write these tags, but iTunes has trouble reading them after
they have been written. Setting the option "write_m4a" will enable some tags to be written, but iTunes will have problems!

=head1 REQUIRED DATA VALUES

No values are required (except filename, which is usually provided on object creation).

=head1 SET DATA VALUES

=pod

=over 4

=item B<artist, album >

=item B<disc, totaldiscs, tempo, encoder, title, composer>

=item B<copyright, track, totaltracks, comment, lyrics>

=item B<bitrate, duration, picture>

=back

=head1 METHODS

=over 4

=item B<default_options()>

Returns the default options for the plugin.  

=item B<set_tag()>

Save object back to MPEG4 container. THIS IS DANGEROUS. Requires write_m4a be set to true.

=item B<get_tag()>

Load information from MPEG4 container. 

=item B<set_values()>

A list of values that can be set by this module.

=item B<saved_values()>

A list of values that can be saved by this module.

=item B<get_tag_qt_info()> 

Load information using Audio::M4P::QuickTime

=item B<get_tag_mp4_info()>

Load information using MP4::Info

=item B<close()>

Close the file and destroy the Audio::M4P::QuickTime object. As this can be large, do this soon after running get_tag
if you do not intend to write back to the file ever.

=item B<qt()>

Returns the Audio::M4P::QuickTime object

=back

=head1 OPTIONS

=over 4

=item B<write_m4a>

Set to true to allow some tags to be written to disc.  Not recommended.

=back

=head1 BUGS

M4A Tags are error-prone. Writing tags is not reliable.

=head1 SEE ALSO

L<Audio::M4P::QuickTime>, L<MP4::Info>, L<Music::Tag>

=head1 SOURCE

Source is available at github: L<http://github.com/riemann42/Music-Tag-M4A|http://github.com/riemann42/Music-Tag-M4A>.

=head1 BUG TRACKING

Please use github for bug tracking: L<http://github.com/riemann42/Music-Tag-M4A/issues|http://github.com/riemann42/Music-Tag-M4A/issues>.

=head1 AUTHOR 

Edward Allen III <ealleniii _at_ cpan _dot_ org>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either:

a) the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

b) the "Artistic License" which comes with Perl.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License with this
Kit, in the file named "Artistic".  If not, I'll be glad to provide one.

You should also have received a copy of the GNU General Public License
along with this program in the file named "Copying". If not, write to the
Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
Boston, MA 02110-1301, USA or visit their web page on the Internet at
http://www.gnu.org/copyleft/gpl.html.


=head1 COPYRIGHT

Copyright (c) 2007 Edward Allen III. Some rights reserved.


