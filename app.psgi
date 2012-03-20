#!/usr/bin/perl

use strict;
use warnings;

use lib '.';

use Plack::Builder;
use Plack::Request;

use CGI::PSGI;
use Cwd qw/getcwd/;
use Data::Dumper;
BEGIN { my $path = getcwd() . '/'. $0; $path =~ s{/\./}{/}g; $path =~ s/app\.psgi$//; unshift @INC, $path; };
use JSON;
use Encode qw/encode decode/;
use HTML::Entities qw/encode_entities/;
use Data::Dumper;
use voicesrv;

my $wav = sub {
	my $env = shift;
	my $use_ogg = $env->{HTTP_USER_AGENT} =~ /firefox/i ? 1 : 0;
	my $req = Plack::Request->new($env);
	my $path = $req->path_info;
	$path =~ s{^/b/}{};
	$path =~ s{/}{ };
	my $srv = voicesrv->new;
	my $voice = $srv->request($path);
	my $filename = $voice->filename($use_ogg ? 'ogg' : 'mp3');
	return [301, ['Location',"/git/jts/wav/$filename"], []];
};

builder {
		mount '/' => sub { $wav->(@_) };
}

