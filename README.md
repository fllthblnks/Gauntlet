# Gauntlet

A test which you might not survive

## What does it do?

Gauntlet is a perl script that streamlines testing by automating discovery, test initiation and reporting of multi-client speed tests.

It leverages iperf as its main mode of operation but can also do FTP tests.

It can either be ran in client-mode (requires a client to be installed on the endpoints, supports Windows and macOS) or in iperf-lite mode (Just run iperf on the endpoints in server mode).

It uses nmap for the endpoint discovery, runs the test applications and then displays the test results using a web interface.

![Display Example](/sample.png)

## How to install it?

The server runs Linux or macOS and is currently unsupported under Windows.

Installation steps:
1. Install nmap 
1. Install the required modules using the ./install_modules.sh script
1. Edit the config.txt file

## How to run it?

To run in iperf-lite mode:
1. Start the reporting server with ./start_webserver.sh
1. Make sure the endpoints are reachable by the Gauntlet server
   1. If on WiFi, make sure they are associated and able to reach the server
1. Install and run iperf on the endpoints in server mode
   1. For a TCP test, use: iperf -s -i
   1. For a UDP test, use: iperf -s -u -i 1
1. Configure the config.txt
1. Start the test with perl run_the_gauntlet.pl -c

You can view the results on the webserver by visiting http://localhost:8081/

