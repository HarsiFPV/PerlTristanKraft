#!/usr/bin/perl

#Use statments to make sure proper Perl is writen and we are informed of bad uses or errors
use strict;
use warnings;
use diagnostics;
use List::Util qw(shuffle);

#Version specification to maximise compatibility
use v5.32;

# CHAPTER 1: Command-line Argument Handling and File I/O
# ------------------------------------------------------

# Check if the input file name is provided as a command-line argument
my $input_file = shift @ARGV;
die "Usage: $0 <input_file>\n" unless defined $input_file;

# Generate the output file name based on the input file name and current timestamp
my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
my $timestamp = sprintf("%04d%02d%02d-%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my $output_file = "${timestamp}-$input_file";
open my $fh_in, '<', $input_file or die "Could not open $input_file: $!";
open my $fh_out, '>', $output_file or die "Could not open $output_file: $!";


# CHAPTER 2: Process Input and Prepare Data Structures
# ----------------------------------------------------

# Regular expressions with explanations
my $question_regex = qr/^(\d+\.\s+.+)$/;  # Matches a question number and text
my $answer_regex = qr/^\s*\[.\]\s+(.+)$/;  # Matches an answer choice

# Initialize variables to hold questions and answer sets
my @questions;
my %answer_sets; # Hash to store answer sets for each question

# Process each line in the input file
while (my $line = <$fh_in>) {
    chomp $line;

    # Detect questions and answer sets
    if ($line =~ /$question_regex/) {
        push @questions, $1;
        $answer_sets{$1} = []; # Initialize answer set array for the question
    } elsif ($line =~ /$answer_regex/ && @questions) {
        push @{$answer_sets{$questions[-1]}}, $1; # Add answer to the last question encountered
    }
}

# Close the input file
close $fh_in;


# CHAPTER 3: Randomize Answer Sets
# --------------------------------

# Shuffle the order of answer sets for each question
foreach my $question (keys %answer_sets) {
    @{$answer_sets{$question}} = shuffle @{$answer_sets{$question}};
}


# CHAPTER 4: Generate Modified Exam Content
# -----------------------------------------

# Write the modified content to the output file
for my $i (0..$#questions) {
    print $fh_out "________________________________________________________________________________\n\n";
    print $fh_out "$questions[$i]\n\n";

    # Shuffled answers for the current question
    my @shuffled_answers = @{$answer_sets{$questions[$i]}};
    for my $j (0..$#shuffled_answers) {
        print $fh_out "    [ ] $shuffled_answers[$j]\n";
    }

    print $fh_out "\n";
}

# Close the output file
close $fh_out;

print "Modified exam content written to $output_file\n";