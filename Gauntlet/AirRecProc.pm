#!/usr/bin/perl
# Author: Guillaume Germain (ggermain@arubanetworks.com)
# Date: 2014/06/18
# Description: tails AirRecorder files and inserts it into a MySQL DB

use strict;

package Gauntlet::AirRecProc;

sub new{
  my $class = shift;
  my %cmd_out;
  my $self = { file    => shift,
  	       mac     => shift};

  my $tmp;
  my @tmp_command; 

  open(FIC, $self->{file}) or die "OPENING FILE ERROR " . $self->{file};
  while(<FIC>){
    if($_ =~ /\.\.\.\.\./){
      %cmd_out = &process_command(\@tmp_command, \%cmd_out);
      @tmp_command = [];
    }else{
      $tmp = $_;
      $tmp =~ s/\n//;
      $tmp =~ s/\r//;
      push(@tmp_command, $tmp)
    }
  }
  close(FIC);
  
  $self->{cmd_out} = \%cmd_out;


  bless $self, $class;
  return $self;
}

sub getDebugClientTableByTime{
  my ($self, $user_ip, $time_data) = @_;
  
  my %tmp = %{$self->{cmd_out}};

  my $user_mac = $tmp{"show user"}{$user_ip}{mac};

  my $time_val = 0;

  foreach my $time_key (keys %{$tmp{"show ap debug client-table"}{$user_mac}}){
    #print $time_data . " " . $time_key . " " . abs($time_data - $time_key) . "\n";
    if(abs($time_data - $time_key) < abs($time_data - $time_val)){
      $time_val  = $time_key;
    }
  }
  return $tmp{"show ap debug client-table"}{$user_mac}{$time_val};
}




sub process_command{
  my ($arr_ref, $hash_ref) = @_;
  my %command_data;
  my @t = @$arr_ref;
  my %cmd_out = %{$hash_ref};  

  shift(@t);  
  
  while($t[0] =~ /^\/\/\/\/\//){
    my $l = shift(@t);
    $l =~ s/^\/\/\/\/\/ //;
    if(!defined($l) or $l eq ""){ next; }
    my @p = split(':\ ', $l);
    $command_data{$p[0]} = $p[1];
  } 

  if($command_data{"Command"} =~ /ap-name/){ 
     $command_data{"Command"} =~ /ap-name (\S+)/;
     $command_data{"AP_Name"} =  $1;
  }

  $command_data{"LocalBeginTime"} =~ /^(\w+)/;
  $command_data{"LocalBeginTime"} =  $1;
  $command_data{"LocalBeginTime"} =~ s/([0-9]{10})/$1\./;

  $command_data{"LocalEndTime"}  =~ /^(\w+)/;
  $command_data{"LocalEndTime"} =   $1;
 
 
  $command_data{"data"} = \@t;
 
  #print "Command: " . $command_data{"Command"} . " started at " . $command_data{"LocalBeginTime"} . "\n";  


    # /show ap debug radio-stats/) { %cmd_out = &show_ap_radio_stats(\%command_data, \%cmd_out); }
  if($command_data{"Command"} =~ /show user/){ 
	%cmd_out = &show_user(\%command_data, \%cmd_out); 
  }
  elsif($command_data{"Command"} =~ /show ap active/){ 
	%cmd_out = &show_ap_active(\%command_data, \%cmd_out); 
  }
  elsif($command_data{"Command"} =~ /show ap debug client-table/){ 
	%cmd_out = &show_ap_debug_client_table(\%command_data, \%cmd_out); 
  }


  return %cmd_out;
}



sub show_ap_radio_stats{
  my %meta    = %{$_[0]};
  my %cmd_out = %{$_[1]};
  my @data    = @{$meta{"data"}};
  my ($desc, $value);


}

sub show_user{
  my %meta = %{$_[0]};
  my %cmd_out = %{$_[1]};
  my @data = @{$meta{"data"}};

  foreach my $line (@data){
    if($line =~ /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}/){
      $line =~ /(\w+)(\W+)(\w+)(\W+)(\w+)\/(.+)\/(\S)/;
      #($meta{"AP_Name"},$essid,$bssid,$radio) = ($1,$5,$6,$7);


      my @u = split(" ", $line); 

      $cmd_out{"show user"}{$u[0]}{mac}  = $u[1];
      $cmd_out{"show user"}{$u[0]}{role} = $u[2];
      $cmd_out{"show user"}{$u[0]}{line} = $line;
    }
  }
  return %cmd_out;
}

sub show_ap_active{
  my %meta = %{$_[0]};
  my %cmd_out = %{$_[1]};
  my @data = @{$meta{"data"}};

  foreach my $line (@data){
    if($line =~ /AP\:/){
      my @ap = split(" ", $line);

      $cmd_out{"show ap active"}{$ap[0]} = $line;
    }
  }

  return %cmd_out;
}





sub show_ap_debug_client_table{
  my %meta = %{$_[0]};
  my %cmd_out = %{$_[1]};
  my @data = @{$meta{"data"}};



  foreach my $line (@data){
    if($line =~ /Last_Rx_SNR/){
      $line =~ s/(.+)Assoc_State(\s+)//;
      $cmd_out{header}{"show_ap_debug_client_table"} = $line;
    }

    if($line =~ /^(?:[0-9a-f]{2}\:){5}[0-9a-f]{2}/i){
      my @ss = split(" ", $line);
      chomp($line);

      $line =~ s/(.+)Associated(\s+)//;
      $cmd_out{"show ap debug client-table"}{$ss[0]}{$meta{LocalBeginTime}} = $line;


    }
  }

  return %cmd_out;
}

sub getHeader{
  my ($self, $head) = @_;

  return $self->{cmd_out}->{header}{$head};
}

1;
