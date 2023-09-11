use strict;
use warnings;
use Lingua::StopWords qw( getStopWords );

my $stopwords = getStopWords('en');

my $sentence = "What is the airspeed of a fully laden African swallow?";
my @words = split(/\s+/, lc($sentence));

my @filtered_words = grep { !$stopwords->{$_} } @words;

print "Original: $sentence\n";
print "Filtered: ", join(' ', @filtered_words), "\n";
