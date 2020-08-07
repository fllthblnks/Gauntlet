#!/usr/bin/perl

use Parse::CSV;


`unzip -o $ARGV[0]`;

my $output_filename = $ARGV[1];

my %data;


$filename =  'ixchariot_mix_application_user.csv';



use Text::CSV;
 
my @rows;
# Read/parse CSV
my $csv = Text::CSV->new ({ binary => 1, auto_diag => 1 });

open my $fh, "<:encoding(utf8)", $filename or die "$filename: $!";

while (my $row = $csv->getline ($fh)) {
    if($row->[6] eq 'N/A'){ $s[6] = 0; }

    

    $data{($row->[0] / 1000)}{$row->[5]} += $row->[6] / 8;
    $data{($row->[0] / 1000) - 1}{$row->[5]} += $row->[6] / 8;
}


open(OUT, ">./speed_data_files/$output_filename.spdata");

print OUT "HEADER,$ARGV[1],1500000,Converted_Chariot,Chariot,1M,,1.10.1\n";

for my $time (keys %data){
    for my $device (keys %{$data{$time}}){
        if($device eq 'Destination IP'){ next; }
        print OUT $time . ',' . $device . ',DATA_CLIENT,' . $time . ',' . $data{$time}{$device} . "\n";
    }
}

close(OUT);
close(FIC);
