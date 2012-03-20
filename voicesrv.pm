package voicesrv;
$|++;
use strict;
use warnings;

use LWP::UserAgent;
use URI::Escape qw/uri_escape uri_unescape/;
use IPC::Open2;
use Data::Dumper;

use lib '.';
use voice;
use voicefx;


sub new {
	my $class = shift;
	my $self = bless { @_ } => $class;
	return $self;
}

sub _cachedir {
	return '/home/raoul/git/jts/wav';
}

sub voice_filename {
	my $self = shift;
	my $voice = shift;
	return $self->_cachedir . '/' . $voice->filename(@_);
}

sub request {
	my $self = shift;
	my $str = shift;

	my $voice = voice->new->parse_string($str);
	my $filename_wav = $self->voice_filename($voice, 'wav');
	print STDERR "compile stem: $str\n";

	my $googli_data = $self->bin_curl_googli($voice);
	my $trim_raw_wav = $self->bin_decode_mp3(\$googli_data);
	my $raw_wav = $self->bin_silence(\$trim_raw_wav);
	my $wav = $self->bin_effects($voice, \$raw_wav);
	my %bin;
	$bin{wav} = $raw_wav;
	$bin{png} = $self->bin_waveform_png(\$wav);
	$bin{mp3} = $self->bin_encode_mp3(\$wav);
	$bin{ogg} = $self->bin_encode_ogg(\$wav);

	print STDERR "1. googli-mp3: " . length($googli_data) . " bytes\n";
	print STDERR "2. raw-wav: " . length($wav) . " bytes\n";
	print STDERR "3. na sox: " . length($wav) . " bytes\n";
	print STDERR "4. wav opslaan op $filename_wav\n";
	print STDERR "5. mp3:   \t" . length($bin{mp3}) . " bytes\n";
	print STDERR "6. ogg:   \t" . length($bin{ogg}) . " bytes\n";
	print STDERR "7. png:   \t" . length($bin{png}) . " bytes\n";
	for my $ext (grep $bin{$_} => qw/wav png ogg mp3/) {
		my $fn = $self->voice_filename($voice, $ext);
		open(my $fh, '>', $fn) or die $! . '@' . $fn;
		print $fh $bin{$ext};
		close($fh);
	}
}

sub url_googli {
	my $self = shift;
	my $voice = shift;
	my $txt = $voice->{text};
	my $l = length($txt);
	my $u = uri_escape($txt);
	$u =~ s{ }{+}g;
	my $lang = $voice->{lang} || 'nl';
	return qq'http://translate.google.com/translate_tts?ie=UTF-8&q=$u&textlen=$l&total=1&idx=0&tl=' . $lang;
}

my %googli_cookies = (
	rememberme	=> 'true',
);

sub bin_curl_googli {
	my $self = shift;
	my $url = $self->url_googli(@_);
	my $ua = LWP::UserAgent->new(agent=>'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:10.0.2) Gecko/20100101 Firefox/10.0.4', cookie_jar => {});

	for my $cook (keys %googli_cookies) {
		$ua->cookie_jar->set_cookie(0, $cook, $googli_cookies{$cook}, '/', 'translate.google.com');
	}
	my $res = $ua->get($url);
	return $res->content;
}

sub bin_waveform_png {
	my $self = shift;
	my $ref = shift;
	$self->system23($ref, qw{./waveformgen - -});
}
sub bin_encode_mp3 {
	my $self = shift;
	my $ref = shift;
	$self->system23($ref, qw{lame - -});
}
sub bin_encode_ogg {
	my $self = shift;
	my $ref = shift;
	$self->system23($ref, qw{oggenc -o - -});
}
sub bin_decode_mp3 {
	my $self = shift;
	my $ref = shift;
	return $self->system23($ref, qw/mpg321 -q -w - -/);
}

sub system23 {
	my $self = shift;
	my $ref = shift;
	my $cmd = $_[0];
	print STDERR "SYSTEM23 $cmd\n" . join(" ", @_) . "\n";
	my $pid = open2(my $hr, my $hw, @_);
	# print STDERR "open2-pid: $pid $cmd\n";
	print $hw ${$ref};
	print STDERR length(${$ref}) . " bytes geschreven\n";
	close($hw);
	# print STDERR "schrijf-handle gesloten; wacht op blocking read\n";
	local $/;
	my $mp3 = <$hr>;
	# print STDERR length($mp3) . " bytes gelezen\n";
	close($hr);
	# print STDERR "lees-handle gesloten; wait op pid $pid\n";
	waitpid($pid, 0);
	return $mp3;
}
sub bin_silence {
	my $self = shift;
	my $ref = shift;

	$self->system23($ref, qw/sox - -t wav - silence 1 0.1 0.1% reverse silence 1 0.1 0.1% reverse/);
}

sub bin_effects {
	my $self = shift;
	my $voice = shift;
	my $ref = shift;

	my @sox = qw/sox - -t wav -/;

	my $mod = $voice->{pitch}.$voice->{tempo};
	my ($pitch, $tempo) = (0, 0);
	if ($mod) {
		for my $c (split //, $mod) {
			$pitch += 200 if $c eq '+';
			$pitch -= 200 if $c eq '-';
			$tempo += 200 if $c eq '*';
			$tempo -= 200 if $c eq '/';
		}
	}
	if ($voice->{repeat}) {
		push @sox, "repeat $voice->{repeat}";
	}
	if ($voice->{reverse}) {
		push @sox, "reverse";
	}
	if ($voice->{music}) {
		my $xdoc = $voice->compile_music->{'score-partwise'}{part};
		my $fx = voicefx->new(bpm => 180, base => [qw'C 4']);
		for my $measure (@{ $xdoc->{measure} }) {
			$fx->add_measure($measure);
		}
		if (@{ $fx->{bends} }) {
			push @sox, 'bend';
			for my $b (@{ $fx->{bends} }) {
				print STDERR "sox bend: " . join(',', @{$b}) . "\n";
				push @sox, join(',', @{$b});
			}
		}
	}
	return $self->system23($ref, @sox);
}


1;

__END__

waveformgen heeft echt een tempfile nodig:
carlos@w500s:~/git/mms_r7dood$ ls -al waveformgen 
-rwxrwxr-x 1 carlos carlos 22734 2012-03-20 01:12 waveformgen
carlos@w500s:~/git/mms_r7dood$ ./waveformgen - - < /home/raoul/git/jts/wav/toch.wav > /tmp/kut.png
Saved waveform image to -
carlos@w500s:~/git/mms_r7dood$ ls -al  /tmp/kut.png
-rw-rw-r-- 1 carlos carlos 2547 2012-03-20 01:21 /tmp/kut.png
carlos@w500s:~/git/mms_r7dood$ cat /home/raoul/git/jts/wav/toch.wav | ./waveformgen - - | tee /tmp/kut.png
ERROR: Could not read samples from audio file!

