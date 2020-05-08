package Gauntlet::Messaging;
use strict;

sub new{
  my $class = shift;
  my $self = { file => shift };

  return $self;
}


sub decode_test_args{
  my $self = shift;
  my $received_data = shift;
  
  my %out;


  while($received_data =~ /^\</){
    $received_data =~ s/^\<([^>]+)\>([^<]+)<\/([^>]+)>//;
    $out{$1} = $2;
  }



  return %out;
}

sub encode_test_args{
  my $self = shift;
  my $h_ref = shift;
  my %data_to_send = %{$h_ref};
  my $line = "";

  foreach my $key (keys(%data_to_send)){
    $line .= "<" . $key . ">" . $data_to_send{$key} . "</" . $key . ">";
  } 

  return $line;
}

sub put{
  my $self = shift;
  my $data = shift;

  my $FH = $$self->{FH};

    
  
}


sub done{
  my $self = shift;

  my $FH = $$self->{FH}; 
  close($FH);
}

1;
