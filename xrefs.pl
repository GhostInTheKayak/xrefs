#
#   Scan all text files for cross references to other text files
#
#   Libraries
#   switches
#   constants
#   global hashes
#
#   SUB found_something -- call-back from Find - called for every directory and file in turn during pass 1
#   SUB scan_file -- scan a text file for xrefs
#
#   Begin
#   PASS 1 -- build a hash of all of the directories and files in the tree
#   PASS 2 -- examine each file for references
#   PASS 3 -- Report totals and misc lists
#   Wind up
#   End
#

###     Libraries

use POSIX qw(strftime);
use File::Find;
use File::Spec;

###     switches

#   pass 1

$pass1_list_all_files           = 0;
$pass1_list_dir_names           = 0;
$pass1_list_dirs_overwrite      = 0;
$pass1_list_file_names          = 1;
$pass1_list_files_overwrite     = 0;

#   pass 2

$pass2_list_file_names          = 0;
$pass2_list_files_overwrite     = 0;
$pass2_list_bad_underlines      = 1;
$pass2_list_xrefs               = 1;

#   pass 3

$pass3_list_dirs_with_space     = 1;
$pass3_list_all_targets         = 1;
$pass3_list_valid_targets       = 0;
$pass3_list_broken              = 1;
$pass3_list_bad_underlines      = 1;
$pass3_list_targets_with_spaces = 1;
$pass3_list_targets_not_txt     = 1;

###     constants

$blanks                 = " " x 40;

$all_files_prefix       = "GOT  ";
$dir_found_prefix       = "DIR  ";
$file_found_prefix      = "FILE ";
$file_scanned_prefix    = "SCAN ";

$source_file_prefix     = "";
$space_xref_prefix      = " > > ";
$not_txt_xref_prefix    = " >?> ";
$good_xref_prefix       = " >>> ";

$space_xref_suffix      = " === cross reference includes a space";
$not_txt_xref_suffix    = " === cross reference to a non-TXT file";
$bad_underlining_suffix = " === bad title underlining";

###     global hashes

my  %all_files;
#
#   holds   all the files (and directories) found under the root directory
#   key     full path and file name
#   value   $all_files{$file_name}++;
#   printed when added in pass 1 if $pass1_list_all_files or $pass1_list_file_names

my  %all_directories;
#
#   holds   all the directories found under the root directory
#   key     full path and directory name
#   value   $all_directories{$file_name}++;
#   printed when added in pass 1 if $pass1_list_all_files or $pass1_list_dir_names

my  %dirs_with_space;
#
#   holds   all the directories including a space in the name
#   key     full path and directory name
#   value   $dirs_with_space{$file_name}++;
#   printed in pass 3 if $pass3_list_dirs_with_space

my  %files_with_bad_underlines;
#
#   holds
#   key     full path and file name
#   value   $files_with_bad_underlines{$this_file}++;
#   printed in pass 3 if $pass3_list_bad_underlines

my  %all_targets;
#
#   holds
#   key     full path and file name
#   value   $all_targets{$target}++;
#   printed in pass 2 if $pass2_list_xrefs
#   printed in pass 3 if $pass3_list_all_targets

my  %targets_not_txt;
#
#   holds   all the referenced files that are not *.TXT
#   key     full path and file name
#   value   $targets_not_txt{$target}++;
#   printed in pass 2 if $pass2_list_xrefs
#   printed in pass 3 if $pass3_list_targets_not_txt

my  %targets_with_space;
#
#   holds   all the referenced files that include a space in the file name
#   key     full path and file name
#   value   $targets_with_space{$target}++;
#   printed in pass 2 if $pass2_list_xrefs
#   printed in pass 3 if $pass3_list_targets_with_spaces

###     SUB found_something -- call-back from Find - called for every directory and file in turn during pass 1

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
        $all_directories{$file_name}++;
        if ($file_name =~ /\s/) {
            $dirs_with_space{$file_name}++;
        }
    } else {
        print "$file_found_prefix$file_name\n" if ($pass1_list_all_files || $pass1_list_file_names);
        print "$file_found_prefix$file_name$blanks\r" if ($pass1_list_files_overwrite);
        $all_files{$file_name}++;
    }
}

###     SUB scan_file -- scan a text file for xrefs
#
#   look for well formed titles
#   look for lines which are file names
#
#   p1  external directory to look for
#   p2  this file name
#

sub scan_file {

    my $title = "";
    my $last_line = "";
    my $line_number = 0;
    my $title_matches = 0;
    my $external_dir = shift;
    my $this_file = shift;
    my $output_filename = 1;
    my $left_length = length($external_dir);

    print "$file_scanned_prefix$this_file\n" if ($pass2_list_file_names);
    print "$file_scanned_prefix$this_file$blanks\r" if ($pass2_list_files_overwrite);

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
                    $files_with_bad_underlines{$this_file}++;

                    if ($pass2_list_bad_underlines) {
                        print "$source_file_prefix$this_file\n" if ($output_filename);
                        $output_filename = 0;
                        print "$bad_underlining_suffix\n";
                    }
                }
            }
            # else ignore the second line
        }

        #   remember the last non-blank line. check it at the end to see if it is "=== END"

        $last_line = $_ if ($_);

        #   check each line for a possible file name

        $target = lc $_;
        my $left_part = substr( $target, 0, $left_length);

#       print "+++ left=$left_part startingdir=$external_dir\n";

        if ( $left_part eq $external_dir ) {

            #   The line starts with the $starting directory and so is probably a file name
            #   TODO    check if the file ref is badly formed BUT does in fact match a target file

            #   check if the cross reference is to a file with spaces in the name

            if ( $target =~ /\s/ ) {
                $targets_with_space{$target}++;
                if ($pass2_list_xrefs) {
                    print "$source_file_prefix$source\n" if ($output_filename);
                    $output_filename = 0;
                    print "$space_xref_prefix$target$space_xref_suffix\n";
                }

                next;   #   26 January 2012
            }

            #   check if cross reference is not to a text file

            unless ( $target =~ /.txt$/ ) {
                $targets_not_txt{$target}++;
                if ($pass2_list_xrefs) {
                    print "$source_file_prefix$source\n" if ($output_filename);
                    $output_filename = 0;
                    print "$not_txt_xref_prefix$target$not_txt_xref_suffix\n";
                }

                next;   #   26 January 2012
            }

            $xref_count++;
            $all_targets{$target}++;

            if ($pass2_list_xrefs) {
                print "$source_file_prefix$source\n" if ($output_filename);
                $output_filename = 0;
                print "$good_xref_prefix$target\n";
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

###     Begin

print "\nCross reference scan -- 04 April 2013 -- Ian Higgs\n";

$starting_dir = shift;
unless ( -d $starting_dir ) {
    die "\nDirectory $starting_dir does not exist\n";
}

$stamp = strftime( "%a %d %b %Y @ %H:%M:%S", localtime );
print "\nStarted $stamp\n";

$source_count = 0;
$xref_count = 0;

###     PASS 1 -- build a hash of all of the directories and files in the tree

print "\n=== PASS 1 -- Scanning directory tree below $starting_dir\n\n"
    if ($pass1_list_all_files || $pass1_list_dir_names || $pass1_list_dirs_overwrite || $pass1_list_file_names || $pass1_list_files_overwrite);

&find({ wanted => \&found_something }, $starting_dir);

$directory_count = keys %all_directories;
$file_count = (keys %all_files) - $directory_count;

###     PASS 2 -- examine each file for references

print "\n=== PASS 2 -- Scanning files for xrefs\n\n" if ($pass2_list_xrefs);

foreach $source (sort keys %all_files ) {
    if ( $source =~ /.*\.txt$/ ) {
        $source_count++;
        &scan_file( lc $starting_dir, $source );
    }
}

$target_count = keys %all_targets;

###     PASS 3 -- Report totals and misc lists

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

    foreach $target (sort keys %all_targets ) {
        if ($all_files{$target}) {
            $known_count++;
            if ($all_targets{$target} > 1)
            {
                print "$all_targets{$target} valid xrefs to $target\n";
            } else {
                print "One valid xref to $target\n";
            }
        } else {
            $unknown_count++;
            if ($all_targets{$target} > 1) {
                print "$all_targets{$target} broken xrefs for $target\n";
            } else {
                print "One broken xrefs for $target\n";
            }
        }
    }
    print "\n$known_count valid targets and $unknown_count broken xrefs\n";
}

if ($pass3_list_valid_targets) {
    print "\n=== Valid target files\n\n";

    foreach $target (sort keys %all_targets ) {
        print "$all_targets{$target} ~ $target\n" if ($all_files{$target});
    }
}

if ($pass3_list_broken) {
    print "\n=== Missing target files\n\n";

    foreach $target (sort keys %all_targets ) {
        print "$all_targets{$target} ~ $target\n" unless ($all_files{$target});
    }
}

if ($pass3_list_bad_underlines) {
    print "\n=== Files with incorrectly underlined title\n\n";

    foreach $target (sort keys %files_with_bad_underlines) {
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
    print "\n=== Target files not .TXT\n\n";

    foreach $target (sort keys %targets_not_txt) {
        print "$targets_not_txt{$target} ~ $target\n";
    }
}

###     Wind up

print "\n=== Summary\n\n";

print "Scanned $file_count files in $directory_count directories\n";
print "Found $source_count files and $xref_count cross references\n";
print "Found $target_count different target files\n";

$stamp = strftime( "%a %d %b %Y @ %H:%M:%S", localtime );

print "\nFinished $stamp\n\n";

###     End
