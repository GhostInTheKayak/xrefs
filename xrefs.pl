#
#   Scan all text files for cross references to other text files
#
#   Assumes that a text file will have a .txt suffix    (I am not an animal)
#
### Libraries
### switches
### constants
### global hashes
#
### SUB found_something
### SUB scan_file
### SUB output_help
### SUB start_section
### SUB report_line
### SUB report_filename
### SUB filename_and_line
#
### Begin
### PASS 1 -- build a hash of all of the directories and files in the tree
### PASS 2 -- examine use of directory names
### PASS 3 -- examine use of filenames
### PASS 4 -- examine each file for references
### PASS 5 -- Report totals and misc lists
### Summary
### End
#

### Libraries

use POSIX qw(strftime);
use File::Find;
use File::Spec;

### switches

#   debug

$debug_found_something_output   = 0;

#   pass 1

$pass1_list_all_files           = 0;
$pass1_list_dir_names           = 0;
$pass1_list_dirs_overwrite      = 0;
$pass1_list_file_names          = 0;
$pass1_list_files_overwrite     = 0;

#   pass 2

$pass2_list_dirs_with_space     = 1;

#   pass 3

$pass3_list_files_with_space    = 0;
$pass3_list_duplicate_filenames = 0;
$pass3_list_duplicate_txt_filenames = 1;

#   pass 4

$pass4_list_file_names          = 0;
$pass4_list_files_overwrite     = 0;
$pass4_list_bad_underlines      = 1;
$pass4_list_xrefs               = 1;
$pass4_list_xrefs_source        = 0;
$pass4_list_todo_tags           = 1;
$pass4_list_todo_sections       = 1;

#   pass 5

$pass5_output_target_counts     = 1;
$pass5_list_valid_targets       = 0;
$pass5_list_missing_targets     = 1;
$pass5_list_bad_underlines      = 1;
$pass5_list_targets_with_space  = 1;
$pass5_list_targets_not_txt     = 1;
$pass5_list_todo_tags           = 1;
$pass5_list_todo_sections       = 1;

### constants

$crlf                   = "\n";
$space                  = ' ';
$blanks                 = $space x 40;

$tag_section            = '=' x 3;
$tag_todo_section       = $tag_section . ' todo';
$tag_todo               = '\[\[\[todo\]\]\]';
$tag_end                = $tag_section . ' END';

$prefix_xref            = $space x 4;
$suffix_start           = ' --';
$suffix_end             = '-- ';

$prefix_all_files       = 'GOT  ';
$prefix_dir_found       = '';
$prefix_file_found      = $prefix_xref;
$prefix_file_scanned    = 'SCAN ';

$prefix_source_file     = '';

$prefix_space_xref      = $prefix_xref;
$suffix_space_xref      = $suffix_start . 'SP' . $suffix_end;

$prefix_not_txt_xref    = $prefix_xref;
$suffix_not_txt_xref    = $suffix_start . 'text?' . $suffix_end;

$prefix_good_xref       = $prefix_xref;
$suffix_good_xref       = $suffix_start . 'XREF' . $suffix_end;

$prefix_todo_tag        = $prefix_xref;
$suffix_todo_tag        = $suffix_start . 'TODO' . $suffix_end;

$prefix_todo_section    = $prefix_xref;
$suffix_todo_section    = $suffix_start . 'todo' . $suffix_end;

$prefix_bad_underlining = $prefix_xref;
$suffix_bad_underlining = $suffix_start . 'UL' . $suffix_end;

$file_source_sep        = $crlf;
$file_source_expanded   = $crlf . $prefix_xref;

### global hashes

my  %all_files_hash;
my  $all_files_count = 0;
#
#   holds   all the files (and directories) found under the root directory
#   key     full path and file name
#   value   1
#   printed when added in pass 1 if $pass1_list_all_files or $pass1_list_file_names

my  %all_directories_hash;
my  $all_directories_count = 0;
#
#   holds   all the directories found under the root directory
#   key     full path and directory name
#   value   1
#   printed when added in pass 1 if $pass1_list_all_files or $pass1_list_dir_names

my  %dirnames_with_space_hash;
my  $dirnames_with_space_count = 0;
#
#   holds   all the directories including a space in the name
#   key     full path and directory name
#   value   1
#   printed in pass 2 if $pass2_list_dirs_with_space

my  %filenames_with_space_hash;
my  $filenames_with_space_count = 0;
#
#   holds   all the files including a space in the name
#   key     full path and directory name
#   value   1
#   printed in pass 3 if $pass3_list_files_with_space

my  %all_filenames_hash;
#
#   holds   all of the filenames
#   key     filename
#   value   count
#   not printed - helper for building duplicate_filenames_hash

my  %duplicate_filenames_hash;
my  $duplicate_filenames_count;
#
#   holds   all of the duplicated filenames
#           entries from all_filenames_hash where value>1
#   key     filename
#   value   n * ("\n    " . full path and filename)
#   printed in pass 3 if $pass3_list_duplicate_filenames

my  %duplicate_txt_filenames_hash;
my  $duplicate_txt_filenames_count;
#
#   holds   all of the duplicated .txt filenames
#           entries from all_filenames_hash where value>1
#   key     filename
#   value   n * ("\n    " . full path and filename)
#   printed in pass 3 if $pass3_list_duplicate_txt_filenames

my  %files_with_bad_underlines_hash;
my  $files_with_bad_underlines_count = 0;
#
#   holds   all files where line 2 is = signs but does not match line 1
#   key     full path and file name
#   value   1
#   printed in pass 5 if $pass5_list_bad_underlines

my  %all_targets_hash;
my  $all_targets_count = 0;     # count of distinct targets
my  $valid_xref_count = 0;      # count of xrefs to targets (target itself may not be good)
#
#   holds   target of cross references found in the text files
#   key     full path and file name
#   value   count of inbound xrefs
#   printed in pass 4 if $pass4_list_xrefs

my  $missing_targets_hash;
my  $existing_targets_file_count = 0;   # count of target files that do exist
my  $missing_targets_file_count = 0;    # count of target files that are missing
my  $missing_targets_count = 0;         # count of xrefs to target files that are missing
#
#   holds   cross reference targets not found
#   key     full path and file name
#   value   count of inbound xrefs
#   printed in pass 5 if $pass5_list_missing_targets

my  %targets_not_txt_hash;
my  $targets_not_txt_count = 0;
#
#   holds   all the referenced files that are not *.TXT
#   key     full path and file name
#   value   $targets_not_txt_hash{$target}++;
#   printed in pass 4 if $pass4_list_xrefs
#   printed in pass 5 if $pass5_list_targets_not_txt

my  %targets_with_space_hash;
my  $targets_with_space_count = 0;
#
#   holds   all the xref lines that include a space
#   key     full path and file name
#   value   $targets_with_space_hash{$target}++;
#   printed in pass 4 if $pass4_list_xrefs
#   printed in pass 5 if $pass5_list_targets_with_space

my  %files_with_todo_tag_hash;
my  $tag_todo_count = 0;
#
#   holds   all the files that include a TODO tag
#   key     full path and file name
#   value   $files_with_todo_tag{$target}++;
#   printed in pass 4 if $pass4_list_todo_tags
#   printed in pass 5 if $pass5_list_todo_tags

my  %files_with_todo_section_hash;
my  $files_with_todo_section_count = 0;
my  $todo_section_count = 0;
#
#   holds   all the files that include a TODO section
#   key     full path and file name
#   value   $files_with_todo_section_hash{$target}++;
#   printed in pass 4 if $pass4_list_todo_sections
#   printed in pass 5 if $pass5_list_todo_sections

### SUB found_something
#
#   call-back from Find
#   called for every directory and file in turn during pass 1
#
#   full path           $File::Find::name
#   directory name      $File::Find::dir
#   file name           $_
#

sub found_something {

    $just_filename = lc $_;
    $just_dirname = lc $File::Find::dir;
    $just_dirname =~ s/\//\\/g;
    $path_and_filename = lc (File::Spec->canonpath($File::Find::name));

    print $prefix_all_files, $path_and_filename, $crlf if ($pass1_list_all_files);

    print "DIR=".$just_dirname ." FILE=".$just_filename ."\n" if ($debug_found_something_output);

    if (-d $path_and_filename) {
        print "$prefix_dir_found$path_and_filename\n" if ($pass1_list_all_files || $pass1_list_dir_names);
        print "$prefix_dir_found$path_and_filename$blanks\r" if ($pass1_list_dirs_overwrite);
        $all_files_hash{$path_and_filename}++;
        $all_directories_hash{$path_and_filename}++;
        $all_directories_count++;

        #   space in directory name?
        if ($path_and_filename =~ /\s/) {
            $dirnames_with_space_hash{$path_and_filename}++;
            $dirnames_with_space_count++;
        }
    } else {
        print "$prefix_file_found$path_and_filename\n" if ($pass1_list_all_files || $pass1_list_file_names);
        print "$prefix_file_found$path_and_filename$blanks\r" if ($pass1_list_files_overwrite);
        $all_files_hash{$path_and_filename}++;
        $all_files_count++;

        #   space in filename?
        if ($just_filename =~ /\s/) {
            $filenames_with_space_hash{$path_and_filename}++;
            $filenames_with_space_count++;
        }

        #   duplicate filename?
        if (exists($all_filenames_hash{$just_filename})) {
            $duplicate_filenames_hash{$just_filename}++;
            if ($just_filename =~ /\.txt$/) {
                $duplicate_txt_filenames_hash{$just_filename}++;
            }
        }
        $all_filenames_hash{$just_filename} .= $file_source_sep . $path_and_filename;
    }
}

### SUB scan_file
#
#   scan a text file that we have already found
#
#   check the file starts with a well formed title
#   look for lines which include various forms of TODO tags
#   look for lines which are references to other files under the base directory
#
#   p1  base directory
#   p2  this file name
#

sub scan_file {

    my ($external_dir, $this_file) = @_;

    my $title = "";
    my $last_line = "";
    my $line_number = 0;
    my $title_matches = 0;
    my $output_filename = 1;
    my $left_length = length($external_dir);

    print "$prefix_file_scanned$this_file\n" if ($pass4_list_file_names);
    print "$prefix_file_scanned$this_file$blanks\r" if ($pass4_list_files_overwrite);

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
                    $files_with_bad_underlines_hash{$this_file}++;
                    $files_with_bad_underlines_count++;

                    if ($pass4_list_bad_underlines) {
                        report_filename($this_file) if ($output_filename);
                        $output_filename = 0;
                        print "$prefix_bad_underlining\n";
                        report_line($prefix_bad_underlining, filename_and_line($source, $line_number), $suffix_bad_underlining, '');

                    }
                }
            }
            # else ignore the second line
        }

        #   remember the last non-blank line. check it at the end to see if this is a good Notefile

        $last_line = $_ if ($_);

        #   check each line for a possible file name

        $current_line = $_;
        $target = lc $_;
        my $left_part = substr( $target, 0, $left_length);

#       print "+++ left=$left_part startingdir=$external_dir\n";

        if ( $left_part eq $external_dir ) {

            #   The line starts with the $starting directory and so is probably a file name
            #   TODO    check if the file ref is badly formed BUT does in fact match a target file

            #   check if the cross reference is to a file followed by a space

            if ( $target =~ /\s/ ) {
                $targets_with_space_hash{$target}++;
                $targets_with_space_count++;
                if ($pass4_list_xrefs) {
                    report_filename($source) if ($output_filename);
                    $output_filename = 0;
                    report_line($prefix_space_xref, filename_and_line($source, $line_number), $suffix_space_xref, $current_line);
                }

                next;   #   26 January 2012
            }

            #   check if cross reference is not to a text file
            #   TODO    it could be to a directory...

            unless ( $target =~ /.txt$/ ) {
                $targets_not_txt_hash{$target}++;
                $targets_not_txt_count++;
                if ($pass4_list_xrefs) {
                    report_filename($source) if ($output_filename);
                    $output_filename = 0;
                    report_line($prefix_not_txt_xref, filename_and_line($source, $line_number), $suffix_not_txt_xref, $target);
                }

                next;   #   26 January 2012
            }

            $all_targets_hash{$target}++;
            $valid_xref_count++;

            if ($pass4_list_xrefs) {
                report_filename($source) if ($output_filename);
                $output_filename = 0;
                report_line($prefix_good_xref, '', '', $target) unless ($pass4_list_xrefs_source);
                report_line($prefix_good_xref, filename_and_line($source, $line_number), $suffix_good_xref, $target) if ($pass4_list_xrefs_source);
            }
        }

        #   check each line for a possible TODO tag

        if ( $target =~ /$tag_todo/ ) {

            $files_with_todo_tag_hash{$this_file}++;
            $tag_todo_count++;

            if ($pass4_list_todo_tags) {
                report_filename($source) if ($output_filename);
                $output_filename = 0;
                report_line($prefix_todo_tag, filename_and_line($source, $line_number), $suffix_todo_tag, $current_line);
            }
        }

        #   check each line for a TODO section

        if ( $target =~ /^$tag_todo_section/ ) {

            $files_with_todo_section_hash{$this_file}++;
            $todo_section_count++;

            if ($pass4_list_todo_sections) {
                report_filename($source) if ($output_filename);
                $output_filename = 0;
                report_line($prefix_todo_section, filename_and_line($source, $line_number), $suffix_todo_section, $current_line);
            }
        }


    }

#   at EOF - do we have a well-formed Notefile?
#   print "$last_line\n";

    if ($last_line eq $tag_end) {
        if ($title_matches) {
            #   clean notefile
            #   TODO    record notefile name
        } else {
            #   unclean notefile
            #   TODO    record file name ...
        }
    }
}

### SUB output_help
#
#   Just output some friendly help text
#

sub output_help
{
    print STDERR <<ENDhelptext;

Usage: $0 [starting directory]

ENDhelptext
}

### SUB start_section
#
#   Just output a header for the section
#
#   p1  title
#

sub start_section
{
    my ($title) = @_;
    print $crlf, $tag_section, ' ', $title, $crlf, $crlf;
}

### SUB report_line
#
#   Report a finding of some some
#
#   p1  prefix      string to start the line
#   p2  filename
#   p3  suffix      string to follow the filename
#   p4  rest        anything else to print at the end of the line
#

sub report_line
{
    my ($prefix, $filename, $suffix, $rest) = @_;
    print $prefix, $filename, $suffix, $rest, $crlf;
}

### SUB report_filename
#
#   Report the filename
#
#   p1  filename
#

sub report_filename
{
    my ($filename) = @_;
    print $prefix_source_file, $filename, $crlf;
}

### SUB filename_and_line
#
#   Report the filename and line number as a viable link
#
#   p1  filename
#   p2  line number
#

sub filename_and_line
{
    my ($filename, $linenumber) = @_;
    return $filename . '(' . $linenumber . ')';
}

### Begin

print "\nCross reference scanner -- 09 June 2019 -- Ian Higgs\n";

$root_dir = shift;

unless ( $root_dir ) {
    output_help;
    exit(1);
}

( -d $root_dir ) or die "\nDirectory $root_dir does not exist\n";

$stamp = strftime( "%a %d %b %Y @ %H:%M:%S", localtime );
print "\nStarted $stamp\n";

### PASS 1 -- build a hash of all of the directories and files in the tree

start_section("PASS 1 -- Scanning directory tree below $root_dir");

&find({ wanted => \&found_something }, $root_dir);

### PASS 2 -- examine use of directory names

start_section("PASS 2 -- Checking directory names");

if ($dirnames_with_space_count && $pass2_list_dirs_with_space) {
    start_section("$dirnames_with_space_count Directory names with a space");

    foreach $dir (sort keys %dirnames_with_space_hash) {
        print $dir, $crlf;
    }
}

### PASS 3 -- examine use of filenames

start_section("PASS 3 -- Checking filenames");

#   filename includes a space

if ($filenames_with_space_count && $pass3_list_files_with_space) {
    start_section("$filenames_with_space_count filenames with a space");

    foreach $filename (sort keys %filenames_with_space_hash) {
        print $filename, $crlf;
    }
}

#   all duplicate filenames

$duplicate_filenames_count = scalar keys %duplicate_filenames_hash;
if ($pass3_list_duplicate_filenames && $duplicate_filenames_count) {
    start_section("$duplicate_filenames_count duplicate filenames");

    foreach $filename (sort keys %duplicate_filenames_hash) {
        print "$filename -- ";
        print $duplicate_filenames_hash{$filename} +1;
        $s = $all_filenames_hash{$filename};
        $s =~ s/$file_source_sep/$file_source_expanded/g;
        print $s;
        print "\n";
    }
}

#   duplicate filenames only for .txt files

$duplicate_txt_filenames_count = scalar keys %duplicate_txt_filenames_hash;
if ($pass3_list_duplicate_txt_filenames && $duplicate_txt_filenames_count) {
    start_section($duplicate_txt_filenames_count . ' duplicate .txt filenames');

    foreach $filename (sort keys %duplicate_txt_filenames_hash) {
        print $filename;
        # print " -- " . ($duplicate_txt_filenames_hash{$filename} +1);
        $s = $all_filenames_hash{$filename};
        $s =~ s/$file_source_sep/$file_source_expanded/g;
        print $s;
        print "\n";
    }
}

### PASS 4 -- examine each file for references

start_section("PASS 4 -- Scanning text files");
$source_count = 0;

foreach $source (sort keys %all_files_hash ) {
    if ( $source =~ /.*\.txt$/ ) {
        $source_count++;
        &scan_file( lc $root_dir, $source );
    }
}

$all_targets_count = scalar keys %all_targets_hash;

### PASS 5 -- Report totals and misc lists

start_section("PASS 5 -- Summary");

foreach $target (sort keys %all_targets_hash ) {
    if (exists($all_files_hash{$target})) {
        $existing_targets_file_count++;
    } else {
        $missing_targets_file_count++;
        $missing_targets_hash{$target}++;
        $missing_targets_count += $all_targets_hash{$target};
    }
}
print "$existing_targets_file_count existing targets and $missing_targets_file_count missing targets\n";

if ($pass5_list_valid_targets) {
    start_section("Valid target files");

    foreach $target (sort keys %all_targets_hash ) {
        if (exists($all_files_hash{$target})) {
            print "$all_targets_hash{$target} ~ " if ($pass5_output_target_counts);
            print "$target\n";
        }
    }
}

if ($targets_not_txt_count && $pass5_list_targets_not_txt) {
    start_section("$targets_not_txt_count targets that are not text files");

    foreach $target (sort keys %targets_not_txt_hash) {
        print "$targets_not_txt_hash{$target} ~ " if ($pass5_output_target_counts);
        print "$target\n";
    }
}

if ($targets_with_space_count && $pass5_list_targets_with_space) {
    start_section("Target lines include spaces");

    foreach $target (sort keys %targets_with_space_hash) {
        print "$targets_with_space_hash{$target} ~ " if ($pass5_output_target_counts);
        print "$target\n";
    }
}

if ($todo_section_count && $pass5_list_todo_sections) {
    $files_with_todo_section_count = scalar keys %files_with_todo_section_hash;
    start_section("$todo_section_count TODO sections in $files_with_todo_section_count files");

    foreach $target (sort keys %files_with_todo_section_hash) {
        print "$target\n";
    }
}

if ($tag_todo_count && $pass5_list_todo_tags) {
    $files_with_todo_tag_count = scalar keys %files_with_todo_tag_hash;
    start_section("$tag_todo_count [[[TODO]]] tags in $files_with_todo_tag_count files");

    foreach $target (sort keys %files_with_todo_tag_hash) {
        print "$target\n";
    }
}

if ($missing_targets_file_count && $pass5_list_missing_targets) {
    start_section("$missing_targets_count references to $missing_targets_file_count missing files");

    foreach $target (sort keys %all_targets_hash ) {
        unless (exists($all_files_hash{$target})) {
            print "$all_targets_hash{$target} ~ " if ($pass5_output_target_counts);
            print "$target\n";
        }
    }

    start_section("TEST $missing_targets_count references to $missing_targets_file_count missing files");
    foreach $target (sort keys %missing_targets_hash) {
        print "$all_targets_hash{$target} ~ " if ($pass5_output_target_counts);
        print "$target\n";
    }


}

if ($files_with_bad_underlines_count && $pass5_list_bad_underlines) {
    start_section("$files_with_bad_underlines_count Files with an incorrectly underlined title");

    foreach $target (sort keys %files_with_bad_underlines_hash) {
        print "$target\n";
    }
}

### Summary

start_section("Summary");

print "PASS 1 -- Scanning directory tree below $root_dir\n";
print "    $all_files_count files in $all_directories_count directories\n";
print "PASS 2 -- Checking directory names\n";
print "    $dirnames_with_space_count directory names with a space\n";
print "PASS 3 -- Checking filenames\n";
print "    $filenames_with_space_count filenames with a space\n";
print "    $duplicate_filenames_count duplicate filenames\n";
print "    $duplicate_txt_filenames_count duplicate .txt filenames\n";
print "PASS 4 -- Scanned $source_count text files\n";
print "    $valid_xref_count valid references to $all_targets_count different target files\n";
print "PASS 5 -- Summary\n";
print "    $targets_not_txt_count targets that are not text files\n";
print "    $targets_with_space_count target lines include spaces\n";
print "    $todo_section_count TODO sections in $files_with_todo_section_count files\n";
print "    $tag_todo_count [[[TODO]]] tags in $files_with_todo_tag_count files\n";
print "    $missing_targets_count references to $missing_targets_file_count missing files\n";
print "    $files_with_bad_underlines_count files with an incorrectly underlined title\n";

$stamp = strftime( "%a %d %b %Y @ %H:%M:%S", localtime );

print "\nFinished $stamp\n\n";

### End
