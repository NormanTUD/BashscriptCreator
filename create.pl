#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use autodie;

use UI::Dialog;
my $d = new UI::Dialog ( title => 'BashscriptCreator',
                         height => 25, width => 85 , listheight => 8,
                         order => [ 'whiptail' ] );
 
sub msgbox {
	my $text = shift;
	$d->msgbox(title => 'BashscriptCreator', text => $text);
}

sub yesno {
	my $text = shift;
	if ($d->yesno(text => $text) ) {
		return 1;
	} else {
		return 0;
	}
}

sub inputbox {
	my ($text, $default) = (shift, shift // '');
	my $string = $d->inputbox(text => $text, entry => $default);
	if ($d->state() ne "OK") {
		exit 0;
	}
	return $string;
}

sub menu {
	my $text = shift;
	my $selection = $d->menu(text => 'Select one:', list => \@_);
	if($d->rv()) {
		exit(0);
	}
	return $selection;
}

sub checklist {
	my $text = shift;
	my @selection1 = $d->checklist( text => $text, list => \@_);
	if($d->rv()) {
		exit(0);
	}
	return @selection1;
}

main();

sub main {
	my $filename = ''; 

	my $script = "#!/bin/bash\n";

	$script .= "function echoerr() {\n";
        $script .= "\t".q#echo "$@" 1>&2#."\n";
	$script .= "}\n\n";

	$script .= "function red_text {\n";
	$script .= "\t".q#echoerr -e "\e[31m$1\e[0m"#."\n";
	$script .= "}\n\n";

	while (!$filename) {
		$filename = inputbox("Filename without .sh");
		$filename =~ s#\.sh{1,}$##g;
		if(-e "$filename.sh") {
			msgbox("The file `$filename.sh` already exists. Choose another one please.");
			$filename = ''; 
		}
	}
	$filename .= ".sh";

	my @options = checklist("Which options should be enabled?", 
		"set -e", ["auto-die on error", 1], 
		"set -o pipefail", ["fail if a command in a pipe fails", 1],
		"set -u", ["exit script if a variable is undefined", 0],
		"set -x", ["show lines before executing them", 0],
		"calltrace", ["Show call trace when the bash script dies", 1]
	);

	foreach my $option (@options) {
		if($option =~ m#^set -([exu]|o pipefail)$#) {
			$script .= "$option\n";
		} elsif ($option eq "calltrace") {
			$script .= "\n";
			$script .= "function calltracer () {\n";
			$script .= "\techo 'Last file/last line:'\n";
			$script .= "\tcaller\n";
			$script .= "}\n";
			$script .= "trap 'calltracer' ERR\n";
			$script .= "\n";
		} else {
			warn "Unknown option $option";	
		}
	}

	my @variables = ();
	while ((my $param = inputbox("Enter a variable name to be used as cli parameters or nothing for ending parameter input. Default value is optional.\n".
				"Prepend '!' to not allow empty values.\n".
				"Examples:\nvarname\nvarname=defaultvalue\ninteger=(INT)defaultvalue\n".
				"float=(FLOAT)\nfile=(FILEEXISTS)defaultvalue\n".
				"file=(FILENOTEXISTS)defaultvalue\nfolder=(DIREXISTS)defaultvalue\nfolder=(DIRNOTEXISTS)defaultvalue\n".
				"!file=(FILEEXISTS)\n"
			)) ne "") {
		if($param) {
			push @variables, $param;
		}
	}
	my @variables_original = @variables;

	$script .= "function help () {\n";
	$script .= qq#\techo "Possible options:"\n#;

	foreach my $var (@variables) {
		my $name = $var;
		$name =~ s#=.*##g;

		if($var =~ m#^!#) {
			$var =~ s#^!##g;
			$name = $var;
		}

		my $helptext = "--$name";
		if($var =~ m#(INT|FLOAT|STRING)#) {
			my $type = $1;
			$helptext .= "=$type";
		} elsif ($var =~ m#(DIREXISTS|DIRNOTEXISTS|FILEEXISTS|FILENOTEXISTS)#) {
			my $type = $1;
			$helptext .= "=$type";
		}

		if($var =~ m#=\((INT|FLOAT|STRING|DIREXISTS|DIRNOTEXISTS|FILEEXISTS|FILENOTEXISTS)\)(.*)#) {
			my $default_value = $2;
			if($default_value !~ m#^\s*$#) {
				while(length($helptext) < 50) {
					$helptext .= ' ';
				}
				$helptext .= " default value: $default_value";
			}
		}
		$script .= qq#\techo "\t$helptext"\n#;
	}

	my $helptext = "--help";
	while(length($helptext) < 50) {
		$helptext .= ' ';
	}
	$helptext .= " this help";
	$script .= qq#\techo "\t$helptext"\n#;


	$helptext = "--debug";
	while(length($helptext) < 50) {
		$helptext .= ' ';
	}
	$helptext .= " Enables debug mode (set -x)";
	$script .= qq#\techo "\t$helptext"\n#;
	$script .= qq#\texit \$1\n#;

	$script .= "}\n";

	foreach my $var (@variables) {
		my $var_exportable = $var;
		$var_exportable =~ s#!##;
		$var_exportable =~ s#\((INT|FLOAT|STRING|DIREXISTS|DIRNOTEXISTS|FILEEXISTS|FILENOTEXISTS)\)##g;
		$script .= "export $var_exportable\n";
	}

	$script .= "for i in \$@; do\n";
	$script .= "\tcase \$i in\n";
	foreach my $var (@variables) {
		my $name = $var;
		if($var =~ m#^!#) {
			$var =~ s#^!##g;
			$name = $var;
		}

		$name =~ s#=.*##g;
		$script .= "\t\t--$name=*)\n";
		$script .= "\t\t\t$name=\"\${i#*=}\"\n";
		if ($var =~ m#\((INT|FLOAT|STRING|FILEEXISTS|DIREXISTS|FILENOTEXISTS|DIRNOTEXISTS)\)#) {
			my $type = $1;
			if($type ne "STRING") {
				if($type eq "FILEEXISTS") {
					$script .= "\t\t\tif [[ ! -f \$$name ]]; then\n";
					$script .= "\t\t\t\tred_text \"error: file \$$name does not exist\" >&2\n";
					$script .= "\t\t\t\thelp 1\n";
					$script .= "\t\t\tfi\n";
				} elsif($type eq "FILENOTEXISTS") {
					$script .= "\t\t\tif [[ -f \$$name ]]; then\n";
					$script .= "\t\t\t\tred_text \"error: file \$$name does already exist\" >&2\n";
					$script .= "\t\t\t\thelp 1\n";
					$script .= "\t\t\tfi\n";
				} elsif($type eq "DIREXISTS") {
					$script .= "\t\t\tif [[ ! -d \$$name ]]; then\n";
					$script .= "\t\t\t\tred_text \"error: directory \$$name does not exist\" >&2\n";
					$script .= "\t\t\t\thelp 1\n";
					$script .= "\t\t\tfi\n";
				} elsif($type eq "DIRNOTEXISTS") {
					$script .= "\t\t\tif [[ -d \$$name ]]; then\n";
					$script .= "\t\t\t\tred_text \"error: directory \$$name does already exist\" >&2\n";
					$script .= "\t\t\t\thelp 1\n";
					$script .= "\t\t\tfi\n";
				} else {
					if($type eq "INT") {
						$script .= "\t\t\tre='^[+-]?[0-9]+\$'\n"
					} elsif ($type eq "FLOAT") {
						$script .= "\t\t\tre='^[+-]?[0-9]+([.][0-9]+)?\$'\n";
					}
					$script .= "\t\t\tif ! [[ \$$name =~ \$re ]] ; then\n";
					$script .= "\t\t\t\tred_text \"error: Not a $type: \$i\" >&2\n";
					$script .= "\t\t\t\thelp 1\n";
					$script .= "\t\t\tfi\n";
				}
			}
		}

		$script .= "\t\t\tshift\n";
		$script .= "\t\t\t;;\n";
	}


	$script .= "\t\t-h|--help)\n";
	$script .= "\t\t\thelp 0\n";
	$script .= "\t\t\t;;\n";

	$script .= "\t\t--debug)\n";
	$script .= "\t\t\tset -x\n";
	$script .= "\t\t\t;;\n";

	$script .= "\t\t*)\n";
	$script .= "\t\t\tred_text \"Unknown parameter \$i\" >&2\n";
	$script .= "\t\t\thelp 1\n";
	$script .= "\t\t\t;;\n";

	$script .= "\tesac\n";
	$script .= "done\n";

	foreach my $var (@variables_original) {
		$var =~ s#=.*##g;
		if($var =~ m#^!#) {
			$var =~ s#^!##g;
			$script .= qq#if [[ -z "\$$var" ]]; then red_text "Parameter --$var cannot be empty"; help 1; fi\n#;
		}
	}

	open my $fh, '>', $filename;
	print $fh $script;
	close $fh;

	print "Written $filename\n";
}

