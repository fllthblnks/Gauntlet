#!/usr/bin/perl
# Author:          Guillaume Germain (ggermain@hpe.com)
# Description:     Client-side component of a multiclient speed test solution. This script listens on port 51090 and await orders from
#		   a test server which it then reports it's results to.
# Date: 12/05/2014

use lib '.';
use IO::Socket::INET;
use POSIX;
use MIME::Base64;
use Time::HiRes qw(time usleep);
use Config;
use strict;
use Gauntlet::Messaging;

my $HASH_VALUE     = 2048;
my $LISTENING_PORT = 51091;
my $REPORTING_PORT = 51095;
my $IPERF_PORT     = 5005;
my $MAX_TIMEOUT    = 10;                                   # Value in seconds
my $PIPE_FILE = './.client.pipe';

my $version = "1.10.1";
my ($peer_address, $peer_port, $reporting_sock);
my ($bytes_before, $bytes_transfered, $data_measured, %int_results, %iperf_results, %airport_results, $dbg, $os);
my %test_param;
my $test_state = "";
my $time_remaining;
my $test_id = 0;
my $IPERF_PATH = "./iperf_osx";
local $| = 1;


print "Gauntlet: A test which you might not survive. v$version\nAuthored by Guillaume Germain (ggermain\@hpe.com)\n\n";

## Enabling debug mode
if(defined($ARGV[0])){ 
  if($ARGV[0] eq "-d"){ $dbg = 1; }else{ $dbg = 0; }
}else{
  $dbg = 0;
}

# FORK SOCKET LISTENER
my $pid = fork();

if($pid == 0){
  inetListener();
  die "SOCKET LISTENER PROCESS DIED";
}

### Allow the forked process to catch up and open the pipe file
sleep(1);




#### Stepping into the main loop
####
####
while(1){
  my $time_before_loop = time;


  open(COMMANDS, $PIPE_FILE) or sleep(1), next; 
  my @command_lines = <COMMANDS>;
  close(COMMANDS);

  
  foreach my $line (@command_lines){
    $line =~ s/^(\d+)//;

    if($test_id >= $1){ next; }
    $test_id = $1;


    &resetTest;

    %test_param = Gauntlet::Messaging->decode_test_args($line);
    $test_param{TEST_ID} = $1;
    

    $test_state = "STARTING";
  }




  if($test_state eq "STARTING"){
    if($test_param{SERVER_VERSION} ne $version){
      print &curTime . " The Gauntlet server is running a different version ($test_param{SERVER_VERSION}). Please update\n";
    }
    &startTest;
    
    $time_remaining = $test_param{TEST_DURATION};

    # Update test state
    $test_state = "RUNNING";




  }elsif($test_state eq "RUNNING"){
    &sendData("DATA_CLIENT," . time . "," . &measure);

    $time_remaining -= $test_param{REPORT_INTERVAL};


    if($time_remaining < 0){
	$test_state = "COMPLETING";
    }

    &speedReport($data_measured, $bytes_transfered);
  
    if($dbg == 1){
      print $time_remaining . "\n";
    }
    

    usleep(1000 * 1000 * ($test_param{REPORT_INTERVAL} - (time - $time_before_loop)));





  }elsif($test_state eq "COMPLETING"){
	  $test_state = "COMPLETED";
          &speedReport($data_measured, $bytes_transfered);
	  print "\n";
	  &sendData("DONE," . time . ",-1,-1");
	  $test_state = "IDLE";




  }else{
    # Any other test, sleep for 1 second.
    sleep(1);
  }

}



###
# Different functions
###
sub startTest{
	
  if($test_param{TEST_TYPE} =~ /IPERF/){
    &startIperfTest;
    &resetInterface;

  }elsif($test_param{TEST_TYPE} eq "PASSIVE"){
    &resetInterface;
  }
}

sub measure{
 
  if($test_param{TEST_TYPE} =~ /IPERF/){  $data_measured = &measureIperf;      }
  else{					  $data_measured = &measureInterface;  }

  if(defined($data_measured)){
    return $data_measured;
  }else{
    return 0;
  }
}

sub resetInterface{
  $bytes_transfered = 0;
  $bytes_before = &readInterfaceBytes;
}

sub measureInterface{

  my $bytes_total = &readInterfaceBytes;
  my $bytes = $bytes_total - $bytes_before;

  $bytes_before = $bytes_total;
  $bytes_transfered += $bytes;
  $int_results{time} = $bytes;  
  
  return $bytes;
}


### IPERF TEST
sub startIperfTest{

  if($test_param{TEST_TYPE} eq "IPERFUDP"){
    if(&whatOS eq "win"){
      system("start /B start_iperf_udp.bat");
    }else{
      `$IPERF_PATH -u -p $IPERF_PORT -i $test_param{REPORT_INTERVAL} -y C &> ./iperf_output.log &`;
    }
  }elsif($test_param{TEST_TYPE} eq "IPERFTCP"){
    if(&whatOS eq "win"){
      system("start /B start_iperf_tcp.bat");
    }else{
      `$IPERF_PATH -s    -p $IPERF_PORT -i $test_param{REPORT_INTERVAL} -y C &> ./iperf_output.log &`;
    }
  }

}

### Stop IPERF test
sub stopIperfTest{
  %iperf_results = {};


  if(&whatOS eq "win"){
    system("start /B taskkill /IM iperf.exe /F");    
  }else{
    `killall iperf 2> /dev/null`;
  }
} 



### Measure IPERF
sub measureIperf{
  
  open(FIC, "./iperf_output.log");
  my @lines = <FIC>;
  close(FIC);

  foreach my $line (@lines){
    chomp($line);
#    if($dbg == 1){ print $line . "\n"; } 

    my @tmp_splt = split(",", $line);
    $tmp_splt[6] =~ /(\d+)\./;
    my $time = $1;

    if(!defined($iperf_results{$time})){
      $iperf_results{$time}{bytes} = $tmp_splt[7];
      $bytes_transfered += $tmp_splt[7];
      if($dbg == 1){ print $tmp_splt[7]; }
      return $tmp_splt[7];
    }
  }

}
     
      

### RUN COMMAND
sub runCommand{
  my $command = shift;

  my $reporting_sock = IO::Socket::INET->new(PeerAddr => $test_param{REPORTING_IP},
 			                     PeerPort => $REPORTING_PORT, 
 			                     Proto    => 'udp') 
                                             or return;

  
  my @tmp = `$command`;
  my $message;
  foreach my $line (@tmp){ $message .= $line; }
  $reporting_sock->send($message);
  $reporting_sock->close();
}



### Testing for now, doesnt work
sub captureTcpdump{
  system("tcpdump -i en0 -w test_tcpdump.pcap 2>&1 /dev/null &"); 
  
   
}


### Format speed report
sub speedReport{
  my ($speed,$dataTransfered) = @_;

  if(!defined($speed)){ $speed = 0; }

  if($dbg == 1){
    print &curTime . " Speed: " . &frmtUnit($speed * 8) . "bps Data Transfered: " . &frmtUnit($dataTransfered) . "              ";
  }else{
    print "\r" . &curTime . " Speed: " . &frmtUnit($speed * 8) . "bps Data Transfered: " . &frmtUnit($dataTransfered) . "              ";
  }
}



### Formats the unit with speed value
sub frmtUnit(){
  my $qty = $_[0];

  if($qty == 0){ return 0; }
  elsif($qty < 999){ return $qty . "B"}
  elsif($qty < 999999){ return sprintf("%.0f", ($qty / 1024)) . "K"; }
  elsif($qty < 999999999){ return sprintf("%.1f", (($qty / 1024) / 1024)) . "M"; }
  elsif($qty < 999999999999){ return sprintf("%.1f", ((($qty / 1024) / 1024) / 1024)) . "G"; }
}



### Returns formated time
sub curTime{
  if($test_state ne ""){
    return strftime("[%Y-%m-%d %H:%M:%S", localtime) . " " . $test_state . "]";
  }else{
    return strftime("[%Y-%m-%d %H:%M:%S", localtime) . "]";
  }
}


## Module figures out which OS this script is running on
sub whatOS{
  if($Config{osname} =~ /MSWin32/){
    return "win";
  }elsif($Config{osname} =~ /darwin/){
    return "osx";
  }else{
    return "linux";
  }

}


## Module to read the amount of bytes transfered on the en0 interface on a Macbook
# Currently, the windows interface remains unbuilt.
sub readInterfaceBytes{

  if(&whatOS eq "win"){

  }elsif(&whatOS eq "osx"){
    my @val = `netstat -ibn | grep en0`;
    my @tmp_splt = split(" ", $val[0]);

    #en0   1500  10.59/19      10.59.24.194     5705156     - 7106275157  3259759     -  443173671     -
    return $tmp_splt[6] + $tmp_splt[9];
  }elsif(&whatOS eq "linux"){
    
  }

}


## Function to read the state of the airport software on OSX. Currently un-used.
sub wifiInfo{

  my @airport_output = `/System/Library/PrivateFrameworks/Apple80211.framework/Versions/A/Resources/airport -I`;
  my %data;

  foreach my $arg (@airport_output){
    $arg =~ s/^(\W+)//;
    chomp($arg);
    my @t = split(": ", $arg);

    $data{$t[0]} = $t[1];
  }

  $data{agrCtlRSSI}  =~ s/\-//;
  $data{agrCtlNoise} =~ s/\-//;
  
  return "$data{agrCtlRSSI},$data{agrCtlNoise},$data{lastTxRate},$data{MCS}";
}


##
#
sub resetTest{
  if(defined($test_param{TEST_TYPE})){
    if($test_param{TEST_TYPE} =~ /IPERF/){
      &stopIperfTest; 
    }
  }

  $test_state = "IDLE";

  undef %test_param;

}


sub sendData{
	my $data_to_send = shift;

	if(!defined($reporting_sock)){
		$reporting_sock = IO::Socket::INET->new(PeerAddr => $test_param{REPORTING_IP},
	                                                PeerPort => $REPORTING_PORT,
 						        Proto    => 'udp')
	                                                or return;

	}

	$reporting_sock->send($data_to_send);

}

sub inetListener{
  my $test_id = 0;

  my $listening_socket = new IO::Socket::INET(
                                 Listen    => 5,
                                 LocalPort => $LISTENING_PORT,
                                 Proto     => 'tcp',
                                 Reuse     => 1) or return;

  print &curTime . " Waiting for instructions on TCP port $LISTENING_PORT\n";


  open(FIC, ">$PIPE_FILE");
  select((select(FIC), $|=1)[0]);

  while(my $client_socket = $listening_socket->accept()){

    my ($peer_address, $peer_port) = ($client_socket->peerhost(), $client_socket->peerport());

    my $received_data = <$client_socket>;
    if(!defined($received_data)){ next; }

    $test_id++;


    open(FIC, ">>$PIPE_FILE");
    print FIC $test_id . "<PEER_ADDRESS>$peer_address</PEER_ADDRESS>$received_data\n";
    close(FIC);

    sleep(1);
  }


}
