#! /usr/bin/env perl

use 5.022;
use experimentals;
use Data::Show;

my $ini_data_ref = load_INI( './IDE_config.ini' );

show $ini_data_ref;


sub load_INI ($filename) {

    # Regexes that match the various kinds of lines in an INI file
    my $HEADER_PAT = qr{ \A \h* \[  (?<header> .*)  \] \h* \Z }xms;
    my $KEYVAL_PAT = qr{ \A \h* (?<key> [^=]*? ) \h* = \h* (?<value> .*?) \h* \Z }xms;
    my $EMPTY_PAT  = qr{ \A \h* (; .*)? \Z }xms;

    # The data structure we're building...
    my %data;

    # Track the current section header...
    my $current_header = "";

    # Open the file for reading...
    open my $filehandle, '<', $filename
       or die "Couldn't open $filename: $!";

    # Read in each line one-per-loop...
    while (my $nextline = readline( $filehandle )) {

        # Is the line a section header???
        if ($nextline =~ $HEADER_PAT) {

            # If so, this is now the current header...
            $current_header = $+{header};

            # Set up the nested hash for this header...
            $data{ $current_header } = {};
        }

        # Is the line a key/value line???
        elsif ($nextline =~ $KEYVAL_PAT) {

            # If so, store the value under the key within the hash for the current header...
            $data{ $current_header }{ $+{key} } = $+{value};
        }

        # Is the line empty (or a comment)...
        elsif ($nextline =~ $EMPTY_PAT) {
            # Do nothing
        }

        # Warn about anything else in the file...
        else {
            warn "I don't know what this line means: $nextline";
        }
    }

    # Once the file is fully processed and the data structure built, return a reference to it...
    return \%data;
}

