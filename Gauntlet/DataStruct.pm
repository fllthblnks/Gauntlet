package Gauntlet::DataStruct;
use strict;
require Math::Complex;
use Math::Round qw(round_even);
use POSIX;

sub new{
  my $class = shift;
  my $self = { file => shift };
  my %header;

  open(FIC, $self->{file}) or warn "CANT OPEN FILE " . $self->{file} . "\n";
  my @file_header = split(",", <FIC>);

   #HEADER,TIME,TEST_TYPE,AP_PARAM,IPERF_PARAM,VERSION

  $header{start_time} = $file_header[1];
  $header{ap_param}   = $file_header[3];
  if($file_header[3] =~ /IPERF/){
    $header{test_type} = $file_header[3] . " " . $file_header[4];
    $header{version}   = $file_header[5];
  }else{
    $header{test_type} = $file_header[3];
    $header{version}   = $file_header[4];
  }

  #1480631039.74227,192.168.1.54,DATA_CLIENT,1480631040.13675,1174328
  my (%tmpSpeed, %tmpData, $tmpTotal, %tmpTime);
  foreach my $line (<FIC>){
    my @splt = split(",", $line);
    if($splt[2] =~ "DATA"){

      my $tm;

      if(defined($tmpSpeed{floor($splt[0])}{$splt[1]})){
	      $tm = ceil($splt[0]);
      }else{
	      $tm = floor($splt[0]);
      }

      $tmpSpeed{$tm}{$splt[1]}     = $splt[4] * 8;
      $tmpTime{$tm}{$splt[1]}      = $splt[0];
      $tmpSpeed{$tm}{"aggregate"} += $splt[4] * 8;
      $tmpData{$splt[1]}               += $splt[4];
      $tmpTotal                        += $splt[4];

    }
  }

  my %avgSpeed;
  my $totalSpeedAvg;
  my $sec_count;
  my $total_speed_total = 0;

  foreach my $hst (keys %tmpData){
    $sec_count = 0;
    my $speed_total = 0;
    foreach my $time (keys %tmpSpeed){
      $speed_total += $tmpSpeed{$time}{$hst};
      $sec_count++;
      $total_speed_total += $tmpSpeed{$time}{$hst};
    }

    $avgSpeed{$hst} = $speed_total / $sec_count;
  }

  

  close(FIC);


  $self->{speed}      = \%tmpSpeed;
  $self->{data}       = \%tmpData;
  $self->{total_data} = $tmpTotal;
  $self->{header}     = \%header;
  $self->{time}       = \%tmpTime;
  $self->{host_count} = keys %tmpData;
  $self->{avg_host_speed} = \%avgSpeed;
  if($sec_count == 0){ $self->{total_speed_average} = 0; }
  else{                $self->{total_speed_average} = $total_speed_total / $sec_count; }

  bless $self, $class;
  return $self;
}

sub getHeader{
  my ($self) = @_;
  return $self->{header};
}

sub speedHostTime{
  my ($self, $host, $time) = @_;
  if(!defined($self->{speed}->{$time}{$host})){    return "N/A"; }
  if(         $self->{speed}->{$time}{$host} < 0){ return 0;     }

  return $self->{speed}->{$time}{$host};
}

sub getHostCount{
  my ($self) = @_;

  return $self->{host_count};
}

sub getHostList{
  my ($self) = @_;
  return keys(%{$self->{data}});
}

sub getHostTotal{
  my ($self, $host) = @_;
  if($self->{data}{$host} < 0){ return 0; }
  return $self->{data}{$host};
}

sub getTimeList{
  my ($self) = @_;
 
  return $self->{speed};
}

sub getHiResTime{
  my ($self, $host, $time) = @_;
  return $self->{time}->{$time}{$host};
}

sub getAvgHiResTime{
  my ($self, $time) = @_;

  my $sum = 0;
  my $host_number = 0;
  foreach my $host (keys %{$self->{time}->{$time}}){
    $sum += $self->{time}->{$time}{$host};
    $host_number++;
  }

  return $sum / $host_number;
}

sub getHostInfo{
  my ($self) = @_;

  my %out;

  $out{mac} = "";
  
}

sub getSpeedAvg{
  my ($self, $host) = @_;

  if($host eq "TOTAL"){
    return $self->{total_speed_average};
  }else{
    if($self->{avg_host_speed}->{$host} < 0){ return 0; }
    return $self->{avg_host_speed}->{$host};
  }
}

sub getHostDataSent{
  my ($self, $host) = @_;
  return $self->{total_data}->{$host};
}

sub getStdrDerivByHost{
  my ($self, $host) = @_;

  my $sec_count = 0;
  my $mean_total = 0;

  if($self->{avg_host_speed}->{$host} < 0){ return 0; }

  foreach my $time (keys %{$self->{speed}}){
    $sec_count++;
    my $tmp_x = $self->{speed}->{$time}{$host} - $self->{avg_host_speed}->{$host};
    $mean_total += $tmp_x * $tmp_x; 
    
  }

  return sqrt($mean_total / $sec_count);
}

sub getStdrDerivByTime{
  my ($self, $time) = @_;

  my $host_count = 0;
  my $mean_total = 0;


  foreach my $host (keys %{$self->{data}}){
    my $tmp_x = $self->{speed}->{$time}{$host} - $self->{speed}->{$time}{"aggregate"} / $self->{host_count};
    $mean_total += $tmp_x * $tmp_x;
  }
  
  if((sqrt($mean_total / $self->{host_count})) < 1){ return 0; }
  return sqrt($mean_total / $self->{host_count});
}

sub getStdrDerivTotalAvg{
  my ($self) = @_;

  my $mean_total;

  foreach my $host (keys %{$self->{data}}){
    my $tmp_x = $self->{avg_host_speed}->{$host} - $self->{total_speed_average} / $self->{host_count};
    $mean_total += $tmp_x * $tmp_x;
  }
  
  if($self->{host_count} == 0){ return 0; }
  return sqrt($mean_total / $self->{host_count});
}

sub getTotalData{
  my ($self) = @_;

  return $self->{total_data}; 
}

1;
