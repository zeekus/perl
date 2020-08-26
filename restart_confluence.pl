#!/usr/bin/perl
#author: Theodore Knab
#date: 8/24/2020
#filename: monitor_and_restart_apache.pl
#description: restart apache when the proxy dies. This is a bandaid solution. A configuration change should prevent this. 
# a work around for this error/bug:
# [proxy_ajp:error] [pid 1270:tid 140402329900800] (70007)The timeout specified has expired: AH01030: ajp_ilink_receive() can't receive header
# PYSDO CODE

open (FH, "journalctl --since "10min ago"|");
@results = <FH>;
close FH;

#sadly journalctl doesn't hold he /var/log/htttpd/error.log so this will not work. 
foreach my $line (@results) {
  if $line =~ /The timeout specified has expired: AH01030: ajp_ilink_receive/ {
     #restart apache
  }
}
