package voice;

# sssf 1.0
# sssf speech specification format

use strict;
use warnings;
use Data::Dumper;

sub new {
	my $class = shift;
	my $self = bless { @_ } => $class;
	return $self;
}
sub parse_string {
	my $self = shift;
	my $str = shift;

	$self->{raw} = $str;
	my $reverse = '';
	my $lang = 'nl';
	my $pitch = '';
	my $repeat = '';
	my $tempo = '';
	my $music = '';

	if ($str =~ s{^~}{}) { $reverse=1; }
	if ($str =~ s/^([a-z]{2})://i) { $lang=$1; }
	if ($str =~ s/^([\+\-]+)//) { $pitch = $1; }
	if ($str =~ s/^([\*\/]+)//) { $tempo = $1; }
	if ($str =~ s/^x(\d)//) { $repeat = $1; }
	if ($str =~ s/^\[(.+?)\]//) { $music = $1;}

	$self->{text} = $str;
	$self->{lang} = $lang;
	$self->{pitch} = $pitch;
	$self->{repeat} = $repeat;
	$self->{tempo} = $tempo;
	$self->{reverse} = $reverse;
	$self->{music} = $music;

	print STDERR Dumper($self);
	return $self;
}

sub filename {
	my $self = shift;
	my $ext = shift;
	if (defined $ext) { if ($ext) { $ext = ".$ext" } } else { $ext = '' }
	return $self->{raw} . $ext;
}

sub compile_music {
	my $self = shift;
	return unless $self->{music};
	my @meas;
	for my $measure (1) {
		my @notes;
		for my $beat (split /,/, $self->{music}) {
			$beat =~ m{^(\d).(\d)([A-F][#b]?\d)};
			my ($beat, $maat, $noot) = ($1, $2, $3);
			# print STDERR "beat=$beat maat=$maat noot=$noot\n";
			$noot =~ m{^([A-F])([#b]?)(\d)};
			my ($step, $alter, $octave) = ($1, $2, $3);
			if ($alter) { $alter = 1 if $alter eq '#'; $alter = -1 if $alter eq 'b' }
			if ($maat ne '4') { die "unsupported maatsoort: $maat"; }
			push @notes, { pitch => { step => $step, octave => $octave, alter => $alter }, type => 'foobar', duration => $beat };
		}
		push @meas, { number => 1, note => \@notes };
	}
	return { 'score-partwise' => { part => { measure => \@meas } } };
}

1;
__END__

~<lang:><+-/*><x3><[midi]>TXT
~ja:+++***x3y4[1/4C#4,1/4F#4]hallo toshiba

