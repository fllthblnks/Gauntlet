package Gauntlet::DataStore;
use strict;

sub new{
  my $class = shift;
  my $self = { file => shift };
  my $FH;

  open($FH, '>' . $self->{file}) or warn "CANT OPEN FILE " . $self->{file} . "\n";

  $self->{FH} = \$FH;

  return $self;
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

