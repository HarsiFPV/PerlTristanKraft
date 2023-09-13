#!/usr/bin/perl
use strict;
use warnings;

use v5.32;

use Lingua::StopWords qw( getStopWords );
use Text::Levenshtein::XS qw(distance);

score_exam ('./sample_exam.txt', './Exams/Arnold_Jenny.txt', './Exams/Berger_Carina.txt', './Exams/Frank_Tina.txt', './Exams/Haas_Charlotte.txt');

sub normalize_text {
    my $stopwords = getStopWords('en');

    delete $stopwords->{not};

    my ($sentence) = @_;
    my @words = split(/\s+/, lc($sentence));
    my @filtered_words = grep { !$stopwords->{$_} } @words;

    return join(' ', @filtered_words);
}

sub distance_calc {
    my ($str1, $str2) = @_;
    my $max_distance = int(0.1 * length($str1));
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
            push @master_questions, $normalized_question;
            $master_answer_sets{$normalized_question} = {};
        }
        elsif ($line =~ /$answer_regex/ && @master_questions) {
            my ($mark, $answer) = (uc($1), normalize_text($2));
            $master_answer_sets{$master_questions[-1]}->{$answer} = $mark;
        }
    }
    close $fh_master;

    my @questions_answered;
    my @correct_answers;

    foreach my $completed_file (@completed_files) {
        open my $fh_completed, '<', $completed_file or die "Could not open $completed_file: $!";
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
        my $num_questions_answered = 0;
        my $num_correct_answers = 0;

        for my $completed_question (@completed_questions) {
            my ($similar_master_question) = grep { distance_calc($completed_question, $_) } @master_questions;

            if ($similar_master_question && $completed_question ne $similar_master_question) {
                $feedback{$completed_file}{"questions"}{$completed_question} = $similar_master_question;
            }
            next unless $similar_master_question;

            for my $answer (keys %{$completed_answer_sets{$completed_question}}) {
                if ($completed_answer_sets{$completed_question}->{$answer} eq "X") {
                    if (exists $master_answer_sets{$similar_master_question}->{$answer}) {
                        $num_correct_answers++ if $master_answer_sets{$similar_master_question}->{$answer} eq "X";
                        next;
                    }
                    my ($similar_master_answer) = grep { distance_calc($answer, $_) } keys %{$master_answer_sets{$similar_master_question}};
                    if ($similar_master_answer && $answer ne $similar_master_answer) {
                        $feedback{$completed_file}{"answers"}{$answer} = $similar_master_answer;
                        $num_correct_answers++ if $master_answer_sets{$similar_master_question}->{$similar_master_answer} eq "X";
                    }
                }
            }
            $num_questions_answered++;
        }

        push @questions_answered, $num_questions_answered;
        push @correct_answers, $num_correct_answers;

        print "$completed_file...........$num_correct_answers/$num_questions_answered\n\n";

        for my $master_question (@master_questions) {
            unless (grep { distance_calc($master_question, $_) } @completed_questions) {
                $feedback{$completed_file}{"missing_questions"}{$master_question} = 1;
            }
        }

        if (exists $feedback{$completed_file}) {
            for my $q (keys %{$feedback{$completed_file}{"questions"}}) {
                print "\tMissing question: $feedback{$completed_file}{'questions'}{$q}\n";
                print "\tUsed this instead: $q\n\n";
            }

            for my $a (keys %{$feedback{$completed_file}{"answers"}}) {
                print "\tMissing answer: $feedback{$completed_file}{'answers'}{$a}\n";
                print "\tUsed this instead: $a\n\n";
            }
        }
    }

    my $avg_questions_answered = int(sum(@questions_answered)/@questions_answered);
    my $avg_correct_answers = int(sum(@correct_answers)/@correct_answers);

    my $min_questions_answered = int(min(@questions_answered));
    my $max_questions_answered = int(max(@questions_answered));
    my $min_correct_answers = int(min(@correct_answers));
    my $max_correct_answers = int(max(@correct_answers));

    my $count_min_questions_answered = grep { $_ == $min_questions_answered } @questions_answered;
    my $count_max_questions_answered = grep { $_ == $max_questions_answered } @questions_answered;

    my $count_min_correct_answers = grep { $_ == $min_correct_answers } @correct_answers;
    my $count_max_correct_answers = grep { $_ == $max_correct_answers } @correct_answers;

    print "\n\tAverage number of questions answered...... $avg_questions_answered\n";
    print "\t\t\t\t    Minimum....... $min_questions_answered ($count_min_questions_answered student", ($count_min_questions_answered == 1 ? "" : "s"), ")\n";
    print "\t\t\t\t    Maximum....... $max_questions_answered ($count_max_questions_answered student", ($count_max_questions_answered == 1 ? "" : "s"), ")\n";

    print "\n\tAverage number of correct answers......... $avg_correct_answers\n";
    print "\t\t\t\t  Minimum......... $min_correct_answers ($count_min_correct_answers student", ($count_min_correct_answers == 1 ? "" : "s"), ")\n";
    print "\t\t\t\t  Maximum......... $max_correct_answers ($count_max_correct_answers student", ($count_max_correct_answers == 1 ? "" : "s"), ")\n";
}

sub sum {
    my @numbers = @_;
    my $total = 0;
    $total += $_ for @numbers;
    return $total;
}

sub min {
    my @numbers = @_;
    return (sort {$a <=> $b} @numbers)[0];
}

sub max {
    my @numbers = @_;
    return (sort {$a <=> $b} @numbers)[-1];
}