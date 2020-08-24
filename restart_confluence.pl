#!/usr/bin/perl
#author: Theodore Knab
#date: 8/24/2020
#filename: restart_confluence.pl
#description: clean up memory problems with confluence 
# a work around for this error/bug:
# [proxy_ajp:error] [pid 1270:tid 140402329900800] (70007)The timeout specified has expired: AH01030: ajp_ilink_receive() can't receive header
#
print "running ... ($0)\n";

use Sys::Hostname;
my $host = hostname() or die "unable to get hostname\n"; #my hostname
my @services; #services to stop and start
my @service=("confluence","httpd");

sub verify_process_died_or_kill_it {
  my $process=$_[0];
  print "looking for $process\n";
  open (PROC,"ps aux|");
  my @procs=<PROC>;
  close PROC;
  foreach(@procs){
    chomp;
    if ( $_=~ /$process/) {
      #orphan to kill
      my $prid=(split(/\s+/,$_))[1];
      if ( $prid > 100 ) {
        print "forcing kill on orphan for $process using prid of $prid\n";
        system("kill $prid");
      }
    }
  }
}



#stop services
foreach (@service) {
  print "systemctl stop $_\n";
  system("systemctl stop $_");
  #system("/etc/init.d/$_ stop");
  sleep(5);
  verify_process_died_or_kill_it($_);
}

#start services
foreach(@service) {
  print "systemctl start $_\n";
  system("systemctl start $_");
  #system("/etc/init.d/$_ start");
  sleep(5);
}
