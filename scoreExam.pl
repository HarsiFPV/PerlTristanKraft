#!/usr/bin/perl
use strict;
use warnings;

#We specify the version to ensure compatibility
use v5.32;

#Thoses CPAN modules are used to make the code more compact and easier to use
use Lingua::StopWords qw( getStopWords );
use Text::Levenshtein::XS qw(distance);
use File::Spec;

#We put the exam folder in a variable to be able to simply process all files
my $sample_exam = './sample_exam.txt';
my $exam_dir = './Exams/';
my @exam_files = ();

#Catch exception for reliability
opendir(DIR, $exam_dir) or die "Couldn't open directory $exam_dir: $!";

while (my $file = readdir(DIR)) {
    # Skip any non-txt files or any hidden files (starting with a dot)
    next unless $file =~ /\.txt$/ && $file !~ /^\./;

    # Concatenate directory path with file name for full path
    push @exam_files, File::Spec->catfile($exam_dir, $file);
}
closedir(DIR);

score_exam($sample_exam, @exam_files);


#score_exam ('./sample_exam.txt', './Exams/Arnold_Jenny.txt', './Exams/Berger_Carina.txt', './Exams/Frank_Tina.txt', './Exams/Haas_Charlotte.txt');

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
        my $num_correct_answers = 0;
        my $answered_questions = 0;

        for my $completed_question (@completed_questions) {
            my ($similar_master_question) = grep { distance_calc($completed_question, $_) } @master_questions;

            if ($similar_master_question && $completed_question ne $similar_master_question) {
                $feedback{$completed_file}{"questions"}{$completed_question} = $similar_master_question;
            }
            next unless $similar_master_question;

            for my $answer (keys %{$completed_answer_sets{$completed_question}}) {

                if ($completed_answer_sets{$completed_question}->{$answer} eq "X") {
                    $answered_questions++;
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
        }

        # Score over the total number of questions in the master file
        push @questions_answered, $answered_questions;
        push @correct_answers, $num_correct_answers;

        print "$completed_file...........$num_correct_answers/$answered_questions\n\n";

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

    my $avg_questions_answered = int(sum(@questions_answered) / scalar(@questions_answered));
    my $avg_correct_answers = int(sum(@correct_answers) / scalar(@correct_answers));

    my $min_questions_answered = int(min(@questions_answered));
    my $max_questions_answered = int(max(@questions_answered));
    my $min_correct_answers = int(min(@correct_answers));
    my $max_correct_answers = int(max(@correct_answers));

    # Count occurrences of min and max values
    my $count_min_questions_answered = grep { $_ == $min_questions_answered } @questions_answered;
    my $count_max_questions_answered = grep { $_ == $max_questions_answered } @questions_answered;

    my $count_min_correct_answers = grep { $_ == $min_correct_answers } @correct_answers;
    my $count_max_correct_answers = grep { $_ == $max_correct_answers } @correct_answers;

    my $std_dev_questions_answered = standard_deviation(@questions_answered);
    my $std_dev_correct_answers = standard_deviation(@correct_answers);

    print "\n\tAverage number of questions answered...... $avg_questions_answered\n";
    print "\t\t\t\t    Minimum....... $min_questions_answered ($count_min_questions_answered student", ($count_min_questions_answered == 1 ? "" : "s"), ")\n";
    print "\t\t\t\t    Maximum....... $max_questions_answered ($count_max_questions_answered student", ($count_max_questions_answered == 1 ? "" : "s"), ")\n";

    print "\n\tAverage number of correct answers......... $avg_correct_answers\n";
    print "\t\t\t\t  Minimum......... $min_correct_answers ($count_min_correct_answers student", ($count_min_correct_answers == 1 ? "" : "s"), ")\n";
    print "\t\t\t\t  Maximum......... $max_correct_answers ($count_max_correct_answers student", ($count_max_correct_answers == 1 ? "" : "s"), ")\n";



    # Calculate the mean score
    my $mean_score = sum(@correct_answers) / @correct_answers;

    # Calculate the standard deviation of the scores
    my $std_dev = standard_deviation(@correct_answers);

    # Define the 25th percentile threshold
    my @sorted_scores = sort { $a <=> $b } @correct_answers;
    my $twenty_fifth_percentile = $sorted_scores[int(0.25 * @sorted_scores)];

    print "\nResults below expectation:\n";

    for my $i (0 .. $#completed_files) {
    my @reasons;

    # Check if score is less than 50% of the total questions.
    push @reasons, 'score < 50%' if $correct_answers[$i] < @master_questions / 2 && $questions_answered[$i] != 0;

    # Check if score is more than one standard deviation below the mean.
    push @reasons, 'score > 1σ below mean' if $correct_answers[$i] < $mean_score - $std_dev && $questions_answered[$i] != 0;

    # Check if score is in the bottom 25% of all scores.
    # Note: This assumes you have already calculated the $twenty_fifth_percentile variable elsewhere.
    push @reasons, 'bottom 25% of cohort' if $correct_answers[$i] <= $twenty_fifth_percentile && $questions_answered[$i] != 0;

    push @reasons, 'Possible empty file' if $questions_answered[$i] == 0;

    if (@reasons) {
        printf("%s........%02d/%02d (%s)\n", $completed_files[$i], $correct_answers[$i], $questions_answered[$i], join(", ", @reasons));
    }
}


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

sub standard_deviation {
    my @numbers = @_;
    my $count = scalar @numbers;
    my $sum = 0;
    $sum += $_ for @numbers;

    my $mean = $sum / $count;

    $sum = 0;
    $sum += ($_ - $mean)**2 for @numbers;

    return sqrt($sum / $count);
}

