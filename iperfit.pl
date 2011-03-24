#!/usr/bin/perl -w
#
# iperfit.pl
#
# Nicolas Hennion (aka) Nicolargo
#
# Test de la performance d'un réseau en utilisant IPerf.
# Ce script permet de lancer simplement un Iperf entre deux machines.
# Il faut que le SSH soit possible entre ces deux machines.
# Il faut bien sur avoir Iperf installé sur son système.
#
#---------------------------------------------------------------------------------------------------------------------------------
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor Boston, MA 02110-1301,  USA
#---------------------------------------------------------------------------------------------------------------------------------
my $program_name = "IperfiT.pl";
my $program_version =  "0.1";

# Libraries
use Getopt::Std;
use Data::Dumper;
use POSIX qw ( strftime );
use Net::IPv4Addr qw( :all );
use Net::Ping;
use strict;

# Global variable
my $ssh_cmd = "/usr/bin/ssh";
my $iperf_server_cmd = "/usr/bin/iperf -s";
my $iperf_client_cmd = "/usr/bin/iperf -c";
my $kill_cmd = "/usr/bin/killall";
my $server_ip;
my $server_user;
my $iperf_udp = 0;
my $iperf_bandwidth = 1024;
my $iperf_time = 30;
my $iperf_mss = 1400;
my $iperf_wsize = 128;
my $iperf_bsize = 8000;
my $iperf_tos = 0x00;
my $quiet = 0;	# Quit mode default is OFF
my $result;

# Functions
#-----------------

# printmsg
# Print a message ($_[0]) on the console only if the quiet tag is NOT set
sub printmsg {
	my ($msg) = @_;
    if (!$quiet) {
        print "[$program_name] $msg";
    }
}

# Main program
#-------------------------

# Programs argument management
my %opts = ();
getopts("hvqs:n:ub:t:m:w:l:d:", \%opts);
if ($opts{v}) {
    # Display the version
    print "$program_name $program_version\n";
    exit(-1);
}

if ($opts{h} || !$opts{s} || !$opts{u}) {
    # Help
    print "$program_name $program_version\n";
    print "usage: ", $program_name," [options]\n";
    print " -h: Print the command line help\n";
    print " -v: Print the program version\n";
    print " -q: Quiet mode (no display)\n";
    print " -s <ip>: Server IP address\n";
    print " -n <user>: SSH user name used to connect to the server\n";
    print " -u: Use UDP protocol (default is TCP)\n";
    print " -b: Target bitrate for UDP flow\n";    
    print " -t <time>: Test duration, default is $iperf_time sec\n";    
    print " -m <mss>: Set the TCP Maximum Segment Size (MTU-40), default $iperf_mss bytes\n";
    print " -w <wsize>: Set the TCP Window Size, default $iperf_wsize Kbytes\n";
    print " -l <bsize>: Set the R/W Buffer Size, default $iperf_bsize bytes\n";    
    print " -d <tos>: Set the TOS field (Diffserv), default is $iperf_tos\n";    
    exit (-1);
}

if ($opts{q}) {
	# Quiet mode is ON
    $quiet = 1;
}

# Server
if ($opts{s}) {
	$server_ip = $opts{s};
}

# SSH User
if ($opts{n}) {
	$server_user = $opts{n};
}

# UDP
if ($opts{n}) {
	$iperf_udp = 1;
}

# UDP target bandwidth
if ($opts{b}) {
	$iperf_bandwidth = $opts{b};
}

# Time
if ($opts{t}) {
	$iperf_time = $opts{t};
}

# MSS: TCP Maximum Segment Size
if ($opts{m}) {
	$iperf_mss = $opts{m};
}

# TCP Windows Size
if ($opts{w}) {
	$iperf_wsize = $opts{w};
}

# R/W Buffer Size
if ($opts{l}) {
	$iperf_bsize = $opts{l};
}

# TOS
if ($opts{d}) {
	$iperf_tos = $opts{d};
}

# Test if server is reachable (using ICMP)
my $server_ping = Net::Ping->new();
if ($server_ping->ping($server_ip)) {
	printmsg "Server $server_ip is reachable\n";
} else {
	printmsg "Server $server_ip is not reachable\n";
	exit(1);
}

# Run the Iperf server (using SSH)
my $ssh_cmd_iperf_server_start = "$ssh_cmd -f $server_user\@$server_ip $iperf_server_cmd -M $iperf_mss -l $iperf_bsize -S $iperf_tos -w $iperf_wsize"."k";
$ssh_cmd_iperf_server_start .= $iperf_udp?" -u":"";
printmsg "Start the Iperf server\n";
printmsg $ssh_cmd_iperf_server_start."\n";
$result = system($ssh_cmd_iperf_server_start);
if ($result != 0) {
	print "Error $result while executing the latest command\n";
	exit(2);
}
printmsg "Server is started\n";
sleep(3);

# Run the client
printmsg "Start the Iperf client\n";
my $ssh_cmd_iperf_client_start = "$iperf_client_cmd $server_ip -t $iperf_time -M $iperf_mss -l $iperf_bsize -S $iperf_tos -w $iperf_wsize"."k";
$ssh_cmd_iperf_client_start .= $iperf_udp?" -u -b $iperf_bandwidth"."k":"";
$ssh_cmd_iperf_client_start .= " > /dev/null 2>&1";
printmsg $ssh_cmd_iperf_client_start."\n";
$result = system($ssh_cmd_iperf_client_start);
if ($result != 0) {
	print "Error $result while executing the latest command\n";
	exit(2);
}
printmsg "Test is finished\n";

# Stop the Iperf server (using SSH)
printmsg "Stop the Iperf server\n";
my $ssh_cmd_iperf_server_stop = "$ssh_cmd -f labo\@$server_ip $kill_cmd -9 iperf";
printmsg $ssh_cmd_iperf_server_stop."\n";
$result = system($ssh_cmd_iperf_server_stop);
if ($result != 0) {
	print "Error $result while executing the latest $server_ip\n";
	exit(2);
}

# The end
printmsg("The end...\n");
exit(0);
