#!/usr/bin/perl

sub usage {
    print "Usage: bump_version.pl VERSION\n";
    exit(2);
}

$VERSION=$ARGV[0];
usage() unless defined $VERSION;
print "Bumping to version $VERSION.\n";

# Bump version in tcl files
while ($file = <pbc*.tcl>) {
    print "Working on $file.\n";
    open(IN, "<$file") || die "Can't open $file for reading!";
    open(OUT, ">$file.new") || die "Can't open $file.new for writing!";
    while (<IN>) {
	if (s/^package provide pbctools (.*)$/package provide pbctools $VERSION/) {
	    print "  $1 -> $VERSION\n";
	}
	print OUT $_;
    }
    close(IN);
    close(OUT);
    print "  $file.new -> $file.\n";
    rename "$file.new", $file;
}

# Call pkg_mkIndex
print "Updateing pkgIndex.tcl...\n";
system('tclsh maintainer/pkg_mkIndex.tcl');
print "Finished.\n";

# Bump version in doc/index.html
$file = "doc/index.html";

print "Working on $file.\n";
open(IN, "<$file") || die "Can't open $file for reading!";
open(OUT, ">$file.new") || die "Can't open $file.new for writing!";

# Replace version number in the first line
$_ = <IN>;
if (s/value="PBCTools Plugin, Version (.*)"/value="PBCTools Plugin, Version $VERSION"/) {
    print "  $1 -> $VERSION\n";
}
print OUT $_;

# Just copy the rest of the file
while (<IN>) { print OUT $_; }
close(IN);
close(OUT);

print "  $file.new -> $file.\n";
rename "$file.new", $file;
