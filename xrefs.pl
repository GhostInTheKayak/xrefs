#
#   Scan all text files for cross references to other text files
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
#
### Begin
### PASS 1 -- build a hash of all of the directories and files in the tree
### PASS 2 -- examine each file for references
### PASS 3 -- Report totals and misc lists
### Wind up
### End
#

### Libraries

use POSIX qw(strftime);
use File::Find;
use File::Spec;

### switches

#   pass 1

$pass1_list_all_files           = 0;
$pass1_list_dir_names           = 1;
$pass1_list_dirs_overwrite      = 0;
$pass1_list_file_names          = 0;
$pass1_list_files_overwrite     = 0;

#   pass 2

$pass2_list_file_names          = 0;
$pass2_list_files_overwrite     = 0;
$pass2_list_bad_underlines      = 1;
$pass2_list_xrefs               = 1;
$pass2_list_todo_tags           = 1;
$pass2_list_todo_sections       = 1;

#   pass 3

$pass3_list_dirs_with_space     = 1;
$pass3_list_all_targets         = 0;
$pass3_list_valid_targets       = 0;
$pass3_list_broken              = 1;
$pass3_list_bad_underlines      = 1;
$pass3_list_targets_with_space  = 1;
$pass3_list_targets_not_txt     = 1;
$pass3_list_todo_tags           = 1;
$pass3_list_todo_sections       = 1;

### constants

$blanks                 = " " x 40;
$dash_tag               = "-" x 3;
$section_tag            = "=" x 3;
$todo_section_tag       = "$section_tag todo";
$todo_tag               = '\[\[\[todo\]\]\]';
$end_tag                = "$section_tag END";

$all_files_prefix       = "GOT  ";
$dir_found_prefix       = "DIR  ";
$file_found_prefix      = "FILE ";
$file_scanned_prefix    = "SCAN ";

$source_file_prefix     = "";
$space_xref_prefix      = " ?SP ";
$not_txt_xref_prefix    = " ?NT ";
$good_xref_prefix       = "     ";
$todo_tag_prefix        = " ?TT ";
$todo_section_prefix    = " ?TS ";

$bad_underlining_prefix = " ?UL ";

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

my  %dirs_with_space_hash;
my  $dirs_with_space_count = 0;
#
#   holds   all the directories including a space in the name
#   key     full path and directory name
#   value   1
#   printed in pass 3 if $pass3_list_dirs_with_space

my  %files_with_bad_underlines_hash;
my  $files_with_bad_underlines_count = 0;
#
#   holds   all files where line 2 is = signs but does not match line 1
#   key     full path and file name
#   value   1
#   printed in pass 3 if $pass3_list_bad_underlines

my  %all_targets_hash;
my  $all_targets_count = 0;     # count of distinct targets
my  $valid_xref_count = 0;      # count of xrefs to targets (target itself may not be good)
#
#   holds   target of cross references found in the text files
#   key     full path and file name
#   value   count of inbound xrefs
#   printed in pass 2 if $pass2_list_xrefs
#   printed in pass 3 if $pass3_list_all_targets

my  %targets_not_txt_hash;
my  $targets_not_txt_count = 0;
#
#   holds   all the referenced files that are not *.TXT
#   key     full path and file name
#   value   $targets_not_txt_hash{$target}++;
#   printed in pass 2 if $pass2_list_xrefs
#   printed in pass 3 if $pass3_list_targets_not_txt

my  %targets_with_space_hash;
my  $targets_with_space_count = 0;
#
#   holds   all the xref lines that include a space
#   key     full path and file name
#   value   $targets_with_space_hash{$target}++;
#   printed in pass 2 if $pass2_list_xrefs
#   printed in pass 3 if $pass3_list_targets_with_space

my  %files_with_todo_tag_hash;
my  $files_with_todo_tag_count = 0;
#
#   holds   all the files that include a TODO tag
#   key     full path and file name
#   value   $files_with_todo_tag{$target}++;
#   printed in pass 2 if $pass2_list_todo_tags
#   printed in pass 3 if $pass3_list_todo_tags

my  %files_with_todo_section_hash;
my  $files_with_todo_section_count = 0;
my  $todo_section_count = 0;
#
#   holds   all the files that include a TODO section
#   key     full path and file name
#   value   $files_with_todo_section_hash{$target}++;
#   printed in pass 2 if $pass2_list_todo_sections
#   printed in pass 3 if $pass3_list_todo_sections

### SUB found_something
#
#   call-back from Find
#   called for every directory and file in turn during pass 1
#

sub found_something {

    $file_name = $File::Find::name;
    $file_name = File::Spec->canonpath($file_name);
    $file_name = lc $file_name;
    print "$all_files_prefix$file_name\n" if ($pass1_list_all_files);

    if (-d $file_name) {
        print "$dir_found_prefix$file_name\n" if ($pass1_list_all_files || $pass1_list_dir_names);
        print "$dir_found_prefix$file_name$blanks\r" if ($pass1_list_dirs_overwrite);
        $all_files_hash{$file_name}++;
        $all_directories_hash{$file_name}++;
        $all_directories_count++;

        if ($file_name =~ /\s/) {
            $dirs_with_space_hash{$file_name}++;
            $dirs_with_space_count++;
        }
    } else {
        print "$file_found_prefix$file_name\n" if ($pass1_list_all_files || $pass1_list_file_names);
        print "$file_found_prefix$file_name$blanks\r" if ($pass1_list_files_overwrite);
        $all_files_hash{$file_name}++;
        $all_files_count++;
    }
}

### SUB scan_file
#
#   scan a text file for xrefs
#
#   look for well formed titles
#   look for lines which are file names
#   look for lines which include TODO tags
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
                    $files_with_bad_underlines_hash{$this_file}++;
                    $files_with_bad_underlines_count++;

                    if ($pass2_list_bad_underlines) {
                        print "$source_file_prefix$this_file\n" if ($output_filename);
                        $output_filename = 0;
                        print "$bad_underlining_prefix\n";
                    }
                }
            }
            # else ignore the second line
        }

        #   remember the last non-blank line. check it at the end to see if this is a good Notefile

        $last_line = $_ if ($_);

        #   check each line for a possible file name

        $target = lc $_;
        my $left_part = substr( $target, 0, $left_length);

#       print "+++ left=$left_part startingdir=$external_dir\n";

        if ( $left_part eq $external_dir ) {

            #   The line starts with the $starting directory and so is probably a file name
            #   TODO    check if the file ref is badly formed BUT does in fact match a target file

            #   check if the cross reference is to a file follwed by a space

            if ( $target =~ /\s/ ) {
                $targets_with_space_hash{$target}++;
                $targets_with_space_count++;
                if ($pass2_list_xrefs) {
                    print "$source_file_prefix$source\n" if ($output_filename);
                    $output_filename = 0;
                    print "$space_xref_prefix$target\n";
                }

                next;   #   26 January 2012
            }

            #   check if cross reference is not to a text file
            #   TODO    it could be to a directory...

            unless ( $target =~ /.txt$/ ) {
                $targets_not_txt_hash{$target}++;
                $targets_not_txt_count++;
                if ($pass2_list_xrefs) {
                    print "$source_file_prefix$source\n" if ($output_filename);
                    $output_filename = 0;
                    print "$not_txt_xref_prefix$target\n";
                }

                next;   #   26 January 2012
            }

            $all_targets_hash{$target}++;
            $valid_xref_count++;

            if ($pass2_list_xrefs) {
                print "$source_file_prefix$source\n" if ($output_filename);
                $output_filename = 0;
                print "$good_xref_prefix$target\n";
            }
        }

        #   check each line for a possible TODO tag

        if ( $target =~ /$todo_tag/ ) {

            $files_with_todo_tag_hash{$this_file}++;
            $files_with_todo_tag_count++;

            if ($pass2_list_todo_tags) {
                print "$source_file_prefix$source\n" if ($output_filename);
                $output_filename = 0;
                print "$todo_tag_prefix$target\n";
            }
        }

        #   check each line for a TODO section

        if ( $target =~ /^$todo_section_tag/ ) {

            $files_with_todo_section_hash{$this_file}++;
            $files_with_todo_section_count++;

            if ($pass2_list_todo_sections) {
                print "$source_file_prefix$source\n" if ($output_filename);
                $output_filename = 0;
                print "$todo_section_prefix$target\n";
            }
        }


    }

#   at EOF - do we have a well-formed Notefile?
#   print "$last_line\n";

    if ($last_line eq $end_tag) {
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
    my $title = shift;
    print "\n$section_tag $title\n\n";
}

### Begin

print "\nCross reference scan -- 08 January 2014 -- Ian Higgs\n";

$starting_dir = shift;

unless ( $starting_dir ) {
    output_help;
    exit(1);
}

( -d $starting_dir ) or die "\nDirectory $starting_dir does not exist\n";

$stamp = strftime( "%a %d %b %Y @ %H:%M:%S", localtime );
print "\nScanning directory tree below $starting_dir\n";
print "Started $stamp\n";

$source_count = 0;

### PASS 1 -- build a hash of all of the directories and files in the tree

start_section("PASS 1 -- Scanning directory tree below $starting_dir")
    if ($pass1_list_all_files || $pass1_list_dir_names || $pass1_list_dirs_overwrite || $pass1_list_file_names || $pass1_list_files_overwrite);

&find({ wanted => \&found_something }, $starting_dir);

if ($dirs_with_space_count && $pass3_list_dirs_with_space) {
    start_section("$dirs_with_space_count Directories with spaces");

    foreach $dir (sort keys %dirs_with_space_hash) {
        print "$dir\n";
    }
}

### PASS 2 -- examine each file for references

start_section("PASS 2 -- Scanning text files") if ($pass2_list_xrefs);

foreach $source (sort keys %all_files_hash ) {
    if ( $source =~ /.*\.txt$/ ) {
        $source_count++;
        &scan_file( lc $starting_dir, $source );
    }
}

$all_targets_count = keys %all_targets_hash;

### PASS 3 -- Report totals and misc lists

start_section("All target files") if ($pass3_list_all_targets);
my $known_count = 0;
my $unknown_count = 0;

foreach $target (sort keys %all_targets_hash ) {
    if ($all_files_hash{$target}) {
        $known_count++;
        if ($pass3_list_all_targets) {
            if ($all_targets_hash{$target} > 1) {
                print "$all_targets_hash{$target} valid xrefs to $target\n";
            } else {
                print "One valid xref to $target\n";
            }
        }
    } else {
        $unknown_count++;
        if ($pass3_list_all_targets) {
            if ($all_targets_hash{$target} > 1) {
                print "$all_targets_hash{$target} broken xrefs for $target\n";
            } else {
                print "One broken xrefs for $target\n";
            }
        }
    }
}
print "\n$known_count valid targets and $unknown_count missing targets\n" if ($pass3_list_all_targets);

if ($pass3_list_valid_targets) {
    start_section("Valid target files");

    foreach $target (sort keys %all_targets_hash ) {
        print "$all_targets_hash{$target} ~ $target\n" if ($all_files_hash{$target});
    }
}

if ($targets_not_txt_count && $pass3_list_targets_not_txt) {
    start_section("Targets that are not text files");

    foreach $target (sort keys %targets_not_txt_hash) {
        print "$targets_not_txt_hash{$target} ~ $target\n";
    }
}

if ($targets_with_space_count && $pass3_list_targets_with_space) {
    start_section("Target lines include spaces");

    foreach $target (sort keys %targets_with_space_hash) {
        print "$targets_with_space_hash{$target} ~ $target\n";
    }
}

if ($files_with_todo_section_count && $pass3_list_todo_sections) {
    $todo_section_count = scalar(keys(%files_with_todo_section_hash));
    start_section("$todo_section_count files include $files_with_todo_section_count TODO sections");

    foreach $target (sort keys %files_with_todo_section_hash) {
        print "$target\n";
    }
}

if ($files_with_todo_tag_count && $pass3_list_todo_tags) {
    start_section("$files_with_todo_tag_count files which include a TODO tag");

    foreach $target (sort keys %files_with_todo_tag_hash) {
        print "$target\n";
    }
}

if ($unknown_count && $pass3_list_broken) {
    start_section("$unknown_count references to missing files");

    foreach $target (sort keys %all_targets_hash ) {
        print "$all_targets_hash{$target} ~ $target\n" unless ($all_files_hash{$target});
    }
}

if ($files_with_bad_underlines_count && $pass3_list_bad_underlines) {
    start_section("$files_with_bad_underlines_count Files with an incorrectly underlined title");

    foreach $target (sort keys %files_with_bad_underlines_hash) {
        print "$target\n";
    }
}

### Wind up

start_section("Summary");

print "PASS 1 -- Scanned directory tree below $starting_dir\n";
print "Found $all_files_count files in $all_directories_count directories\n";
print "Found $dirs_with_space_count directories with spaces\n";
print "PASS 2 -- Scanned $source_count text files\n";
print "Found $valid_xref_count valid references to $all_targets_count different target files\n";
print "Found $targets_not_txt_count targets that are not text files\n";
print "Found $targets_with_space_count target lines include spaces\n";
print "Found $todo_section_count files include $files_with_todo_section_count TODO sections\n";
print "Found $files_with_todo_tag_count files which include a TODO tag\n";
print "Found $unknown_count references to missing files\n";
print "Found $files_with_bad_underlines_count files with an incorrectly underlined title\n";

$stamp = strftime( "%a %d %b %Y @ %H:%M:%S", localtime );

print "\nFinished $stamp\n\n";

### End
