#
#   Scan all text files for cross references to other text files
#

print "\nCross reference scan -- 11 September 2012 -- Ian Higgs\n";

####    control constants

$starting_dir                   = 'I:\';

####    PASS1 switches

$pass1_list_all_files           = 0;
$pass1_list_dir_names           = 0;
$pass1_list_dirs_overwrite      = 0;
$pass1_list_file_names          = 1;
$pass1_list_files_overwrite     = 0;

####    PASS2 switches

$pass2_list_bad_underlines      = 1;
$pass2_list_xrefs               = 1;

####    PASS3 switches

$pass3_list_dirs_with_space     = 1;
$pass3_list_all_targets         = 1;
$pass3_list_valid_targets       = 0;
$pass3_list_broken              = 1;
$pass3_list_bad_underlines      = 1;
$pass3_list_targets_with_spaces = 1;
$pass3_list_targets_not_txt     = 1;

####    constants

$blanks                 = " " x 40;

$all_files_prefix       = "GOT  ";
$dir_found_prefix       = "DIR  ";
$file_found_prefix      = "FILE ";

$source_file_prefix     = "";
$space_xref_prefix      = "  >> ";
$not_txt_xref_prefix    = "  >> ";
$xref_prefix            = "  >> ";
$bad_underlining_prefix = "  == Bad title underlining";

####    Libraries

use POSIX qw(strftime);
use File::Find;
use File::Spec;

####    global hashes

#   holds   all the files (and directories) found under the root directory
#   key     full path and file
#   value   1 (to force)

my  %all_files;

#   holds
#   key
#   value

my  %targets_with_space;

####    PASS1   call-back from Find - called for every directory and file in turn

sub found_something {

    $file_count++;
    $file_name = $File::Find::name;
    $file_name = File::Spec->canonpath($file_name);
    $file_name = lc $file_name;
    print "$all_files_prefix$file_name\n" if ($pass1_list_all_files);

    if (-d $file_name) {
        print "$dir_found_prefix$file_name\n" if ($pass1_list_all_files || $pass1_list_dir_names);
        print "$dir_found_prefix$file_name$blanks\r" if ($pass1_list_dirs_overwrite);
        $all_files{$file_name}++;
        $directories{$file_name}++;
        if ($file_name =~ /\s/) {
            $dirs_with_space{$file_name}++;
        }
    } else {
        print "$file_found_prefix$file_name\n" if ($pass1_list_all_files || $pass1_list_file_names);
        print "$file_found_prefix$file_name$blanks\r" if ($pass1_list_files_overwrite);
        $all_files{$file_name}++;
    }
}

####    PASS2   scan a text file

sub scan_file {

    my $title = "";
    my $last_line = "";
    my $line_number = 0;
    my $title_matches = 0;
    my $this_file = shift;
    my $output_filename = 1;

    open(FILE,"<$this_file");

    while( <FILE> ) {

        chomp;
        $line_number++;
#       print "$line_number -- $_\n";

        #   if we are at the first line then remember it as the title

        if ($line_number == 1) {
            $title = $_;
        }

        #   if we are at the second line then see if it a line of = signs

        if ($line_number == 2) {
            if (/^=+$/) {
                if (length($title)==length($_)) {
                    #   title is correctly underlined
#                   print "$title\n$_\n";
                    $title_matches++;
                } else {
                    # title is underlined, but the underlines do not match
                    $file_with_bad_underlines{$this_file}++;

                    if ($pass2_list_bad_underlines) {
                        print "$source_file_prefix$this_file\n" if ($output_filename);
                        $output_filename = 0;
                        print "$bad_underlining_prefix\n";
                    }
                }
            }
            # else ignore the second line
        }

        #   remember the last non-blank line. check it at the end to see if it is "=== END"

        $last_line = $_ if ($_);

        #   check each line for a possible file name

        if ( /^$starting_dir/i ) {
            $target = lc $_;

            #   The line starts with the $starting directory and so is probably a file name
            #   TODO    check if the file ref is badly formed BUT does in fact match a target file
            #   check if the cross reference is to a file with spaces in the name

            if ( $target =~ /\s/ ) {
                $targets_with_space{$target}++;
                if ($pass2_list_xrefs) {
                    print "$source_file_prefix$source\n" if ($output_filename);
                    $output_filename = 0;
                    print "$space_xref_prefix$target *** cross reference includes a space\n";
                }

                next;   #   26 January 2012
            }

            #   check if cross reference is not to a text file
            unless ( $target =~ /.txt$/ ) {
                $targets_not_txt{$target}++;
                print "$source_file_prefix$source\n" if ($output_filename && $pass2_list_xrefs);
                $output_filename = 0;
                print "$not_txt_xref_prefix$target *** cross reference to a non-TXT file\n" if ($pass2_list_xrefs);

                next;   #   26 January 2012
            }

            $xref_count++;
            $targets{$target}++;

            if ($pass2_list_xrefs) {
                print "$source_file_prefix$source\n" if ($output_filename);
                $output_filename = 0;
                print "$xref_prefix$target\n";
            }
        }
    }

#   at EOF - do we have a well-formed notefile?
#   print "$last_line\n";

    if ($last_line eq "=== END") {
        if ($title_matches) {
            #   clean notefile
            #   TODO    record notefile name
        } else {
            #   unclean notefile
            #   TODO    record file name ...
        }
    }
}

####    Begin

$stamp = strftime( "%a %d %b %Y @ %H:%M:%S", localtime );
print "\nStarted $stamp\n";

$source_count = 0;
$xref_count = 0;

####    PASS 1 -- build a hash of all of the directories and files in the tree

print "\n=== PASS 1 -- Scanning directory tree\n\n"
    if ($pass1_list_all_files || $pass1_list_dir_names || $pass1_list_dirs_overwrite || $pass1_list_file_names || $pass1_list_files_overwrite);

&find({ wanted => \&found_something }, $starting_dir);

$directory_count = keys %directories;
$file_count = (keys %all_files) - $directory_count;

####    PASS 2 -- examine each file for references

print "\n=== PASS 2 -- Scanning files for xrefs\n\n" if ($pass2_list_xrefs);

foreach $source (sort keys %all_files ) {
    if ( $source =~ /.*\.txt$/ ) {
        $source_count++;
        &scan_file( $source );
    }
}

$target_count = keys %targets;

####    PASS 3 -- Report totals and misc lists

if ($pass3_list_dirs_with_space) {
    print "\n=== Directories with spaces\n\n";

    foreach $dir (sort keys %dirs_with_space) {
        print "$dir\n";
    }
}

if ($pass3_list_all_targets) {
    print "\n=== All target files\n\n";
    my $known_count = 0;
    my $unknown_count = 0;

    foreach $target (sort keys %targets ) {
        if ($all_files{$target}) {
            $known_count++;
            if ($targets{$target} > 1)
            {
                print "$targets{$target} valid xrefs to $target\n";
            } else {
                print "One valid xref to $target\n";
            }
        } else {
            $unknown_count++;
            if ($targets{$target} > 1) {
                print "$targets{$target} broken xrefs for $target\n";
            } else {
                print "One broken xrefs for $target\n";
            }
        }
    }
    print "\n$known_count valid targets and $unknown_count broken xrefs\n";
}

if ($pass3_list_valid_targets) {
    print "\n=== Valid target files\n\n";

    foreach $target (sort keys %targets ) {
        print "$targets{$target} ~ $target\n" if ($all_files{$target});
    }
}

if ($pass3_list_broken) {
    print "\n=== Missing target files\n\n";

    foreach $target (sort keys %targets ) {
        print "$targets{$target} ~ $target\n" unless ($all_files{$target});
    }
}

if ($pass3_list_bad_underlines) {
    print "\n=== File with incorrectly underlined title\n\n";

    foreach $target (sort keys %file_with_bad_underlines) {
        print "$target\n";
    }
}

if ($pass3_list_targets_with_spaces) {
    print "\n=== Target lines with spaces\n\n";

    foreach $target (sort keys %targets_with_space) {
        print "$targets_with_space{$target} ~ $target\n";
    }
}

if ($pass3_list_targets_not_txt) {
    print "\n=== Target lines not .TXT\n\n";

    foreach $target (sort keys %targets_not_txt) {
        print "$targets_not_txt{$target} ~ $target\n";
    }
}

####    Wind up

print "\n=== Summary\n\n";

print "Scanned $file_count files in $directory_count directories\n";
print "Found $source_count files and $xref_count cross references\n";
print "Found $target_count different target files\n";

$stamp = strftime( "%a %d %b %Y @ %H:%M:%S", localtime );

print "\nFinished $stamp\n\n";

####    End
