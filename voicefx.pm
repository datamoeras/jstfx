package voicefx;
use strict;
use warnings;

# Convert a single-channel musicxml file to arguments for sox
# Pass the xml filename on the commandline and a series op bend options will be generated
# Needs XML::Mini perlmodule (libxml-mini-perl package in debian/ubuntu)

use Music::Note;

sub new {
	my $class = shift;
	my $self = bless { @_ } => $class;
	$self->{hold} = 0;
	$self->{last_pitch} = 0;
	$self->{bends} = [];
	return $self;
}
sub add_measure {
	my $self = shift;
	my $maat = shift;
	# print STDERR "add_measure\n";
	for my $note (@{ $maat->{note} }) {
		# print STDERR "add note: $note\n";
		$self->add_note($maat, $note);
	}
}
sub hold {
	my $self = shift;
	my $beats = shift;
	my $pitch = shift;
	$self->{hold} = $beats;
	$self->{hold_pitch} = $pitch;
}
sub add_note {
	my $self = shift;
	my $maat = shift;
	my $note = shift;

	$self->output($note->{pitch});
	$self->hold($note->{duration}, $note->{pitch});
}
sub bms {
	my $self = shift;
	my $beats = shift; # 0 or 1 or 2
	my $spb = 60 / $self->{bpm};
	return $spb * $beats;
}
sub bpc {
	my $self = shift;

	my $base = $self->base_note_obj;
	my $note = $self->note_obj(@_);
	# print STDERR "FROM " . $base->format('midinum') . " TO " . $note->format('midinum') . "\n";
	my $semi = $note->format('midinum') - $base->format('midinum');
	my $pitch = $semi * 100;
	# if ($pitch == 0) { $pitch = 1; } # sox won't bend 0

	my $rel = $pitch - $self->{last_pitch};
	$self->{last_pitch} = $pitch;
	if ($rel == 0) {
		$rel++;
		$self->{last_pitch}++;
	}
	# eerst relatief aan de vorige maken
	# dan het absolute deel opslaan in _last
	return $rel;
}
sub note_obj {
	my $self = shift;
	my $pitch = shift;
	my $step = $pitch->{step};
	my $oct = $pitch->{octave};
	my $alter = $pitch->{alter};
	my $alt = '';
	if ($alter) {
		if ($alter > 0) { $alt = '#' }
		else { $alt = 'b'; }
	}
	Music::Note->new($step.$alt.$oct, "ISO");
}
sub base_note_obj {
	my $self = shift;
	Music::Note->new($self->{base}->[0].$self->{base}->[1], "ISO");
}
sub output {
	my $self = shift;
	my $pitch = shift;
	
	my $ms = $self->bms($self->{hold});
	my $bend = $self->bpc($pitch);
	my $duration = .01;
	push @{ $self->{bends} }, [$ms, $bend, $duration];
}

1;
