#!/usr/bin/perl
# Enforce strict variable declaration and provide warnings for common mistakes to enhance code reliability
use strict;
use warnings;

# Specify the version to ensure compatibility with the Perl features being used in the script
use v5.32;

# Use CPAN modules to take advantage of existing efficient solutions, rather than rewriting a lot of stuff
use Lingua::StopWords qw( getStopWords );
use Text::Levenshtein::XS qw(distance);
use File::Spec;

# Centralizing file paths and directories in variables provides a single point of change, simplifying potential modifications
my $sample_exam = './sample_exam.txt';
my $exam_dir = './Exams/';
my @exam_files = ();

# Using opendir within a block that checks for exceptions ensures that directory-access issues are caught early
opendir(DIR, $exam_dir) or die "Couldn't open directory $exam_dir: $!";

while (my $file = readdir(DIR)) {
    # Filtering for '.txt' files, excluding hidden files (starting with a dot)
    next unless $file =~ /\.txt$/ && $file !~ /^\./;

    # Using File::Spec ensures that file paths are constructed in a cross-platform manner
    push @exam_files, File::Spec->catfile($exam_dir, $file);
}
closedir(DIR);

# A separate function call keeps the main logic clean
score_exam($sample_exam, @exam_files);

############################################
# Usage      : normalize_text($text)
# Purpose    : Used to normalize a text by removing common stopwords except 'not', and converting to lowercase
# Returns    : A normalized string with stopwords removed
# Parameters : A string to be normalized
# Throws     : no exceptions
# Comments   : This subroutine is especially useful in text analysis when stopwords can skew results

sub normalize_text {

    # Fetch English stopwords. It's efficient to use an existing library than manually listing them
    my $stopwords = getStopWords('en');

    # Remove 'not' from stopwords. 'Not' is often important in sentiment analysis or context understanding
    delete $stopwords->{not};

    # Split the sentence into words and convert to lowercase for standardization
    my ($sentence) = @_;
    my @words = split(/\s+/, lc($sentence));

    # Filter out the stopwords from the list of words
    my @filtered_words = grep { !$stopwords->{$_} } @words;

    # Return the filtered words as a single string
    return join(' ', @filtered_words);
}

############################################
# Usage      : distance_calc($str1, $str2)
# Purpose    : Calculate the Levenshtein distance between two strings and check if it's within an acceptable threshold
# Returns    : 1 (true) if distance is within threshold, otherwise 0 (false)
# Parameters : Two strings for comparison
# Throws     : no exceptions
# Comments   : The subroutine checks the similarity of two strings, useful in scenarios like typo detection or approximate string matching

sub distance_calc {

    # Get the two input strings to be compared
    my ($str1, $str2) = @_;

    # Set an acceptable threshold for similarity. Here, 10% of the length of the first string
    my $max_distance = int(0.1 * length($str1));

    # Return true if the Levenshtein distance is less than or equal to the threshold
    return distance($str1, $str2) <= $max_distance;
}

############################################
# Usage      : score_exam($master_file, @completed_files)
# Purpose    : Evaluate student answers against a master answer key, and provide feedback and statistics
# Returns    : Prints out individual scores and statistics
# Parameters : A master answer file and a list of student answer files
# Throws     : Errors related to file handling
# Comments   : A robust exam grading system that can handle textual variations
# See Also   : normalize_text, distance_calc, sum, min, max, standard_deviation

sub score_exam {

    # Extracting master file and student completed files from the subroutine arguments.
    my ($master_file, @completed_files) = @_;

    # Using regex to detect question and answer structure in exams. This method supports exams with varying designs.
    my $question_regex = qr/^\s*(\d+\.\s+.+)$/;
    my $answer_regex = qr/^\s*\[([Xx ]{0,1})\]\s+(.+)$/;

    # Initializing arrays and hashes to store master exam questions and answers. This structure speeds up the comparison process.
    my @master_questions;
    my %master_answer_sets;

    # Opening master exam file for reading; if not found, it terminates the script with an error message.
    open my $fh_master, '<', $master_file or die "Could not open $master_file: $!";

    # Iterating through each line of the master exam file.
    while (my $line = <$fh_master>) {

        # Removing any trailing newline characters from the line for processing.
        chomp $line;

        # Checking if the line matches the question structure using the previously defined regex.
        if ($line =~ /$question_regex/) {

            # Normalizing the matched question to maintain consistency.
            my $normalized_question = normalize_text($1);

            # Adding the normalized question to the master questions array.
            push @master_questions, $normalized_question;

            # Initializing an empty hash reference for storing answers related to this question.
            $master_answer_sets{$normalized_question} = {};
        }

        # Checking if the line matches the answer structure and ensuring that we've found questions before processing answers.
        elsif ($line =~ /$answer_regex/ && @master_questions) {

            # Extracting and normalizing the matched answer and its mark.
            my ($mark, $answer) = (uc($1), normalize_text($2));

            # Associating the answer with the most recent question in the master_answer_sets hash.
            $master_answer_sets{$master_questions[-1]}->{$answer} = $mark;
        }
    }

    # Closing the master file handle as it's no longer needed, freeing system resources.
    close $fh_master;

    # Initializing arrays to track the number of questions each student answered and how many they got correct.
    my @questions_answered;
    my @correct_answers;

    # Processing each student's completed exam.
    foreach my $completed_file (@completed_files) {

        # Attempting to open the current student's completed exam file.
        open my $fh_completed, '<', $completed_file or die "Could not open $completed_file: $!";

        # Arrays and hashes to store the student's answers and their associations with questions.
        my @completed_questions;
        my %completed_answer_sets;

        # Iterating through each line of the student's exam.
        while (my $line = <$fh_completed>) {

            # Stripping newline characters for processing.
            chomp $line;

            # Checking if the line matches the defined question format.
            if ($line =~ /$question_regex/) {

                # Normalizing the matched question to ensure consistency when comparing later.
                my $normalized_question = normalize_text($1);

                # Storing the student's question and initializing a place to associate answers.
                push @completed_questions, $normalized_question;
                $completed_answer_sets{$normalized_question} = {};
            }

            # Checking if the line matches the answer structure and ensuring we've processed questions before answers.
            elsif ($line =~ /$answer_regex/ && @completed_questions) {

                # Extracting and normalizing the matched answer.
                my ($mark, $answer) = (uc($1), normalize_text($2));

                # Associating the answer with the student's most recent question.
                $completed_answer_sets{$completed_questions[-1]}->{$answer} = $mark;
            }
        }

        # Closing the current student's file handle post-processing, conserving system resources.
        close $fh_completed;

        # Initializing a feedback hash to store potential issues with student answers and questions, and track performance.
        my %feedback;

        # Variables to count the number of correct answers and the number of questions attempted by the student.
        my $num_correct_answers = 0;
        my $answered_questions = 0;

        # Looping through each of the student's completed questions to compare against the master.
        for my $completed_question (@completed_questions) {

            # Searching for a similar master question using a distance calculation to account for minor discrepancies.
            my ($similar_master_question) = grep { distance_calc($completed_question, $_) } @master_questions;

            # If we find a similar but not exact match, we note the potential issue in feedback.
            if ($similar_master_question && $completed_question ne $similar_master_question) {
                $feedback{$completed_file}{"questions"}{$completed_question} = $similar_master_question;
            }
            # Skipping the rest of this loop iteration if there's no similar master question found.
            next unless $similar_master_question;

            # Looping through the student's answers associated with the current question.
            for my $answer (keys %{$completed_answer_sets{$completed_question}}) {

                # If the student marked this answer, incrementing the attempted count.
                if ($completed_answer_sets{$completed_question}->{$answer} eq "X") {
                    $answered_questions++;

                    # If the answer also exists in the master and is marked correct, increment the correct count.
                    if (exists $master_answer_sets{$similar_master_question}->{$answer}) {
                        $num_correct_answers++ if $master_answer_sets{$similar_master_question}->{$answer} eq "X";
                        next;
                    }

                    # For unmatching answers, we look for a similar master answer.
                    my ($similar_master_answer) = grep { distance_calc($answer, $_) } keys %{$master_answer_sets{$similar_master_question}};

                    # If we find a similar but not exact answer match, we note it in feedback and check if it's correct in the master.
                    if ($similar_master_answer && $answer ne $similar_master_answer) {
                        $feedback{$completed_file}{"answers"}{$answer} = $similar_master_answer;
                        $num_correct_answers++ if $master_answer_sets{$similar_master_question}->{$similar_master_answer} eq "X";
                    }
                }
            }
        }

        # Storing the count of questions answered and the number of correct answers for each student for further analysis.
        push @questions_answered, $answered_questions;
        push @correct_answers, $num_correct_answers;

        # Printing the score of the student out of the number of questions they attempted.
        print "$completed_file...........$num_correct_answers/$answered_questions\n\n";

        # Looping through master questions to identify any that the student may have missed.
        for my $master_question (@master_questions) {

            # Checking if the master question isn't similar to any of the student's questions, implying the student missed it.
            unless (grep { distance_calc($master_question, $_) } @completed_questions) {
                $feedback{$completed_file}{"missing_questions"}{$master_question} = 1;
            }
        }

        # If there's feedback related to this student's file, we'll print it out for review.
        if (exists $feedback{$completed_file}) {

            # Looping through the feedback to print any discrepancies between the student's questions and the master.
            for my $q (keys %{$feedback{$completed_file}{"questions"}}) {
                print "\tMissing question: $feedback{$completed_file}{'questions'}{$q}\n";
                print "\tUsed this instead: $q\n\n";
            }

            # Looping through the feedback to print any discrepancies between the student's answers and the master.
            for my $a (keys %{$feedback{$completed_file}{"answers"}}) {
                print "\tMissing answer: $feedback{$completed_file}{'answers'}{$a}\n";
                print "\tUsed this instead: $a\n\n";
            }
        }
    }

    # Calculating the average questions answered and correct answers for all students to get an overall picture of the class performance.
    my $avg_questions_answered = int(sum(@questions_answered) / scalar(@questions_answered));
    my $avg_correct_answers = int(sum(@correct_answers) / scalar(@correct_answers));

    # Identifying the range of questions answered and correct answers to gauge the variability in student performance.
    my $min_questions_answered = int(min(@questions_answered));
    my $max_questions_answered = int(max(@questions_answered));
    my $min_correct_answers = int(min(@correct_answers));
    my $max_correct_answers = int(max(@correct_answers));

    # Counting the occurrences of the extreme values helps in understanding how many students are at the boundary of the performance spectrum.
    my $count_min_questions_answered = grep { $_ == $min_questions_answered } @questions_answered;
    my $count_max_questions_answered = grep { $_ == $max_questions_answered } @questions_answered;

    my $count_min_correct_answers = grep { $_ == $min_correct_answers } @correct_answers;
    my $count_max_correct_answers = grep { $_ == $max_correct_answers } @correct_answers;

    # Calculating standard deviations provides insight into the spread or variability of the data.
    my $std_dev_questions_answered = standard_deviation(@questions_answered);
    my $std_dev_correct_answers = standard_deviation(@correct_answers);

    # Printing the results in a readable format to provide educators with a clear overview of student performance.
    print "\n\tAverage number of questions answered...... $avg_questions_answered\n";
    print "\t\t\t\t    Minimum....... $min_questions_answered ($count_min_questions_answered student", ($count_min_questions_answered == 1 ? "" : "s"), ")\n";
    print "\t\t\t\t    Maximum....... $max_questions_answered ($count_max_questions_answered student", ($count_max_questions_answered == 1 ? "" : "s"), ")\n";

    print "\n\tAverage number of correct answers......... $avg_correct_answers\n";
    print "\t\t\t\t  Minimum......... $min_correct_answers ($count_min_correct_answers student", ($count_min_correct_answers == 1 ? "" : "s"), ")\n";
    print "\t\t\t\t  Maximum......... $max_correct_answers ($count_max_correct_answers student", ($count_max_correct_answers == 1 ? "" : "s"), ")\n";


    # Understanding the average performance gives context to individual student results.
    my $mean_score = sum(@correct_answers) / @correct_answers;

    # Calculating the spread of scores helps identify unusually low or high scores.
    my $std_dev = standard_deviation(@correct_answers);

    # Setting a boundary for the lower quartile to flag students whose performance is below the majority of the cohort.
    my @sorted_scores = sort { $a <=> $b } @correct_answers;
    my $twenty_fifth_percentile = $sorted_scores[int(0.25 * @sorted_scores)];

    # Start a new section in the output to highlight scores that might be concerning.
    print "\nResults below expectation:\n";

    # Iterate over each student's completed file to evaluate their performance.
    for my $i (0 .. $#completed_files) {

        # Store reasons for scores being below expectation.
        my @reasons;

        # Identifying students who scored less than half the total available points
        push @reasons, 'score < 50%' if $correct_answers[$i] < @master_questions / 2 && $questions_answered[$i] != 0;

        # Identifying students whose performance is significantly below the average performance of the class.
        push @reasons, 'score > 1σ below mean' if $correct_answers[$i] < $mean_score - $std_dev && $questions_answered[$i] != 0;

        # Spotting students in the lower quartile
        push @reasons, 'bottom 25% of cohort' if $correct_answers[$i] <= $twenty_fifth_percentile && $questions_answered[$i] != 0;

        # Checking for potential submission issues, where a file might be empty or corrupted.
        push @reasons, 'Possible empty file' if $questions_answered[$i] == 0;

        # Printing only those students whose results fall into the predefined categories, allowing educators to prioritize their attention.
        if (@reasons) {
        printf("%s........%02d/%02d (%s)\n", $completed_files[$i], $correct_answers[$i], $questions_answered[$i], join(", ", @reasons));
        }
    }
}

############################################
# Usage      : sum(@numbers)
# Purpose    : Calculates the sum of all numbers in the provided array
# Returns    : Total sum of all numbers in the array
# Parameters : An array of numbers
# Throws     : no exceptions
# Comments   : Basic utility function for summation
# See Also   : n/a

sub sum {

    # Retrieve the passed array of numbers.
    my @numbers = @_;

    # Initialize the sum to zero to start accumulation.
    my $total = 0;

    # Efficiently accumulate the sum in a single loop.
    $total += $_ for @numbers;

    # Return the computed sum.
    return $total;

}

############################################
# Usage      : min(@numbers)
# Purpose    : Determines the minimum number in the provided array
# Returns    : The smallest number in the array
# Parameters : An array of numbers
# Throws     : no exceptions
# Comments   : Basic utility function to get the minimum value
# See Also   : n/a

sub min {

    # Retrieve the passed array of numbers.
    my @numbers = @_;

    # Sort numbers in ascending order and return the first element (smallest).
    return (sort {$a <=> $b} @numbers)[0];

}

############################################
# Usage      : max(@numbers)
# Purpose    : Determines the maximum number in the provided array
# Returns    : The largest number in the array
# Parameters : An array of numbers
# Throws     : no exceptions
# Comments   : Basic utility function to get the maximum value
# See Also   : n/a

sub max {

    # Retrieve the passed array of numbers.
    my @numbers = @_;

    # Sort numbers in ascending order and return the last element (largest).
    return (sort {$a <=> $b} @numbers)[-1];

}

############################################
# Usage      : standard_deviation(@numbers)
# Purpose    : Calculates the standard deviation of a list of numbers
# Returns    : The standard deviation
# Parameters : An array of numbers
# Throws     : no exceptions
# Comments   : This subroutine aids in analyzing the spread of a dataset
# See Also   : n/a

sub standard_deviation {

    # Retrieve the passed array of numbers.
    my @numbers = @_;

    # Determine the count of numbers for further calculations.
    my $count = scalar @numbers;
    my $sum = 0;

    # Sum all the numbers for mean calculation.
    $sum += $_ for @numbers;

    # Calculate the mean (average) of the numbers.
    my $mean = $sum / $count;

    $sum = 0;

    # For each number, compute the squared difference from the mean. This provides a measure of each number's deviation from the mean.
    $sum += ($_ - $mean)**2 for @numbers;

    # Return the square root of the average squared deviation which provides the standard deviation.
    return sqrt($sum / $count);
}

