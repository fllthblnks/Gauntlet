#!/usr/bin/perl
# Author: 	Guillaume Germain (ggermain@arubanetworks.com)
# Data:		2014/12/01
# Filename:     display_data.pl
# Description: 	This script will format and display the spdata files that are obtained by the run_test.pl application
#               If you run this application with no arguments, it will diplay the latest file in the directory and update the screen as it gets updated.
#	 	Otherwise, you can specify a file and it will display it and quit
use strict;

require Gauntlet::DataStruct;
use Term::ANSIColor qw(:constants);
use POSIX;
use constant DATETIME => strftime("%Y-%m-%d_%H-%M-%S", localtime);


my $version = "1.1.2";
my $PERF_RUN_TIME = 120;
my $IPERF_REPORT_INTERVAL = 1;
my $SLEEP_INTERVAL = $IPERF_REPORT_INTERVAL;

my $loop_times = 0;
my $filename = $ARGV[1];
my $csv_mode = 0;
my $clear_string;

if($ARGV[0] eq "-c"){
  $csv_mode = 1;
  print "CVS_MODE\n";
}else{
  print "Multi-Client Throughput Test Engine v$version\nAuthored by Guillaume Germain (ggermain\@arubanetworks.com)\n\n";

  print "Display mode... $csv_mode\n";
}

if(!defined($ARGV[0])){
  print "Usage: perl display_data.pl options [FILE_NAME]\n";
  print "  options:\n";
  print "  -c: outputs a cvs to the terminal that can be opened in excel or any other software\n";
  print "  -d: displays the information live on the screen\n\n";
  print "  FILE_NAME:	Specify a .spdata file to display data from that file\n";
  print "  If run with no arguments, the scrit will look for the latest file in ./speed_data_files\n\n";

  print "Color information:\n";
  print RED, "Values with 0 mbps\n";
  print YELLOW, "Values between 0 and 2 mbps\n", RESET;
  print "Values between 2 and 5 mbps\n";
  print GREEN, "Values greater than 5 mbps\n", RESET;
  exit();
}


if(!defined($ARGV[1])){ my @filelist = `ls -t ./speed_data_files/*.spdata`; $filename = $filelist[0]; }

chomp($filename);

if($csv_mode == 1){ 
  print $filename . "\n"; 
}else{
  print "Reading file: " . $filename . "\n";
  sleep 2;

  $clear_string = `clear`;
  print $clear_string;
}


my $periods_with_no_new_data = 0;
my $maxTime = 0;

while(1){
  $loop_times++;
  my %dataSpeed;  # dataSpeed{time_stamp}{machine && aggregate} = speed_in_bps 
  my %dataTotal;  # dataTotal{machine} = data_in_bps
  my $totalTotal;  
  my $zeros = 0;
  my $period_updated = 0;
  my @file_header;

  my $dataStruct = Gauntlet::DataStruct->new($filename);
     

  ### Check if there has been data added to the file, if not, kill it
  if($period_updated > 0){ 
    $periods_with_no_new_data = 0; 
  }else{ 
    if($periods_with_no_new_data >= 10){ 
      print "Done."; sleep 1; exit; 
    }else{ 
      $periods_with_no_new_data++; 
    }  
 }

  if($dataStruct->getHeader()->{test_type} eq "FTP"){ 
    print "FTP test";
  }else{
    print $dataStruct->getHeader()->{test_type} . " test using " . " with ";
    if($dataStruct->getHeader()->{test_type} =~ /UDP/){ print " bandwidth"; }else{ print " window size"; }
  }
  print " TOTAL DATA SENT: " . &frmtSpeed($totalTotal) . "B\n";

  # Print header
  print "";
  if($csv_mode == 1){ print ","; }else{ print "\t"; }
  foreach my $host (sort { $a cmp $b } $dataStruct->getHostList()){
    if($csv_mode == 1){ print $host . ","; }
    else{ 
      $host =~ /(......)$/;
      print $1 . "\t";
    }
  }
  print "TOTAL\n";

 
  foreach my $time (sort { $a <=> $b } $dataStruct->getTimeList){
    if($csv_mode == 1){ print "$time,"; }else{ print "$time sec\t"; }
    foreach my $host (sort { $a cmp $b } $dataStruct->getHostList()){
      
      if($csv_mode == 1){ print &frmtSpeed($dataStruct->speedHostTime($host, $time)) . ","; }
      else{
        if(   &frmtSpeed($dataStruct->speedHostTime($host, $time)) == 0     ){ print RED,    &frmtSpeed($dataStruct->speedHostTime($host, $time)) . "\t", RESET; $zeros++; }
        elsif(&frmtSpeed($dataStruct->speedHostTime($host, $time)) < 2000000){ print YELLOW, &frmtSpeed($dataStruct->speedHostTime($host, $time)) . "\t", RESET; }
        elsif(&frmtSpeed($dataStruct->speedHostTime($host, $time)) > 5242880){ print GREEN,  &frmtSpeed($dataStruct->speedHostTime($host, $time)) . "\t", RESET; }
        else{					   			       print         &frmtSpeed($dataStruct->speedHostTime($host, $time)) . "\t"; }
      }

    }
    print &frmtSpeed($dataStruct->speedHostTime("aggregate", $time));
    print "\n";
  }

  ## PRINT TOTAL DATA SENT
  print "DATASNT ";
  foreach my $host ( sort { $a cmp $b } $dataStruct->getHostList()){
    if($csv_mode == 1){ print &frmtSpeed($dataStruct->getHostTotal($host)) . ",";  }
    else{               print &frmtSpeed($dataStruct->getHostTotal($host)) . "\t"; }
  }
  print "\n";

  if($csv_mode == 0){
    print "HOST\t"; 
    foreach my $host (sort { $a cmp $b } $dataStruct->getHostList()){
      $host =~ /(......)$/;
      print $1 . "\t";
    }
  }
 
  # PRINT PERCENTAGE OF TOTAL
  print "\nPERCNTG ";
  foreach my $host ( sort { $a cmp $b } keys(%dataTotal)){
    print sprintf("%.2f", $dataTotal{$host} / $totalTotal * 100) . "%";
    if($csv_mode == 1){ print ","; }else{ print "\t"; }
  }
  print "\n";
  
  print "NUMBER OF ZEROS: " . $zeros . "\n"; 

  if(defined($ARGV[1]) or $csv_mode){
    exit;
  }else{
    sleep $SLEEP_INTERVAL;
    print $clear_string;
  }
}



sub frmtSpeed(){
  my $dt = $_[0];


  if($dt == 0){ return 0; }
  elsif($dt < 999){ return $dt . "B"}
  elsif($dt < 999999){ return sprintf("%.0f", ($dt / 1024)) . "K"; }
  elsif($dt < 999999999){ return sprintf("%.1f", (($dt / 1024) / 1024)) . "M"; }
  elsif($dt < 999999999999){ return sprintf("%.1f", ((($dt / 1024) / 1024) / 1024)) . "G"; }   
 
  
}
