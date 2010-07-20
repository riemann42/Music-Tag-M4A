#!/usr/bin/perl -w
use strict;

use Test::More tests => 8;
use File::Copy;
use 5.006;

BEGIN { use_ok('Music::Tag') }

our $options = {};

# Add 13 test for each run of this
sub filetest {
    my $file        = shift;
    my $testoptions = shift;
  SKIP: {
        skip "File: $file does not exists", 7 unless ( -f $file );
        return unless ( -f $file );
        my $tag = Music::Tag->new( $file, $testoptions );
        ok( $tag, 'Object created: ' . $file );
        die unless $tag;
        ok( $tag->get_tag, 'get_tag called: ' . $file );
        ok( $tag->isa('Music::Tag'), 'Correct Class: ' . $file );
        is( $tag->artist, "Beethoven", 'Artist: ' . $file );
        is( $tag->album,  "GPL",       'Album: ' . $file );
        is( $tag->title,  "Elise",     'Title: ' . $file );
		$tag->close();
		$tag = undef;
    }
}

ok( Music::Tag->LoadOptions("t/options.conf"), "Loading options file.\n" );
filetest( "t/elise.m4a" );

