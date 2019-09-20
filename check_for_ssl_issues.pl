#!/usr/bin/perl
#FILENAME: check_for_ssl_issues.pl
#Description check for ssl issues
#
#
sub get_key_cert_files {
    my $filename = shift;
    open( SUDOCAT, "sudo cat $filename|" );
    my @lines = <SUDOCAT>;
    close SUDOCAT;
    foreach $line (@lines) {
        chomp $line;
        $line =~ s/^\s+//g;    #clean up precceding whitespace
        if ( $line =~ /private/i or $line =~ /cert/i ) {

            #ignore lines with comments
            if ( $line !~ /#/ and $line =~ /private/ ) {
                my $nl = ( split( ' ', $line ) )[1];    #get second field
                print "###################\n SSL CONFIG FILENAME: $filename \n"
                  ;                                     #format line
                print "###################\n";    #format line
                                                  #print "line is '$line'\n";
                print "key FILENAME: '$nl'\n";
                print "key hash: ";
                system("sudo openssl rsa -noout -modulus -in $nl| openssl md5");

                #ignore lines with comments
            }
            elsif ( $line !~ /#/ and $line =~ /cert/ ) {
                my $nl = ( split( ' ', $line ) )[1];    #get second field
                print "###################\n SSL CONFIG FILENAME: $filename \n"
                  ;                                     #format line
                print "###################\n";    #format line
                                                  #print "line is '$line'\n";
                print "cert FILENAME: '$nl'\n";
                print "key hash: ";
                system(
                    "sudo openssl x509 -noout -modulus -in $nl| openssl md5");
                system(
                    "sudo openssl x509 -subject -serial -enddate -noout -in $nl"
                );                                #get expiration
            }
        }
    }
}

open( FINDF, "find /etc/httpd/conf.d/ -type f -iname '*.conf'|" );
my @files = <FINDF>;
close FINDF;

print "################################\n";

foreach $name (@files) {
    chomp $name;

    #print "FILENAME: $name \n";
    get_key_cert_files($name);
}
print "################################\n";
