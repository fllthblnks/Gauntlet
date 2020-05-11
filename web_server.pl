#!/usr/bin/perl
my $version = "1.10.1";

 {
 package MyWebServer;
 require Gauntlet::AirRecProc;
 require Gauntlet::AirRecAPProc;
 require Gauntlet::DataStruct;
 use HTTP::Server::Simple::CGI;
 use base qw(HTTP::Server::Simple::CGI);

 
 my %dispatch = (
     '/display'    => \&resp_display,
     '/host'	   => \&resp_host,
     '/start_test' => \&start_test,
     '/update'     => \&update,
     '/ap_info'    => \&resp_apinfo
);

my %test_values = ( IPERFTCP => "IPERF TCP",
		    IPERFUDP => "IPERF UDP",
		    FTP	     => "FTP" );

my $zeros = 0;
 
sub handle_request {
  my $self    = shift;
  my $cgi     = shift;
  my $path    = $cgi->path_info();
  my $handler = $dispatch{$path};
 
  if (ref($handler) eq "CODE") {
   # print "HTTP/1.0 200 OK\r\n";
    $handler->($cgi);
         
  } else {

    # Prints the frontpage
   
    &print_header();
    
    opendir(DIR, './speed_data_files/');
     
    print "<div style=\"width: 100%; overflow: hidden;\"><div style=\"float: left;\">";

    print "GAUNTLET: A test which you might not survive. v$version<br><br>";

    print 'Written by Guillaume Germain<br><br><br>';

    print '<font color="fushcia">300M</font> denotes a speed (in this case 300Mbps)<br>';
    
    print '<font color="aqua">300M</font> denotes a quantity of data (in this case 300 MB)';
 
    # Currently unsupported. Use the command-line tool to start tests

    #print "You can start a test and specify the arguments below:<br>";
    #print '<form method="get" action="start_test"><br><br>';
    #print '<table border=0 cellspacing=1 cellpadding=0>';
    #print '<tr><td>Subnet to scan:&nbsp;&nbsp;</td><td><input type="text" name="subnet"></td><td><font size=-1>Ex: 192.168.0.2-254</font></td></tr>';
    #print '<tr><td>Test Type:&nbsp;&nbsp;</td>';
    #print '<td><select name="test_type">';
    #foreach my $val (keys %test_values){
    #  print "<option value=\"" . $val . "\">" . $test_values{$val} . "</option>";
    #}
    #print '</select></td></tr>';
    #print '<tr><td>Test Parameter:&nbsp;&nbsp;</td><td><input type=text name="test_param"></td><td><font size=-1>IPERF TCP: Windows size (Ex: 1M or 512k...)<br>IPERF UDP: Bandwidth (Ex: 1M or 512k)<br>FTP: File to fetch (Ex: ftp://192.168.1.1/file.txt)</font></tr>';
    #print '<tr><td colspan=2><center><input type=submit value="START TEST"></center></td></tr>';
    #print '</table></form>';
    print "</div>";
    

    print "<div style=\"float: right;\"><font size=-2>";
    print "<font color=green><a href=\"./display\">LATEST or CURRENT TEST</a></font><br><table border=0 cellspacing=1 cellpadding=0>";
    print "<tr><td>Timestamp</td><td>TestType</td><td>AP Configuration</td></tr>";
    foreach my $file (reverse sort readdir(DIR)){
      if($file !~ /\.spdata/){ next; }
      print &fileInfoLine($file);
    }
    closedir(DIR);
    print "</table></div></div>";

    $cgi->end_html;

  }




}

sub start_test{
   my $cgi  = shift;   # CGI.pm object
   return if !ref $cgi;

   &print_header();

   my @values = ("subnet", "test_type", "test_param", "test_type", "ap_config");

   print "Starting test with the following parameters:<br><br>";
   print "Subnet to scan: " . $cgi->param("subnet") . "<br>";
   print "Test type: " . $cgi->param("test_type") . "<br>";
   print "Test Parameter: " . $cgi->param("test_param") . "<br>"; 

   system("perl run_test.pl " . $cgi->param("subnet") . " " .
				$cgi->param("test_type") . " " .
				$cgi->param("test_param") . " " .
				$cgi->param("ap_config") . " &");
   
   $cgi->end_html;

}


sub resp_apinfo{
  my $cgi  = shift;   # CGI.pm object
  return if !ref $cgi;
  my $out;

  my $dataStruct = Gauntlet::DataStruct->new("./speed_data_files/" . $cgi->param("file"));
 #my $airrec     = Gauntlet::AirRecProc->new("./airrec_logs/" . $dataStruct->getHeader()->{start_time} . "-controller.log-00.log");
  my $ap_info    = Gauntlet::AirRecAPProc->new("./airrec_logs/" . $dataStruct->getHeader()->{start_time} . "-ap.log-00.log");


  &print_header();

  $out .= '<a href="./display?file=' . $cgi->param("file") . '">TEST RESULTS</a><br>';
 
  $out .= "<table border=1 cellspacing=0 cellpadding=2><tr><td>TIME</td><td>SPEED</td>";
  
  foreach my $ar ($ap_info->getArgumentList()){
    $out .= '<td width="70">' . $ar . '&nbsp;</td>';
  }



  foreach my $time_val (sort { $a <=> $b } $dataStruct->getTimeList){
    $out .= "<tr><td>" . $time_val . "_sec&nbsp;</td><td>" . &frmtSpeed($dataStruct->speedHostTime("aggregate", $time_val)) . "</td>";
    
    foreach my $ar ($ap_info->getArgumentList()){
      $out .= "<td>" . $ap_info->getDataByTime($ar, $dataStruct->getAvgHiResTime($time_val)) . "</td>\n";
    }

    $out .= "</tr>\n";
  }

  $out .= '</tr></table>';

  print $out, $cgi->end_html;


}

sub update {
  my $cgi = shift;
 
  print "HTTP/1.0 200 OK\r\n"; 
  print "Content-type: text/plain\n";
  
  print "HELLO";
}
 
sub resp_display {
   my $cgi  = shift;   # CGI.pm object
   return if !ref $cgi;
  
   &print_header(); 

   my $filename, $out;

   if(defined($cgi->param('file'))){ $filename = "./speed_data_files/" . $cgi->param('file'); }
   else{  my @filelist = `ls -t ./speed_data_files/*.spdata`; $filename = $filelist[0]; }

   $filename =~ s/\.\/speed\_data\_files\///; 
   
   my $dataStruct = Gauntlet::DataStruct->new("./speed_data_files/" . $filename);
   

   # Display Header
   $out = '<font size="-3">';
   $out .= "Test type: " . $dataStruct->getHeader()->{test_type} . "&nbsp;&nbsp;<a href=\"./ap_info?file=" . $filename . "\">AP CONSOLE INFO</a><br>\n";
   $out .= "<table border=0 cellspacing=1 cellpadding=0>\n";
   $out .= "<tr><td>SEC</td>";
   
   # Display Host List
   foreach my $host (sort { $a cmp $b } $dataStruct->getHostList()){
     $host =~ /(......)$/;
     $out .= '<td><a href="./host?file=' . $filename . '&host_ip=' . $host . '">' . $1 . "</a>&nbsp;</td>";
   }
  

   $out .= "<td>TOTAL</td><font color=\"aqua\"><td>AVG</td><td>&sigma;</td></tr>\n";


  # Display results for each time slice, including individual and total results
  #
  my @times = keys %{$dataStruct->getTimeList};

  foreach my $time_val (sort { $a <=> $b } @times){
    $out .= "<tr><td>" . $time_val . "_sec&nbsp;</td>"; 
    foreach my $host (sort { $a cmp $b } $dataStruct->getHostList()){
      
      $out .= "<td>" . &frmtSpeedColor($dataStruct->speedHostTime($host, $time_val)) . "&nbsp;</td>\n"; 
    }
    $out .= "<td><font color=\"fushcia\">" . &frmtSpeed($dataStruct->speedHostTime("aggregate", $time_val)) . "&nbsp;</td>\n";
    $out .= "<td><font color=\"fushcia\">" . &frmtSpeed($dataStruct->speedHostTime("aggregate", $time_val) / $dataStruct->getHostCount()) . "&nbsp;</td>\n"; 
    $out .= "<td><font color=\"fushcia\">" . &frmtSpeed($dataStruct->getStdrDerivByTime($time_val)) . "&nbsp;</td>\n";
    $out .= "</tr>\n";
  }

  $out .= "<tr><td>AVG</td>";

  ### Display Speed Avg for each host
  foreach my $hst (sort { $a cmp $b } $dataStruct->getHostList()){
    $out .= "<td><font color=\"fushcia\">" . &frmtSpeed($dataStruct->getSpeedAvg($hst)) . "</font></td>";
  } 
  $out .= "<td><font color=\"fushcia\">" . &frmtSpeed($dataStruct->getSpeedAvg("TOTAL")) . "</font></td>";
  $out .= "<td><font color=\"fushcia\">" . &frmtSpeed($dataStruct->getStdrDerivTotalAvg()) . "</font></td></tr>";
 
  $out .= "<tr><td>&sigma;</td>";
  ### Display standard derivation
  foreach my $hst (sort { $a cmp $b } $dataStruct->getHostList()){
    $out .= "<td><font color=\"fushcia\">" . &frmtSpeed($dataStruct->getStdrDerivByHost($hst)) . "</font></td>";
  }
  $out .= '</font>';
  $out .= "</tr><tr><td>DATA</td>";

  #### DATA SENT
  #

  foreach my $hst (sort { $a cmp $b } $dataStruct->getHostList()){

    $out .= "<td><font color=\"aqua\">" . &frmtSpeed($dataStruct->getHostTotal($hst)) . "</font></td>";
  }

  $out .= "<td><font color=\"aqua\">" . &frmtSpeed($dataStruct->getTotalData()) . "</font></td>";

  $out .= "<td>&nbsp;</td></tr></font></table>";

 
  print $out,
        $cgi->end_html;


 }





 # Function to print specific host information
 # 
 #
 sub resp_host(){
   my $cgi  = shift;   # CGI.pm object
   return if !ref $cgi;

   &print_header();

   my $host_ip    = $cgi->param("host_ip");
   my $dataStruct = Gauntlet::DataStruct->new("./speed_data_files/" . $cgi->param("file"));
   my $airrec     = Gauntlet::AirRecProc->new("./airrec_logs/" . $dataStruct->getHeader()->{start_time} . "-controller.log-00.log");
  
   print "<br><br>";
   print "<table border=0 cellspacing=0 cellpadding=0>";
   print "<tr><td>Sec</td><td>Speed</td><td><font size=-3 face=consolas><pre>";
   
   print $airrec->getHeader("show_ap_debug_client_table");
   print "</pre></font></td></tr>";
   
   # Prints each information line

   my @times = keys %{$dataStruct->getTimeList};

   foreach my $time_val (sort @times){
	   print "<tr><td>" . $time_val . "_sec&nbsp;</td><td>" . &frmtSpeed($dataStruct->speedHostTime($host_ip, $time_val)) . "&nbsp;</td>";
	   print "<td><font size=-3 face=consolas><pre>" . $airrec->getDebugClientTableByTime($host_ip, $dataStruct->getHiResTime($host_ip, $time_val)) . "</pre></font></td></tr>";
   }
 }


# Formats the incoming data in the appropriate unit
sub frmtSpeed(){
	my $dt = $_[0];

	if($dt == 0){ 		return 0; }
	elsif($dt < 0){		return $dt; }
	elsif($dt < 999){ 		return sprintf("%.0f", $dt) . "B"; }
	elsif($dt < 999999){ 		return sprintf("%.0f", ($dt / 1024)) . "K"; }
	elsif($dt < 999999999){ 	return sprintf("%.1f", (($dt / 1024) / 1024)) . "M"; }
	elsif($dt < 999999999999){ 	return sprintf("%.1f", ((($dt / 1024) / 1024) / 1024)) . "G"; }

}

# Format the data with a specific color
sub frmtSpeedColor(){
	my $d = $_[0];

	if($d eq "N/A"){		return "<font color=grey>N/A</font>"; }
	if($d <= -1){               return "<font color=purple>DONE</font>"; }
	if($d == 0){                return "<font color=red>0</font>"; $zeros++; }
	elsif($d < 999999){         return '<font color="yellow">' . &frmtSpeed($d) . '</font>'; }
	elsif($d > 5242879){        return '<font color="green">' .  &frmtSpeed($d) . '</font>'; }
	else{                       return '<font>' .                &frmtSpeed($d) . '</font>'; }
}

# Fetches the information for a specific file and prints the information after it being formated
# This function is used to build the file list menu on the frontpage
sub fileInfoLine(){
	my $filename = shift;
	my $date = $filename;
	my $test_type;
	open(FIC, "./speed_data_files/$filename");
	my $header = <FIC>;
	close(FIC);

	my @shft = split(",", $header);

	$date =~ s/.spdata//;

	if($shft[4] =~ /IPERF/){ $test_type = $shft[4] . " " . $shft[5]; }else{ $test_type = $shft[4]; }

	return '<tr><td><a href="./display?file=' . $filename . '">' . $date . "</a>&nbsp;&nbsp;</td><td>" . $test_type . "&nbsp;&nbsp;</td><td>" . $shft[3] . "&nbsp;&nbsp;</td></tr>";
}

# Print HTML header
sub print_header(){
	my $refresh = shift;

	my $out = <<EOF;
	HTTP/1.0 200 OK\r\n
		<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN""http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
		<html>
		<head>
		<script>
		\$('#hoverMe').hover(function () {
				\$('#tooltip').fadeIn();
				}, function () {
				\$('#tooltip').fadeOut();
				});
	</script>
		<title>Gauntlet</title>
		<meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1" />
EOF


		if($refesh ne "autoupdate"){ #$out .= '<META HTTP-EQUIV="refresh" CONTENT="1">';
		}

	$out .= <<EOF;
	</head>
		<body link="#F5821F" vlink="#F5821F" alink="yellow" bgcolor="black" text="white">
		<font face="arial">
EOF

		print $out;
#return $out;
}
} 

# start the server on port 8081
my $pid = MyWebServer->new(8081)->background();
print "Gauntlet v$version web server running.\n\nUse './stop_webserver.sh' to stop server.\n";
open(PID, '>.webserver.pid');
print PID $pid;
close(PID);
