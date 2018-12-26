#!/usr/bin/perl
#description: clean up memory problems with CM/ECF if no speical users are logged in

use Sys::Hostname;
my $host = hostname() or die "unable to get hostname\n"; #my hostname
my @services; #services to stop and start

sub check_for_vip
{
  open (WHOSON, "/opt/util/whoson |") || die ("failed to find file: $)");
  my @list_of_vip = <WHOSON>;
  close WHOSON;

  foreach (@list_of_vip) {
   chomp;
   #modify this accordingly by PRID
   if ( $_ =~ /(999|123555|555333|smith|mannes)/ ) {
     #print "$_\n";
     return 1;
   }
  }
     return 0;
}


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

my $value = check_for_vip();
if ( $value == 1 ) {
  exit;
} else {
  print "no vip. Coast is clear to run the program.\n";
}

print "debug: my host is $host\n";
if ( ( $host =~ /.*db\./i) && ( $host !~ /.*web\./) ) {
 print "debug: on inside server\n";
 @service=("fastServ","httpd","ECF-live","ECF-test","ECF-tomcat","zabbix-agent");
} else {
 print "debug: on outside server\n";
 @service=("fastServ","httpd");
}

#stop services
foreach (@service) {
  system("/etc/init.d/$_ stop");
  sleep(5);
"~/cronjobs/restart_services.pl" [readonly] 70L, 1579C
 

3:15:57 PM:   sleep(5);
  verify_process_died_or_kill_it($_);
}

#start services
foreach(@service) {
  system("/etc/init.d/$_ start");
  sleep(5);
}
