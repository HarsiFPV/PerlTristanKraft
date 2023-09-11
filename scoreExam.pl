#!/usr/bin/perl
use strict;
use warnings;

use v5.32;

use Lingua::StopWords qw( getStopWords );

my $test_string = " What is the airspeed of a fully laden African swallow? ";

score_exam ('.\sample_exam.txt', '.\Exams\Arnold_Jenny.txt' );


#normalize_text($test_string);

sub normalize_text {

    my $stopwords = getStopWords('en');

    my ($sentence) = @_;
    my @words = split(/\s+/, lc($sentence));
    my @filtered_words = grep { !$stopwords->{$_} } @words;

    print "Original: $sentence\n";
    print "Filtered: ", join(' ', @filtered_words), "\n";
    return join(' ', @filtered_words);

}

sub score_exam {
    my ($master_file, @completed_files) = @_;
    my $question_regex = qr/^\s*(\d+\.\s+.+)$/;
    my $answer_regex = qr/^\s*\[([Xx ]{0,1})\]\s+(.+)$/;

    my @master_questions;
    my %master_answer_sets;

    open my $fh_master, '<', $master_file or die "Could not open $master_file: $!";
    while (my $line = <$fh_master>) {
        chomp $line;

        if ($line =~ /$question_regex/) {
            my $normalized_question = normalize_text($1);
            push @master_questions, $normalized_question;
            $master_answer_sets{$normalized_question} = {};
        } elsif ($line =~ /$answer_regex/ && @master_questions) {
            my ($mark, $answer) = (uc($1), normalize_text($2));
            $master_answer_sets{$master_questions[-1]}->{$answer} = $mark;
        }
    }
    close $fh_master;

    foreach my $completed_file (@completed_files) {
        open my $fh_completed, '<', $completed_file or die "Could not open $completed_file: $!";
        my $score = 0;
        my $answered_questions = 0;
        my @completed_questions;
        my %completed_answer_sets;

        while (my $line = <$fh_completed>) {
            chomp $line;

            if ($line =~ /$question_regex/) {
                my $normalized_question = normalize_text($1);
                push @completed_questions, $normalized_question;
                $completed_answer_sets{$normalized_question} = {};
            }
            elsif ($line =~ /$answer_regex/ && @completed_questions) {
                my ($mark, $answer) = (uc($1), normalize_text($2));
                $completed_answer_sets{$completed_questions[-1]}->{$answer} = $mark;
            }
        }
        close $fh_completed;

        for my $question (@completed_questions) {
            my $correct_count = 0;
            my $checked_count = 0;

            for my $answer (keys %{$completed_answer_sets{$question}}) {
                if ($completed_answer_sets{$question}->{$answer} eq "X") {
                    $checked_count++;
                    $correct_count++ if exists $master_answer_sets{$question} && $master_answer_sets{$question}->{$answer} eq "X";
                }
            }

            $answered_questions++ if $checked_count == 1;
            $score++ if $checked_count == 1 && $correct_count == 1;
        }

        print "$completed_file...........$score/$answered_questions\n";

        for my $question (@master_questions) {
            unless (exists $completed_answer_sets{$question}) {
                print "\tMissing question: $question\n";
                next;
            }

            for my $answer (keys %{$master_answer_sets{$question}}) {
                print "\tMissing answer: $answer\n" unless exists $completed_answer_sets{$question}->{$answer};
            }
        }
    }
}