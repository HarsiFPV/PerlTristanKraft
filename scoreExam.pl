#!/usr/bin/perl
use strict;
use warnings;

use v5.32;

use Lingua::StopWords qw( getStopWords );
use Text::Levenshtein::XS qw(distance);

my $test_string = " What is the airspeed of a fully laden African swallow? ";

score_exam ('.\sample_exam.txt', '.\Exams\Arnold_Jenny.txt');

#distance_calc("23. In Perl, you can take references to...", "23. In Perl, you can take references to...")

#normalize_text($test_string);

sub normalize_text {
    my $stopwords = getStopWords('en');

    # Supprimer 'not' de la liste des stopwords
    delete $stopwords->{not};

    my ($sentence) = @_;
    my @words = split(/\s+/, lc($sentence));
    my @filtered_words = grep { !$stopwords->{$_} } @words;

    #print "Original: $sentence\n";
    #print "Filtered: ", join(' ', @filtered_words), "\n";

    return join(' ', @filtered_words);
}

sub distance_calc {
    my ($str1, $str2) = @_;
    my $max_distance = int(0.1 * length($str1)); # 10% of the length of the normalized original string
    return distance($str1, $str2) <= $max_distance;

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
            #print "Detected Question (completed file): $normalized_question\n";
            push @master_questions, $normalized_question;
            $master_answer_sets{$normalized_question} = {};
        }
        elsif ($line =~ /$answer_regex/ && @master_questions) {
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

        my %feedback;

        for my $completed_question (@completed_questions) {
            my $correct_count = 0;
            my $checked_count = 0;

            my ($similar_master_question) = grep {distance_calc($completed_question, $_)} @master_questions;
            #print "DEBUG: Matching master question found for $completed_question: $similar_master_question\n"; # Debug print

            if ($similar_master_question && $completed_question ne $similar_master_question) {
                $feedback{$completed_file}{"questions"}{$completed_question} = $similar_master_question;
            }

            next unless $similar_master_question; # Skip if no similar question in the master set

            for my $answer (keys %{$completed_answer_sets{$completed_question}}) {
                if ($completed_answer_sets{$completed_question}->{$answer} eq "X") {
                    #print "DEBUG: Checking answer: $answer for question: $completed_question\n"; # Debug print
                    $checked_count++;

                    # Check for exact match first
                    if (exists $master_answer_sets{$similar_master_question}->{$answer}) {
                        $correct_count++ if $master_answer_sets{$similar_master_question}->{$answer} eq "X";
                        next;
                    }

                    # If no exact match found, look for similar answer
                    my ($similar_master_answer) = grep {distance_calc($answer, $_)} keys %{$master_answer_sets{$similar_master_question}};

                    if ($similar_master_answer && $answer ne $similar_master_answer) {
                        $feedback{$completed_file}{"answers"}{$answer} = $similar_master_answer;
                        $correct_count++ if $master_answer_sets{$similar_master_question}->{$similar_master_answer} eq "X";
                    }
                }
            }

            #print "DEBUG: For question $completed_question - checked_count: $checked_count, correct_count: $correct_count\n"; # Debug print

            $answered_questions++ if $checked_count == 1;
            $score++ if $checked_count == 1 && $correct_count == 1;
        }

        print "$completed_file...........$score/$answered_questions\n";

        # Vérifier les questions qui ne sont pas du tout dans l'exam rendu
        for my $master_question (@master_questions) {
            unless (grep {distance_calc($master_question, $_)} @completed_questions) {
                $feedback{$completed_file}{"missing_questions"}{$master_question} = 1;
            }
        }

        # Step 3: Display the feedback
        if (exists $feedback{$completed_file}) {
            for my $q (keys %{$feedback{$completed_file}{"questions"}}) {
                print "\tMissing question: $feedback{$completed_file}{'questions'}{$q}\n";
                print "\tUsed this instead: $q\n\n";
            }

            for my $a (keys %{$feedback{$completed_file}{"answers"}}) {
                print "\tMissing answer: $feedback{$completed_file}{'answers'}{$a}\n";
                print "\tUsed this instead: $a\n";
            }

            # Check for completely missing questions
            for my $mq (keys %{$feedback{$completed_file}{"missing_questions"}}) {
                # Only display missing questions that were not already matched with a similar question
                unless (exists $feedback{$completed_file}{"questions"}{$mq}) {
                    print "\tMissing question $mq\n\tNo close match found for question $mq\n\n";
                }
            }
        }
    }
}