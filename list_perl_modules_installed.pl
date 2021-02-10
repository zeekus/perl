#!/usr/bin/perl -w
#filename: list_perl_modules_installed.pl
#description: lists the perl modules installed on a system
use ExtUtils::Installed;
my $inst    = ExtUtils::Installed->new();
my @modules = $inst->modules();
 foreach $module (@modules){
      print $module . "\n";
}
