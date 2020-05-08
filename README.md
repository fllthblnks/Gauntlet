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
