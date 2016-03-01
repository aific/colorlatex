#!/usr/bin/perl

# Copyright (c) 2016, Peter Macko (Aific)
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
# 
# * Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# 
# * Neither the name of colorlatex nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

# To use this script, create symbolic links:
#   /usr/bin/colorlatex    --> colorlatex.pl
#   /usr/bin/colorpdflatex --> colorlatex.pl
#   /usr/bin/colorxelatex  --> colorlatex.pl
#   /usr/bin/colorbibtex   --> colorlatex.pl

use File::Basename;
use IPC::Open3;


# Color constants

$col_gray         = "\033[37m";
$col_purple       = "\033[35m";
$col_green        = "\033[32m";
$col_cyan         = "\033[36m";
$col_brown        = "\033[33m";
$col_red          = "\033[31m";
$col_blue         = "\033[34m";

$col_brighten     = "\033[01m";
$col_underline    = "\033[04m";
$col_normal       = "\033[0;0m";


# Default configuration

$col_this_is      = $col_cyan   . $col_brighten;
$col_no_file      = $col_red                   ;
$col_error        = $col_red    . $col_brighten;
$col_warning      = $col_brown  . $col_brighten;
$col_overfull     = $col_brown                 ;
$col_underfull    = $col_purple                ;

$join_lines              = 1;
$consolidate_whitespace  = 0;
$remove_empty_lines      = 0;
$remove_help_suggestions = 1;
$remove_packages         = 1;
$remove_see_transcript   = 1;


# Get the program name

($program_name, $path, $suffix) = fileparse($0, qr/\.[^.]*/);
$program_name =~ s/color//;


# Check the terminal type, and if it is dumb, just exec the program and exit

$terminal = $ENV{"TERM"} || "dumb";

if (! -t STDOUT || $terminal eq "dumb")
{
	exec $program_name, @ARGV or die("Could not run " . $program_name);
}


# Open the pipe

$pid = open3('<&STDIN', \*OUT, '>&1', $program_name, @ARGV)
	or die("Could not run " . $program_name);


# The main loop

$in_transcript = undef;
$thisline      = "";
$prefix        = "";

while (<OUT>)
{
	$orgline = $_;
	$thisline = $prefix . $orgline;

	# Remove end of line symbols
	$thisline =~ s/[\n\r]//g;

	# Remove multiple spaces
	if ($consolidate_whitespace) {
		$thisline =~ s/  \+/ /g;
	}


	#
	# Join split lines
	#

	if ($join_lines) {
		if ((length $orgline) == 80) {
			$prefix = $thisline;
			next;
		} else {
			$prefix = "";
		}
	}


	#
	# Remove
	#

	# Remove empty lines
	if ($remove_empty_lines && ($thisline =~ /^[ \t]*$/)) {
		next;
	}

	# For additional information...
	if ($remove_help_suggestions) {
		if ($thisline =~ /^(For\ additional\ information)/) {
			next;
		}
	}

	# Remove package information
	if ($remove_packages) {

		# Package: `...'
		if ($thisline =~ /^(Package:\ \`)/) {
			next;
		}

		# (/usr/share/texmf-texlive/tex/latex/amsmath/amsmath.sty...
		$b = $thisline =~ s/^[\( \)]*    \/.*\.sty    [\( \)]*//x;
		$b = $thisline =~ s/^[\( \)]*    \/.*\.cfg    [\( \)]*//x || $b;
		$b = $thisline =~ s/^[\( \)]*    \/.*\.def    [\( \)]*//x || $b;
		$b = $thisline =~ s/^[\( \)]*    \/.*\.clo    [\( \)]*//x || $b;
		$b = $thisline =~ s/^[\( \)]*    \/.*\.cls    [\( \)]*//x || $b;
		$b = $thisline =~ s/^[\( \)]*  \.\/.*\.aux    [\( \)]*//x || $b;
		$b = $thisline =~ s/^[\( \)]*    \/.*\.fd     [\( \)]*//x || $b;
		$b = $thisline =~ s/^[ \t]*[\(\)]+//x || $b;
		if ($b && ($thisline =~ /^[ \t]*$/)) { next; }
	}

	# Remove transcript information
	if ($remove_see_transcript) {

		# Output written on...
		if ($thisline =~ /^(Output\ written)/) {
			$in_transcript = undef;
		}

		# see the transcript file for additional information...
		if ($thisline =~ /^(see\ the\ transcript)/) {
			$in_transcript = 1;
		}

		# ...everything in between...
		if ($in_transcript) {
			next;
		}
	}


	#
	# Color: pdflatex
	#

	# LaTeX Warning: ...
	if ($thisline =~ /^(LaTeX\ Warning)/) {
		$thisline =~ s/^(LaTeX\ Warning)/$col_warning$1$col_normal/x;
		# ... line #
		$thisline =~ s/(line\ )(\d+)/$col_red$1$col_normal$col_cyan$2$col_normal/x;
	}

	# Class x Warning: ...
	$thisline =~ s/^(Class\ \w+\ Warning:)/$col_warning$1$col_normal/x;

	# Package x Warning: ...
	$thisline =~ s/^(Package\ \w+\ Warning:)/$col_warning$1$col_normal/x;

	# Warning--...
	$thisline =~ s/^(Warning--)/$col_warning$1$col_normal/x;

	# Underfull ...
	$thisline =~ s/^(Underfull)/$col_underfull$1$col_normal/x;

	# Overfull ...
	$thisline =~ s/^(Overfull)/$col_overfull$1$col_normal/x;

	# ... lines x--y
	$thisline =~ s/(lines\ )(\d+\-\-\d+)/$col_red$1$col_normal$col_cyan$2$col_normal/x;

	# No file ...
	$thisline =~ s/^(No\ file\ )(.+)[.]/$col_no_file$1$col_normal$col_cyan$2$col_normal\./x;

	# ./report.tex:78: Undefined...
	$thisline =~ s/^(.*\.tex:)/$col_error$1$col_normal/x;

	# ! ...
	$thisline =~ s/^(!)/$col_error$1$col_normal/x;

	# LaTeX Error: ...
	$thisline =~ s/(LaTeX\ Error:)/$col_error$1$col_normal/x;


	#
	# Color: bibtex
	#

	# There was 1 error message
	$thisline =~ s/^(There\ was\ [0-9]+\ error)/$col_error$1/x;

	# I found no...
	$thisline =~ s/^(I\ found\ no)/$col_error$1/x;

	# I was...
	$thisline =~ s/^(I\ was)/$col_error$1/x;


	#
	# Extra line breaks
	#

	# This is ...
	if ($thisline =~ s/^(This\ is)/$col_this_is$1/x) {
		print "\n";
	}


	#
	# Print
	#

	print $thisline . "\n";
	print $col_normal;
	$thisline = "";
}


# Finalize

if ((length $thisline) > 0) {
	print $thisline . "\n";
	print $col_normal;
}

waitpid $pid, 0;
exit $? >> 8;
