#!/usr/bin/perl
# Author:      Guillaume Germain
# Description: 

use POSIX;
use IO::Socket::INET;
use IO::Select;
use Time::HiRes qw(time);
use IO::Handle;
use Gauntlet::Messaging;
use Config;

use constant DATETIME => strftime("%Y-%m-%d_%H-%M-%S", localtime);
use strict;

my $IPERF_PATH = "iperf";
my $IPERF_TMP_FILE = "iprf.tmp";

my $version = "1.10.1";


### Script initialisation and other cleanup;
###
###

print "Gauntlet Testing - A test which you might not survive - v$version\nAuthored by Guillaume Germain (ggermain\@arubanetworks.com)\n\n";

if(!defined($ARGV[0])){
  print "Usage: perl run_test.pl NETWORK_TO_SCAN TEST_TYPE (IPERF_PARAMETER)\n";
  print "  NETWORK_TO_SCAN: nmap format (example: 192.168.1.1-254)\n";
  print "  TEST_TYPE:       IPERFUDP, IPERFTCP, FTP\n";
  print "  IPERF_PARAMETER: For IPERFTCP, specify Window Size (example 512k)\n";
  print "                   For IPERFUDP, specify bandwidth   (example 5M)\n";
  print "  RUN_COMMAND:     Run command on remote hosts and saves output in 'command_outputs' folder\n\n";
  print "Or run with with -c to use the values in config.txt: perl run_the_gauntlet.pl -c\n\n";
  exit();
}


my %params;

open(FIC, "./config.txt");
foreach my $line (<FIC>){
  ## Skip comments 
  if($line =~ /^\#/ or $line !~ /\=/){ next; }
  chomp($line);
  $line =~ s/\s//ig;
  my @splt = split("=", $line);
  $params{$splt[0]} = $splt[1];
}
close(FIC);

if(defined($params{IPERF_PATH})){
    $IPERF_PATH = $params{IPERF_PATH};
}

if($ARGV[0] ne "-c"){
  $params{NETWORK_TO_SCAN}          = $ARGV[0];
  $params{TEST_TYPE}                = $ARGV[1];
  $params{WINDOW_SIZE_OR_BANDWIDTH} = $ARGV[2];
}

my $now 		     	    = DATETIME;
my $test_id			    = &timestmp(time);
my $clear_string             	    = `clear`;
my ($windows_command, $mac_command, %host_list, $kairos_sckt);
my $test_start_time;




if($params{TEST_TYPE} =~ /RUN_COMMAND/){
    print "Please enter the command you want to run on the hosts\n";
    print " WINDOWS: ";
    $windows_command = <STDIN>;
    chomp($windows_command);

    print "MAC OS X: ";
    $mac_command = <STDIN>;
    chomp($mac_command);
}


#####===========
#### Discovery 
#####===========

print &curTime . " Scanning " . $params{NETWORK_TO_SCAN} . " network using nmap... please wait.\n";

my @nmap_output;

if($params{LITE_MODE} eq "YES"){
	if(defined($params{HOST_FILE})){
	    @nmap_output = `nmap -p 5001 -iL $params{HOST_FILE} -n -vv -Pn | grep iscove 2> /dev/null`;
    	}else{
            @nmap_output = `nmap -p 5001 $params{NETWORK_TO_SCAN} -n -vv -Pn | grep iscove 2> /dev/null`;
	}
}else{
	if(defined($params{HOST_FILE})){
		@nmap_output = `nmap -p $params{INIT_PORT} -iL $params{HOST_FILE} -n -vv -Pn | grep iscove 2> /dev/null`;
	}else{
    		@nmap_output = `nmap -p $params{INIT_PORT} $params{NETWORK_TO_SCAN} -n -vv -Pn | grep iscove 2> /dev/null`;
	}
}

if(@nmap_output == 0){ print &curTime . " No clients found during discovery. Exiting.\n"; exit; }
else{ print &curTime . " Done scanning! Found "; print 0+@nmap_output . " hosts\n"; }




#####===========
#### ARP discovery
#####===========

my @arp_entries = `arp -an`;
my %arp;

foreach my $arp_line (@arp_entries){
  $arp_line =~ s/(\(|\))+//ig;
  my @tmp = split(" ", $arp_line);
  $arp{$tmp[1]} = $tmp[3];
}

#####===========
#### AirRecorder
#####===========


my @pid;

if(defined($params{ARUBA_CONTROLLER_IP}) && defined($params{ARUBA_LOGIN}) && defined($params{ARUBA_PASS}) && defined($params{ARUBA_AIRREC_CONTROLLER_FILE})){
  `mkdir -p ./airrec_logs`;
  print &curTime . " Starting controller AirRecorder\n";

  system("java -jar ./lib/AirRecorder-1.5.1-release.jar -c ./$params{ARUBA_AIRREC_CONTROLLER_FILE} -u $params{ARUBA_LOGIN} -p $params{ARUBA_PASS} -e '' --log-file ./airrec_logs/$now-controller.log $params{ARUBA_CONTROLLER_IP} --log-store file,zmq 2>&1 >/dev/null &");

}

if(defined($params{ARUBA_AP_IP}) && defined($params{ARUBA_AIRREC_AP_FILE})){ 
  `mkdir -p ./airrec_logs`;
  print &curTime . " Starting AP AirRecorder\n";
  
  system("java -jar ./lib/AirRecorder-1.5.1-release.jar -c ./$params{ARUBA_AIRREC_AP_FILE} --ap -u \"\" -p \"\" -e \"\" --log-file ./airrec_logs/$now-ap.log $params{ARUBA_AP_IP} --log-store file,zmq 2>&1 >/dev/null &");

 
}


#####===========
#### Remote initiation
#####===========

foreach my $line (@nmap_output){
                chomp($line);
                my @t = split(" ", $line);
                $host_list{$t[5]}{done} = 0;
}

$test_start_time = time + $params{TEST_START_DELAY};

if($params{LITE_MODE} ne "YES"){

	foreach my $host_addr (keys %host_list){

#  my $pid = fork();
# if($pid == 0){
#  &fork_init;
# }




		my $socket = new IO::Socket::INET (PeerHost => $host_addr, PeerPort => $params{INIT_PORT}, Proto => 'tcp', Timeout => 2) or next;  

		my $msg = Gauntlet::Messaging->encode_test_args(
				{TEST_TYPE	=> $params{TEST_TYPE},
				REPORT_INTERVAL	=> $params{REPORT_INTERVAL},
				TEST_DURATION	=> $params{TEST_DURATION},
#				BATCH_REPORT    => $params{BATCH_REPORT},
				REPORTING_IP	=> $params{REPORTING_IP},
				SERVER_VERSION	=> $version});





		if($params{TEST_TYPE} eq "IPERFTCP" || $params{TEST_TYPE} eq "IPERFUDP" || $params{TEST_TYPE} eq "PASSIVE" || $params{TEST_TYPE} eq "FTP"){
			$socket->send($msg);
			$socket->close();
			print &curTime . " Sent $params{TEST_TYPE} start to " . $host_addr . "\n";
		}
		elsif($params{TEST_TYPE} =~ /RUN_COMMAND/i){
			print &curTime . " Sent run_command request to " . $host_addr . "\n";
			$socket->send("RUN_COMMAND,$windows_command,$mac_command,$version");
			$socket->close();
		}
		else{
			die "invalid test type. valid test types: FTP, IPERFTCP, IPERFUDP, RUN_COMMAND";
		}

	}



### Delay between client trigger and start of test on server side
	sleep($params{TEST_START_DELAY});

}

`rm -f $IPERF_TMP_FILE`;

sleep(3);
if($params{TEST_TYPE} =~ /IPERF/){
	foreach my $host (keys %host_list){
		if($params{TEST_TYPE} =~ /IPERFTCP/){
			if($params{LITE_MODE} eq "YES"){
				system("$IPERF_PATH -c $host -w $params{WINDOW_SIZE_OR_BANDWIDTH} -P $params{IPERF_STREAMS} -t $params{TEST_DURATION} -i $params{REPORT_INTERVAL} -y C >> $IPERF_TMP_FILE &");
			}else{
				system("$IPERF_PATH -c $host -p $params{IPERF_PORT} -w $params{WINDOW_SIZE_OR_BANDWIDTH} -P $params{IPERF_STREAMS} -t $params{TEST_DURATION} -i $params{REPORT_INTERVAL} -y C >> $IPERF_TMP_FILE &");
			}

		}elsif($params{TEST_TYPE} =~ /IPERFUDP/){
			if($params{LITE_MODE} eq "YES"){
				system("$IPERF_PATH -c $host -u -b $params{WINDOW_SIZE_OR_BANDWIDTH} -t $params{TEST_DURATION} -i $params{REPORT_INTERVAL} -y C >> $IPERF_TMP_FILE &");
			}else{
				system("$IPERF_PATH -c $host -p $params{IPERF_PORT} -u -b $params{WINDOW_SIZE_OR_BANDWIDTH} -t $params{TEST_DURATION} -i $params{REPORT_INTERVAL} -y C >> $IPERF_TMP_FILE &");
			}
#print "iperf -c $host -p $params{IPERF_PORT} -u -b $params{WINDOW_SIZE_OR_BANDWIDTH} -t $params{TEST_DURATION} -i $params{REPORT_INTERVAL} -y C >> $IPERF_TMP_FILE & \n";
		}
	}
}
sleep(1);


#####============
#### Listening and reporting part of the script
#####============

#### Starting reporting socket

my $reporting_socket;
my $socket_select;

if($params{LITE_MODE} ne "YES"){
	$reporting_socket = new IO::Socket::INET(LocalPort => $params{REPORTING_PORT}, Proto => 'udp') or die "Could not open UDP port " . $params{REPORTING_PORT} . "\n";
	$socket_select = IO::Select->new($reporting_socket) or die "IO::Socket $!";
}

my ($socket,$received_data);
my ($peeraddress,$peerport);

my %dataSpeed;
my %dataTotal;


if($params{TEST_TYPE} eq "RUN_COMMAND"){
	while(my @ready_socks = $socket_select->can_read($params{MAX_TIMEOUT})){
		foreach my $fh (@ready_socks){
			if($fh == $reporting_socket){
				$fh->recv($received_data, 10240);
				my $peer_address = $fh->peerhost();

				print &curTime . " Received data for " . $fh->peerhost() . "\n";
				`mkdir -p ./command_outputs/$now`;

				open(OUT, ">./command_outputs/$now/$peer_address");
				print OUT $received_data;
				close(OUT);
			}
		}
	}

	print &curTime . " no new data $params{MAX_TIMEOUT} seconds. done!\n";

}
else{
	my $filename;
	

	if($params{TEST_TYPE} eq "FTP"){ $filename = $now . "_FTP.spdata"; }
	else{ $filename = $now . "_" . $params{TEST_TYPE} . "_" . $params{WINDOW_SIZE_OR_BANDWIDTH}; }
	`mkdir -p ./speed_data_files`;

	open(OUT, ">./speed_data_files/$now.spdata") or die "Can't open output file\n";
#Empty buffer right away... No caching
	select((select(OUT), $|=1)[0]);

# Open TCP socket for KairosDB
	if(defined($params{KAIROSDB_IP}) && defined($params{KAIROSDB_PORT})){
		print &curTime . " Opening KAIROS socket\n"; 
		$kairos_sckt = new IO::Socket::INET (PeerHost => $params{KAIROSDB_IP}, PeerPort => $params{KAIROSDB_PORT}, Proto => 'tcp', Timeout => 2) or warn "Could not open KAIROS socket\n"; 
	}


### HEADER
	print OUT "HEADER," . $now . "," . $test_id . "," . $params{AP_PARAM} . "," . $params{TEST_TYPE} . ",$params{WINDOW_SIZE_OR_BANDWIDTH},$params{IPERF_RUN_TIME},$version\n";

	my $done = 0;
	my $display = 0;
	

	if($params{LITE_MODE} eq "YES"){
		my $iperf_start_time = 0;
		my $epoch_start_time = 0;		

		open(IPERF_FIC, $IPERF_TMP_FILE) or die "Can't open iperf data file: $IPERF_TMP_FILE\n";
		while(1){
			while(<IPERF_FIC>){
				chomp($_);
				#20180208172122,192.168.10.189,56429,192.168.10.188,5001,4,29.0-30.0,11665408,93323264	
				
				my @splt = split(",", $_);
				my @tmp = split("-", $splt[6]);
				if($iperf_start_time = 0){
					$iperf_start_time = $splt[0];
					$epoch_start_time = time;
				}
				if($params{IPERF_STREAMS} != 1 && $splt[5] ne "-1"){
					next; 
				}
				my $test_time = $epoch_start_time + $tmp[0];
				if($tmp[1] - $tmp[0] > $params{REPORT_INTERVAL}){ 
					$host_list{$splt[3]}{done}  = 1;
					print OUT $test_time  . "," . $splt[3] . ",DATA_CLIENT,$test_time,-1,-1\n";
				}
				else{ 
					$host_list{$splt[3]}{qty} += $splt[7];
					$host_list{$splt[3]}{speed} = $splt[7] * 8;
					print OUT $test_time . "," . $splt[3] . ",DATA_CLIENT,$test_time," . $splt[7] . "\n";
				}

# Is the test done?
				$done = 1;
				foreach my $host (keys(%host_list)){
					if($host_list{$host}{done} == 0){
						$done = 0;
					}
				}
				if($done == 1){
					print &curTime . " Test done!\n";
					sleep 2;
					&cleanup();
					exit;
				}


				if($display >= @nmap_output){
					&display();
					$display = 0;
				}
				$display++;
			}
			sleep 1;
			seek(IPERF_FIC, 0, 1);
		}
	}
	else{
		while(my @ready_socks = $socket_select->can_read($params{MAX_TIMEOUT})){
			foreach my $fh (@ready_socks){
				if($fh == $reporting_socket){   
					$reporting_socket->recv($received_data,1024);
					my $peer_address = $reporting_socket->peerhost();

# DATA_CLIENT,interval_id|speed_in_bps|amount_of_data_sent_for_interval,other_interval

					chomp($received_data);
					my @tmp_splt = split(",", $received_data);

					if($tmp_splt[2] < 0){
						$host_list{$peer_address}{done}  = 1;   
					}else{
						$host_list{$peer_address}{qty}  += $tmp_splt[2];
						$host_list{$peer_address}{speed} = $tmp_splt[2] * 8;
					}


# Is the test done?
					$done = 1;
					foreach my $host (keys(%host_list)){
						if($host_list{$host}{done} == 0){
							$done = 0;
						}
					}

					if($done == 1){ 
						print &curTime . " Test done!\n";
						sleep 2;
						&cleanup();
						exit;
					}

					print OUT time . ",$peer_address,$received_data\n";

					if(defined($kairos_sckt) && $received_data !~ /\-/){
						my @splt_tmp = split(",", $received_data);

						$kairos_sckt->send("put $params{KAIROSDB_PREFIX}.bytes " . &timestmp(time) . " " . $host_list{$peer_address}{qty} . " test.id=$test_id ip=$peer_address direction=from_ap test.type=$params{TEST_TYPE} ap.configuration=$params{AP_PARAM}\n");
					}

					if($display >= @nmap_output){
						&display();
						$display = 0;
					}
					$display++;

				}
			}
		}
	}
	print &curTime . " No new data for " . $params{MAX_TIMEOUT} . " seconds... done!\n";

	close(OUT);
	$reporting_socket->close();

}
&cleanup();

exit;

sub cleanup{
	`killall iperf 2>&1 /dev/null`;

	`kill \$(ps aux | grep 'airrec_log' | awk '{print \$2}')`;

}

sub whatOS{
	if($Config{osname} =~ /MSWin32/){
		return "win";
	}elsif($Config{osname} =~ /darwin/){
		return "osx";
	}else{
		return "linux";
	}

}



sub timestmp{
	my $tm = shift;
	$tm = $tm * 1000;
	$tm    =~ s/\.(.+)$//ig;
	return $tm;
}

sub frmtUnit(){
	my $qty = $_[0];

	if($qty == 0){  	      return 							 0;  }
	elsif($qty < 999){          return                    $qty                          . "B"  }
	elsif($qty < 999999){       return sprintf("%.0f",   ($qty / 1024))                 . "K"; }
	elsif($qty < 999999999){    return sprintf("%.1f",  (($qty / 1024) / 1024))         . "M"; }
	elsif($qty < 999999999999){ return sprintf("%.1f", ((($qty / 1024) / 1024) / 1024)) . "G"; }
}


### Returns formated time
sub curTime{
	return strftime("[%Y-%m-%d %H:%M:%S]", localtime);
}


sub display{

	print $clear_string;
	print sprintf("%-*s", 24, "MAC") .
		sprintf("%-*s", 24, "Host") .
		sprintf("%-*s", 24, "Speed") .
		sprintf("%-*s", 24, "Data Received") . "\n";
	my $totalData;
	foreach my $host_addr (keys(%host_list)){
		print sprintf("%-*s", 24, $arp{$host_addr}) .
			sprintf("%-*s", 24, $host_addr) .
			sprintf("%-*s", 24, &frmtUnit($host_list{$host_addr}{speed}) . "bps") .
			&frmtUnit($host_list{$host_addr}{qty}) . "B";
		$totalData += $host_list{$host_addr}{qty};
		if($host_list{$host_addr}{done} == 1){ print "\tDone!\n"; }else{ print "\n"; }
	}
	print "\nTest Type:          \t" . $params{TEST_TYPE};
	if($params{TEST_TYPE} =~ /IPERF/){ print " " . $params{WINDOW_SIZE_OR_BANDWIDTH}; }
	print "\nNumber of hosts:    \t";
	print 0+@nmap_output;
	print "\nTotal data received:\t" . &frmtUnit($totalData) . "B\n";	

}
