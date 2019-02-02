#
#   Scan text files for cross references to other text files
#
#   31 August 2011      created
#

#   switches for output

$list_dirs = 1;
$list_files = 1;
$list_xrefs = 1;
$list_valid = 1;
$list_broken = 1;

#   zero counts in case we find nothing

$file_count = 0;
$xref_count = 0;
$known_count = 0;
$unknown_count = 0;

use POSIX qw(strftime);
use File::Find;
use Cwd;

####    scan each log in turn

sub wanted
{
    $source = $File::Find::name;
    &scan_file($source);
}

sub scan_file
{
    $source =~ s/\//\\/m;
    if ( /.*\.txt/ )
    {
        print "Scanning file: $source\n" if ($list_files);
        $file_count++;
        $sources{$source}++;

        open(FILE,"<$source");
        $count = 0;

        while( <FILE> )
        {
            if ( /^(I:\\.+)$/ )     #   check each line for file name
            {
                $target =  $1;
                print "  Found xref to $target\n" if ($list_xrefs);
                $xref_count++;
                $targets{$target}++;
                next;
            }
        }
    }
    else
    {
        print "Skipping file: $source\n" if ($list_files);
    }

}

sub scan_dir
{
    print "Scanning directory: $source\n" if ($list_dirs);
    while($source = <*.txt>)
    {
        &scan_file($source);
    }
}

use POSIX qw(strftime);
$stamp = strftime( "%a %d %b %Y  %H:%M:%S", localtime );

find(\&wanted, 'I:');
#   &scan_dir;

print "\n" if ($list_files | $list_xrefs);

$target_count = 0;
foreach $target (sort keys %targets )
{
    $target_count++;
    if ($sources{$target})
    {
        $known_count++;
        print "$targets{$target} valid xrefs to $target\n" if ($list_valid);
    }
    else
    {
        $unknown_count++;
        print "$targets{$target} broken xrefs for $target\n" if ($list_broken);
    }
}

print "\n";
print "Found $file_count files\n";
print "Found $xref_count cross references\n";
print "Found $target_count different target files\n";
print "      $known_count known files\n";
print "      $unknown_count unknown files\n";

$stamp = strftime( "%H:%M:%S", localtime );
print "\nFinished $stamp\n\n";
