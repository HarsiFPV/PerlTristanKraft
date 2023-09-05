#!/usr/bin/perl

#Use statments to make sure proper Perl is writen and we are informed of bad uses or errors
use strict;
use warnings;
use diagnostics;

#Version specification to maximise compatibility
use v5.32;

# CHAPTER 1: Command-line Argument Handling and File I/O
# ------------------------------------------------------

# Check if both input files are provided as command-line arguments
my ($master_file, @completed_files) = @ARGV;
die "Usage: $0 <master_file> <completed_file(s)>\n" unless defined $master_file && @completed_files;
# Check for minimum number of arguments
die "Usage: $0 <master_file> <student_file1> <student_file2> ...\n" if @ARGV < 2;

# Regular expressions with explanations
my $question_regex = qr/^\s*(\d+\.\s+.+)$/;             # Matches a question number and text
my $answer_regex = qr/^\s*\[([Xx ]{0,1})\]\s+(.+)$/;    # Matches an answer choice

# Initialize variables to hold questions and answer sets from the master file
my @master_questions;
my %master_answer_sets;
my $total_questions;

# Process master file
open my $fh_master, '<', $master_file or die "Could not open $master_file: $!";

while (my $line = <$fh_master>) {
    chomp $line;
    if ($line =~ /$question_regex/) {
        push @master_questions, $1;
        $master_answer_sets{$1} = {};
        $total_questions++;
    }
    elsif ($line =~ /$answer_regex/ && @master_questions) {
        my ($mark, $answer) = (uc($1), $2); # Convert to uppercase
        $master_answer_sets{$master_questions[-1]}->{$answer} = $mark;
    }
}

close $fh_master;
# Process each completed exam file

foreach my $completed_file (@completed_files) {

    open my $fh_completed, '<', $completed_file or die "Could not open $completed_file: $!";

    my $score = 0;
    my $answered_questions = 0;
    my @completed_questions;
    my %completed_answer_sets;

    # Process student's file
    while (my $line = <$fh_completed>) {

        chomp $line;

        if ($line =~ /$question_regex/) {

            push @completed_questions, $1;
            $completed_answer_sets{$1} = {};
        }
        elsif ($line =~ /$answer_regex/ && @completed_questions) {

            my ($mark, $answer) = (uc($1), $2); # Convert to uppercase
            $completed_answer_sets{$completed_questions[-1]}->{$answer} = $mark;
        }
    }

    close $fh_completed;

    # Compare student's answers to master
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

    # Check for missing questions or answers
    for my $question (@master_questions) {

        unless (exists $completed_answer_sets{$question}) {
            print "$completed_file:\nMissing question: $question\n";
            next;
        }
        for my $answer (keys %{$master_answer_sets{$question}}) {

            print "$completed_file:\nMissing answer: $answer\n" unless exists $completed_answer_sets{$question}->{$answer};
        }
    }
}

