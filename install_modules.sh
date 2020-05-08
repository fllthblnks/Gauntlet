echo 'This will install the required modules for Gauntlet server on your computer.'
echo 'The script will request your sudo password to install the scripts globally.'
sudo cpan -I HTTP::Server::Simple::CGI
sudo cpan -I POSIX
sudo cpan -I IO::Socket::INET
sudo cpan -I IO::Select
sudo cpan -I Time::HiRes
sudo cpan -I IO::Handle
sudo cpan -I Gauntlet::Messaging
sudo cpan -I Config

