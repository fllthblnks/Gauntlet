#!/usr/bin/perl
# Author: Guillaume Germain (ggermain@arubanetworks.com)
# Date: 2014/07/02
# Description: Checks the content of the database to ensure that the controller is running within the parameters

package Gauntlet::AirRec;

sub new{

  my $class = shift;
  my $self = { data => ""};
  open(FIC,"./logic.csv");

  my %check;

  close(FIC);
  
  $self->{data} = \%check;

  bless $self;
  return $self;
}

sub test_print{
  my ( $self ) = @_;

  my %data = %{$self->{data}};
 

  foreach my $key (keys(%data)){
    print $key . "\n";
  }

}


1;
