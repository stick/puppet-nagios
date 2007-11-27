#!/usr/bin/perl -w
#####################################################################
# Saurabh Bathe <sbathe@redhat.com>                                 #
# check_ssl_cert.pl                                                 #
# A nagios plugin to do SSL URL and certificate expiry check        #
# Adapted from a lot of other Perl scripts for similar purpose      #
# And a lot of help from Chris                                      #
#####################################################################
use strict;
use Getopt::Long;
use Date::Calc qw(:all);
use Data::Dumper;

my %opts;
my %return_codes = (
    'UNKNOWN'   =>  '-1',
    'OK'        =>  '0',
    'WARNING'   =>  '1',
    'CRITICAL'  =>  '2',
);

GetOptions(\%opts, "hostname=s", "port=s") or &show_help;
&show_help unless $opts{'hostname'};

my $openssl_path="/usr/bin/openssl";
my @openssl_output;
my $status=0;
my $site = $opts{'hostname'};
my $port = $opts{'port'} || 443;
my $enddate;

unless (-x $openssl_path ){
        print "UNKNOWN: $openssl_path not found or is not executable by the nagios user\n";
        exit $return_codes{'UNKNOWN'};
}
## Get the certificate in text format ###
open (CMD,"echo QUIT | $openssl_path s_client -connect $site:$port 2>/dev/null| $openssl_path x509 -noout -text |") or print_usage() ;

########################################
##### Get Subject and Expiry date #####
my $sub_Name;
foreach my $line (<CMD>){
	chomp($line);
	if ( $line =~ /Subject:/) {
		$line =~ s/\s+//;
		my @Sname = split(/,/,$line);
                $sub_Name = &extract_Sub_name(@Sname);
	}
	if ( $line =~ /After/) {
		$line =~ s/\s+//;
		$line =~ s/(Not\ After\ :)(.*)/$2/ ;
		$enddate = $line;
	}
}
close (CMD);

#########################################
### Bail out with CRITICAL if we could not get a End Dat for the cert 
### This could also be if the host could not be contacted/is filtered/
### or if the SSL transaction fails
if (!defined($enddate)) {
	print " CRITICAL: Certificate not found or does not have a End Date defined\n";
	exit $return_codes{'CRITICAL'};
}

my ($eyear, $emonth, $eday) = Parse_Date($enddate);
my ($year, $month, $day) = Today();
my $diffDays = Delta_Days($year, $month, $day,
                         $eyear, $emonth, $eday) ;

my $cn_left = substr($site, index($site, ".")+1);

if ( $diffDays < 0 ){
	print " CRITICAL: Cert for $sub_Name expired " . abs($diffDays) . " days ago \n";
	exit $return_codes{'CRITICAL'};
} elsif ( $diffDays >=0 && $diffDays <=7 ) {
	print " CRITICAL: Cert for $sub_Name expires in $diffDays days\n";
	exit $return_codes{'CRITICAL'};
} elsif ( $diffDays >=8 && $diffDays <= 30 ) {
	print " WARNING: Cert for $sub_Name expires in $diffDays days\n";
	exit $return_codes{'WARNING'};
} elsif  ( lc($sub_Name) ne lc($site) && substr($sub_Name,0,1) ne '*') {
        print " CRITICAL: CN for certificate does not match hostname \n";
         exit $return_codes{'CRITICAL'};
### This is really a very long, messy conditional picked up from the postfix tls_verify.c, broken up to suit us
} elsif (substr($sub_Name,0,1) eq '*' && substr($sub_Name,1,1) eq '.' && substr($sub_Name,2) ne "" && lc($cn_left) ne lc(substr($sub_Name,2)) ) {
       print " CRITICAL: CN for wild card certificate (" . substr($sub_Name,2) . ") does not match hostname (" . $cn_left . ")\n";
       exit $return_codes{'CRITICAL'};
} else {
	print " OK: Cert for $sub_Name expires in $diffDays days\n";
	exit $return_codes{'OK'};
}
#### End main ###
### This extracts the CN from the Subject ###
### Could not find a decent way to implement URL check
sub extract_Sub_name {
        my $field; 
        my @Name = @_;
        foreach $field (@Name) {
	        if ( $field =~ /CN/ ) {
		     $field =~ s/\s+//;
		     my ($name,$junk) = split(/\//,$field);
                     return (substr($name,3)) ;
		}
	}
}

sub show_help {
    printf("\nPerl SSL certificate check plugin for Nagios\n");
    printf("Usage:\n");
    printf("
	  check_ssl_cert.pl --hostname <hostname> --port <port>
	  Options:
		--hostname hostname to check certificate for
		--port     ssl port
	");
    printf("Comes with absolutely NO WARRANTY either implied or explicit\n");
    printf("This program is licensed under the terms of the\n");
    printf("GNU General Public License\n(check source code for details)\n\n\n");
    exit($return_codes{"UNKNOWN"});
}
