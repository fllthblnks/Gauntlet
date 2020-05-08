#!/usr/bin/perl
# Author: Guillaume Germain (ggermain@arubanetworks.com)
# Date: 2014/06/18
# Description: tails AirRecorder files and inserts it into a MySQL DB

use strict;

package Gauntlet::AirRecAPProc;

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

sub getArgumentList{
  my ($self) = @_;
  my %cmd_out = %{$self->{cmd_out}};

  
  return keys %{$cmd_out{"cat_proc_drop_list"}};
}

sub getDataByTime{
  my ($self, $argument, $time_data) = @_;
  
  my %tmp = %{$self->{cmd_out}};

  my $time_val = 0;

  foreach my $time_key (keys %{$tmp{"cat_proc_drop_list"}{$argument}}){
    if(abs($time_data - $time_key) < abs($time_data - $time_val)){
      $time_val  = $time_key;
    }
  }

  return $tmp{"cat_proc_drop_list"}{$argument}{$time_val};
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
 
  %cmd_out = &cat_proc_drop_list(\%command_data, \%cmd_out);


  return %cmd_out;
}


sub cat_proc_drop_list{
  my %meta = %{$_[0]};
  my %cmd_out = %{$_[1]};
  my @data = @{$meta{"data"}};

  foreach my $line (@data){
    my @ss = split(": ", $line);
    chomp($line);
    $cmd_out{"cat_proc_drop_list"}{$ss[0]}{$meta{LocalBeginTime}} = $ss[1];
  }


  return %cmd_out;
}

1;
