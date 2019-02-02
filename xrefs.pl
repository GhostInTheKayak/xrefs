#
#   Scan text files for cross references to other text files
#
#   01 September 2011   created
#
#   TODO    Add parameters to replace the hard-coded switches

#   switches for first pass

$list_all_files = 0;
$list_dirs = 0;
$list_dirs_overwrite = 1;
$list_files = 0;
$list_files_overwrite = 0;

#   switches for second pass

$list_xrefs = 1;
$list_all_targets = 1;
$list_valid = 1;
$list_broken = 1;
$list_targets_with_space = 1;
$list_targets_not_txt = 1;

$starting_dir = "I:\\";

$blanks = " " x 40;

####    Libraries

use POSIX qw(strftime);
use File::Find;
use File::Spec;

####    call-back from Find - called for every directory and file in turn

sub found_something
{
    $file_count++;
    $file_name = $File::Find::name;
    $file_name = File::Spec->canonpath($file_name);
    print "File: $file_name\n" if ($list_all_files);

    if (-d $file_name)
    {
        print "Dir: $file_name\n" if ($list_dirs);
        print "Dir: $file_name$blanks\r" if ($list_dirs_overwrite);
        $all_files{$file_name}++;
        $directories{$file_name}++;
    }
    else
    {
        print "$file_name\n" if ($list_files);
        print "$file_name$blanks\r" if ($list_files_overwrite);
        $all_files{$file_name}++;
    }
}

####    scan a text file

sub scan_file
{
    open(FILE,"<$source");

    while( <FILE> )
    {
        if ( /^(I:\\.+)$/ )     #   check each line for file name
        {
            $target = $1;

            #   check for a valid cross reference

            if ( $target =~ /\s/ )
            {
                $targets_with_space{$target}++;
                print " ** cross reference includes a space: [$target]\n" if ($list_xrefs);
                next;
            }

            unless ( $target =~ /.txt$/ )
            {
                $targets_not_txt{$target}++;
                print " ** cross reference not a TXT file: [$target]\n" if ($list_xrefs);
                next;
            }

            print " -> $target\n" if ($list_xrefs);
            $xref_count++;
            $targets{$target}++;
        }
    }
}

####    Begin

print "\nCross reference scan (14 September 2011)\n";

use POSIX qw(strftime);
$stamp = strftime( "%a %d %b %Y  %H:%M:%S", localtime );
print "\nStarted $stamp\n\n";

$source_count = 0;
$xref_count = 0;

####    build a hash of all of the directories and files in the tree

&find({ wanted => \&found_something }, $starting_dir);

$file_count = keys %all_files;

foreach $source (sort keys %all_files )
{
    if ( $source =~ /.*\.txt$/ )
    {
        $source_count++;
        &scan_file( $source );
    }
}

$target_count = keys %targets;
$directory_count = keys %directories;
$file_count -= $directory_count;

####    Report

if ($list_all_targets)
{
    print "\n=== All files ===\n\n";
    $known_count = 0;
    $unknown_count = 0;

    foreach $target (sort keys %targets )
    {
        if ($all_files{$target})
        {
            $known_count++;
            print "$targets{$target} valid xrefs to $target\n";
        }
        else
        {
            $unknown_count++;
            print "$targets{$target} broken xrefs for $target\n";
        }
    }
    print "\n$known_count known files and $unknown_count unknown files\n";
}

if ($list_valid)
{
    print "\n=== Valid target files ===\n\n";

    foreach $target (sort keys %targets )
    {
        print "$target ~ $targets{$target}\n" if ($all_files{$target});
    }
}

if ($list_broken)
{
    print "\n=== Missing target files ===\n\n";

    foreach $target (sort keys %targets )
    {
        print "$target ~ $targets{$target}\n" unless ($all_files{$target});
    }
}

if ($list_targets_with_space)
{
    print "\n=== Target lines with spaces ===\n\n";

    foreach $target (sort keys %targets_with_space)
    {
        print "$target ~ $targets_with_space{$target}\n";
    }
}

if ($list_targets_not_txt)
{
    print "\n=== Target lines not .TXT ===\n\n";

    foreach $target (sort keys %targets_not_txt)
    {
        print "$target ~ $targets_not_txt{$target}\n";
    }
}

####    Wind up

print "\n=== Summary ===\n\n";

print "Scanned $file_count files in $directory_count directories\n";
print "Found $source_count files and $xref_count cross references\n";
print "Found $target_count different target files\n";

$stamp = strftime( "%H:%M:%S", localtime );
print "\nFinished $stamp\n\n";

####    End
