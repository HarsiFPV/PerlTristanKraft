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

# Read the master exam file
open my $fh_master, '<', $master_file or die "Could not open $master_file: $!";

# Regular expressions with explanations
my $question_regex = qr/^(\d+\.\s+.+)$/;  # Matches a question number and text
my $answer_regex = qr/^\s*\[([X ])\]\s+(.+)$/;  # Matches an answer choice

# Initialize variables to hold questions and answer sets from the master file
my @master_questions;
my %master_answer_sets; # Hash to store answer sets for each question

# Process each line in the master file
while (my $line = <$fh_master>) {
    chomp $line;

    # Detect questions and answer sets in the master file
    if ($line =~ /$question_regex/) {
        push @master_questions, $1;
        $master_answer_sets{$1} = {}; # Initialize answer set hash for the question
    } elsif ($line =~ /$answer_regex/ && @master_questions) {
        my ($mark, $answer) = ($1, $2);
        $master_answer_sets{$master_questions[-1]}->{$answer} = $mark; # Store answer and its marking
    }
}

# Close the master file
close $fh_master;


# CHAPTER 2: Calculate Exam Scores
# ---------------------------------

# Process each completed exam file
foreach my $completed_file (@completed_files) {
    open my $fh_completed, '<', $completed_file or die "Could not open $completed_file: $!";

    my $score = 0;  # Initialize the score for the current completed exam
    my $answered_questions = 0;  # Initialize the number of answered questions

    # Initialize variables to hold questions and answer sets from the completed file
    my @completed_questions;
    my %completed_answer_sets;

    # Process each line in the completed exam file
    while (my $line = <$fh_completed>) {
        chomp $line;

        # Detect questions and answer sets in the completed file
        if ($line =~ /$question_regex/) {
            push @completed_questions, $1;
            $completed_answer_sets{$1} = {}; # Initialize answer set hash for the question
        } elsif ($line =~ /$answer_regex/ && @completed_questions) {
            my ($mark, $answer) = ($1, $2);
            $completed_answer_sets{$completed_questions[-1]}->{$answer} = $mark; # Store answer and its marking
        }
    }

    # Close the completed exam file
    close $fh_completed;

    # Compare completed answers with master answers
    for my $i (0..$#completed_questions) {
        my $completed_question = $completed_questions[$i];

        # Skip if the question isn't present in the master exam
        next unless exists $master_answer_sets{$completed_question};

        my %completed_answers = %{$completed_answer_sets{$completed_question}};
        my %master_answers = %{$master_answer_sets{$completed_question}};

        foreach my $completed_answer (keys %completed_answers) {
            if ($completed_answers{$completed_answer} eq 'X' && $master_answers{$completed_answer} eq 'X') {
                $score++;  # Increment score if the answer is correct
            }
        }

        $answered_questions++;  # Increment the count of answered questions
    }

    # Print the score and total questions answered for the completed exam
    my $total_questions = @master_questions;
    print "$completed_file: Score: $score/$answered_questions out of $total_questions answered\n";
}