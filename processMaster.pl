#!/usr/bin/perl

# Answers    : Part 1a of final project

#Use statments to make sure proper Perl is writen and we are informed of bad uses or errors
use strict;
use warnings;
use diagnostics;
use List::Util qw(shuffle);

#Version specification to maximise compatibility
use v5.32;

############################################
# Usage      : perl processMaster.pl <input_file>
# Purpose    : To randomize the order of answer sets for each question in an exam input file and generate a modified exam content.
# Returns    : A new file with randomized answer sets.
# Parameters : The input exam file with questions and their respective answer sets.
# Throws     : Error if the input file cannot be opened.
# Comments   : This script helps in creating multiple versions of an exam by shuffling answer choices.
#              It generates a timestamped output file to differentiate from other versions.
#              Please note that as <input_file> should not be in this format './file.txt' but rather in this format 'file.txt'


# Extract the input file from command line arguments.
my $input_file = shift @ARGV;
die "Usage: $0 <input_file>\n" unless defined $input_file;

# Use timestamp for unique, chronologically sortable output filenames.
my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
my $timestamp = sprintf("%04d%02d%02d-%02d%02d%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
my $output_file = "${timestamp}-$input_file";

# Ensure resources are available upfront by opening files early.
open my $fh_in, '<', $input_file or die "Could not open $input_file: $!";
open my $fh_out, '>', $output_file or die "Could not open $output_file: $!";

# Define regex for structured parsing of questions and answers.
my $question_regex = qr/^(\d+\.\s+.+)$/;
my $answer_regex = qr/^\s*\[.\]\s+(.+)$/;

# Efficiently associate questions with their corresponding answers.
my @questions;
my %answer_sets;

# Process input file line-by-line for memory efficiency.
while (my $line = <$fh_in>) {

    # Remove newline characters for easier pattern matching.
    chomp $line;

    # If the line matches the question format, store it and initialize an answer set for it.
    if ($line =~ /$question_regex/) {

        # Add question to our list.
        push @questions, $1;

        # Prepare a place to store associated answers.
        $answer_sets{$1} = [];

    # If the line matches the answer format and we've seen a question, associate the answer with the last detected question.
    } elsif ($line =~ /$answer_regex/ && @questions) {

        # Add the answer to the answer set of the most recently detected question.
        push @{$answer_sets{$questions[-1]}}, $1;
    }
}

# Release input file's system resources post reading.
close $fh_in;

# Randomize answer sets for anti-cheating.
foreach my $question (keys %answer_sets) {
    @{$answer_sets{$question}} = shuffle @{$answer_sets{$question}};
}

# Generate the randomized exam, with dividers for clarity.
for my $i (0..$#questions) {

    # Use dividers for better visual separation in the output file.
    print $fh_out "________________________________________________________________________________\n\n";

    # Print the current question.
    print $fh_out "$questions[$i]\n\n";

    # Fetch shuffled answers for the current question.
    my @shuffled_answers = @{$answer_sets{$questions[$i]}};

    # Loop through and print each shuffled answer with an empty checkbox.
    for my $j (0..$#shuffled_answers) {
        print $fh_out "    [ ] $shuffled_answers[$j]\n";
    }

    # Add a newline for spacing after each question's answers.
    print $fh_out "\n";
}

# Close output file to ensure data is flushed.
close $fh_out;

# Inform user where the modified exam is saved.
print "Modified exam content written to $output_file\n";