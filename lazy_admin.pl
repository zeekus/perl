#!/usr/bin/perl
#filename: lazy_admin.pl
#description: preform daily checks on the CM/ECF system and send email to any issues.
#author - Zeekus
##! cleaned up a tad afb 4/2019

use strict;
use warnings;
use Sys::Hostname; #for host lookups
use Net::SMTP; #for email

#globals for other courts
my $mailhost='smtp.uscmail.dcn'; #mail gateway if required
my $to_address='somebody@somewhere'; #to be notified address
my $from_address='somebody@somewhere'; #from address
my $server_type = 'inside';
my $informix_server = 'unit_ecf';
my $db_name = 'unit_live';


sub run_command_and_return_results {
  #description takes input in the form of a command and returns the results in an array
  my $command = shift;
  my @results;
  my @return_raw;
  my $count=0;

  open (CMD,"$command|");
  @results=<CMD>;
  close CMD;

  foreach my $line (@results) {
    chomp $line;
    #print "run_command_and_return_results $line\n";
    $count=$count+1;
    push(@return_raw,$line);
  }
  print "**** We got \'$count\' raw lines\n";
  return @return_raw;
}

sub check_ecf_procs {
 my $server_type = shift;
 my $sub="check_ecf_procs";

 #process and number
 my @ecf_services="";

 if ( $server_type =~ /inside/ ) {
   @ecf_services=("SyncDocuments:1","java:1","OutServ.pl:18","oninit:10","httpd:5");
 } else {
   @ecf_services=("thttpd:1","httpd:5");
 }
 my ($process_name,$expected_process_count);
 my @report_results;

 foreach my $line (@ecf_services) {
  print "debug check_ecf_inside_process: $line\n";
  ($process_name,$expected_process_count)=split(":",$line);

  print "verify_process_exists: count of \'$expected_process_count\'\n";
  my $count = verify_process_exists($process_name);
  print "count of \'$count\' returned\n";


  if ( $count >= $expected_process_count ) {
     print "debug - INFO - good : $process_name - $count\n";
     push (@report_results,"PROCESS INFO - $process_name is good with \'$count\' process");
  }else {
     print "debug - WARN - bad: $process_name - $count\n";
     push (@report_results,"PROCESS WARN - $process_name is bad with \'$count\' process");
  }
 }
 print "debug: end of $sub\n";
 return @report_results;

}

sub verify_process_exists {
  my $process_name=shift;
  my $process_count=0;
  my @procs = run_command_and_return_results("ps aux");

  print "verify_process_exists: looking for \'$process_name\'\n";

  #get count of processes from raw data
  foreach my $line (@procs){
    chomp $line;
    if ( $line =~ "$process_name" ) {
      $process_count=$process_count+1;
      }
   }

  #send back process count
  return $process_count;
}

sub check_disk_space {
  my @disk_space=run_command_and_return_results("df -h");
  my @report;
  foreach my $disk (@disk_space) {
     $disk =~ s/^\s*//g; #remove white space at beginning

     if ( $disk =~ /^[0-9]/ ) {

      print "debug \'$disk\'\n";
      if ( ($disk=~ /9[0-9]\%/ ) or ($disk =~ /100\%/)  )  {
         push(@report,"DISK WARN - $disk - bad ");
      } else {
         push(@report,"DISK INFO - $disk - good");
      }
     }
  }
  return @report;
}

sub check_on_swap {
  my @memory=run_command_and_return_results("free -m");
  my @report;
  foreach my $line(@memory) {
    if ( $line =~ /mem/i ) {
        my $avail=(split("\ ",$line))[1];
        my $used=(split("\ ",$line))[2];
        my $free=(split("\ ",$line))[3];
       if ( $free > 1500 ) {
         push(@report,"MEMORY INFO: $free MB - good");
         } else {
         push(@report,"MEMORY WARN: $free MB - bad");
         }
    }

    if ( $line =~ /swap/i) {
        my $avail=(split("\ ",$line))[1];
        my $used=(split("\ ",$line))[2];
       if ( $used < 100 ) {
         #print ("debug - INFO SWAP: $used\n");
         push(@report,"MEMORY SWAP INFO: $used MB - good ");
       } else {
         #print ("debug - WARN SWAP: $used\n");
         push(@report,"MEMORY SWAP WARN: $used MB - good ");
       }
    }
  }
  return @report;
  #check to see if the machine is swapping
}

sub check_interfaces_for_errors {
  my @interface_check=run_command_and_return_results("ifconfig -a");
  my $interface;
  my @report;
  my $count=0;

  foreach my $line (@interface_check) {
       chomp $line;


       if ( $line =~ /^eth/ )   {
         $interface=(split(" ",$line))[0];
         print "debug check_interfaces_for_errors: $line\n";
       } elsif ( $line =~ /RX / )  {
           #print "debug check_interfaces_for_errors: $rx\n";
           #find any error worthy
           if ( ( $line =~ /(errors|dropped|frame|carrier):[1-9]/)  ) {
             print("debug: check_interface_for_errors WARN: $interface: $line\n");
             push(@report,"NETWORK INTERFACE: WARN -  $interface: $line - bad");
           } else {
             #print("debug: check_interface_for_errors INFO: $interface: $line\n");
             #push(@report,"INFO: $interface: $line");
           }
       } elsif ( $line =~ /TX / ) {
           #print "debug check_interfaces_for_errors: $tx\n";
           #find any error worthy
           if ( ( $line =~ /(errors|dropped|frame|carrier):[1-9]/)  ) {
            print("debug: check_interface_for_errors WARN: $interface: $line\n");
             push(@report,"NETWORK INTERFACE: WARN -  $interface: $line - bad");
           } else {
             #print("debug: check_interface_for_errors INFO: $interface: $line\n");
             #push(@report,"INFO: $interface: $line");
           }
       } else {
          #do nothing
       }
  }
  return @report;
}

sub email_report {
 my ($mailhost,$from,$to,$warn_count,@report) = @_;
 my $host = hostname() or die "unable to get hostname\n"; #my hostname  print "debug email_report got $warn_count\n";

 my $smtp = Net::SMTP->new($mailhost);

 $smtp->mail($ENV{USER});
 $smtp->to($to);

 $smtp->data();
 $smtp->datasend("To: $to\n");
 $smtp->datasend("From: $from\n");
 $smtp->datasend("Subject:$host - LAZY ADMIN REPORT warn: $warn_count\n");  $smtp->datasend("\n");
 $smtp->datasend("******** START LAZY ADMIN REPORT ***********\n");

 foreach my $line (@report) {
   chomp $line;
   print "debug: email_report $line\n";
   $smtp->datasend("$line\n");
 }

 $smtp->datasend("******** END LAZY ADMIN REPORT ***********\n");

 $smtp->dataend();
 $smtp->quit;

}

sub count_warnings {
  my @report = @_;
  my $count=0;
  foreach my $line (@report) {
    if ($line =~ /WARN/) {
      $count=$count+1;
    }
  }
 print "debug: count_warnings $count\n";  return $count; }

sub informix_query_for_chunk_space {
 my ($informix_server,$db_name)=@_;
 my @report;

 #set up environment variables
 $ENV{'INFORMIXDIR'}='/opt/informix';
 $ENV{'INFORMIXSERVER'}=$informix_server;
 $ENV{'PATH'}='$PATH:$INFORMIXDIR/bin:/opt/util:/gov/ecf/bin/';

 #create SQL statement to check on the chunks
my @filedata;  my $filename = "/tmp/chunk_space.sql";  #print "open file\n";
open FILE, ">$filename" or warn("WARN unable to open file $!\n");
print FILE "database sysmaster\;\n";
print FILE "select name dbspace, sum(chksize) allocated, sum(nfree) free,\n";
print FILE "round(((sum(chksize)-sum(nfree))/sum(chksize))*100) pctused from sysmaster:sysdbspaces d,\n";
print FILE "sysmaster:syschunks c where d.dbsnum = c.dbsnum group by name order by name\;\n";
close FILE;

 #run the SQL statment we just wrote to file
if ( -e $filename ) {
#   open( FILE, $filename ) or warn "can't open the $filename - reason $!\n";
#   @filedata = <FILE>;
#   close(FILE);
#
#   #output SQL lines to screen
#   foreach my $line (@filedata){
#     chomp;
#     print "SQL: $line";
#   }

   #run the SQL query
   my $CMD = "/opt/informix/bin/dbaccess $db_name $filename";
   open (RUNSQL,"$CMD|");
   @filedata = <RUNSQL>;
   close(RUNSQL);

   my $name;
   my $use;
   foreach my $line (@filedata){
     if ( $line =~ /dbspace/ ) {
       $name = $line;
       chomp $name;
     }elsif ( $line =~ /pctused/ ) {
       $use= $line;
       chomp $use;
       $use=(split("\ ",$use))[1];
       $name=(split("\ ",$name))[1];

       if ( $name =~ /(index|doc|live)/ ) {
          if ( $use > 85 ) {
            #print "DB SPACE WARNING $name, $use\n";
            push(@report, "DB SPACE WARNING $name, $use - bad");
          } else {
            #print "DB SPACE INFO $name, $use\n";
            push(@report, "DB SPACE INFO $name, $use - good");
          }
       }
     }else{
      #do nothing. We don't care about this stuff.
     }
   }
 }

 #TO DO onstat checks
 my $ONSTAT="/opt/informix/bin/onstat - ";
 open (RUNONSTAT,"$ONSTAT|");
 @filedata = <RUNONSTAT>;
 close(RUNONSTAT);

 my $onstat=0; #0 means not in primary mode

 foreach my $data ( @filedata) {
  chomp $data;
  if ( $data =~ /Prim/ ) {
    $onstat=1;
    push(@report, "DB ONSTAT INFO $data - good");
  }elsif ( $data =~ /IBM/ ) {
    push(@report, "DB ONSTAT WARN $data - bad");
  } else {
    #do nothing
  }

 }
 return @report;
}

my @report;
my @results_proc;

if ( $server_type =~ /(inside|outside)/ ) {
  if ($server_type =~ /inside/ ) {
    @results_proc = check_ecf_procs($server_type);
    print"debug: adding results_process to report\n";
  }else {
    @results_proc = check_ecf_procs($server_type);
    print"debug: adding results_process to report\n";
  }
  push(@report,@results_proc);
}

my @results_disk=check_disk_space();
push(@report,@results_disk);

my @swap = check_on_swap();
push(@report,@swap);

my @interfaces= check_interfaces_for_errors(); push(@report,@interfaces);

if ( $informix_server =~ /ecf/ ) {
 my @informix_report = informix_query_for_chunk_space($informix_server,$db_name);
 push(@report,@informix_report);
}

my $warn_count = count_warnings(@report); email_report($mailhost,$from_address,$to_address,$warn_count,@report);
