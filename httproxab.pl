#!/usr/bin/perl
#  Simple HTTP Proxy Program using HTTP::Daemon.
#  (c) 2007 by Takaki Makino  http://www.snowelm.com/~t/

# JY - 2009 v2.0

use strict;

use HTTP::Daemon;
use HTTP::Headers;
use LWP::UserAgent;
use Time::HiRes;

my ($xabqueue, $xabcon, $xabdump, $response, $there, $code, $msg, $header, $content, $type, $timeout, $waittime);
our ($seq);

# XAB queue file
$xabqueue = "queue.txt";

# XAB queue content type file
$xabcon = "queuecon.txt";

# XAB dump location
$xabdump = "/var/www/www.attacker.xab/html/dump/";

# Timeout value to wait for a request in seconds
$timeout = "20";

my $d = HTTP::Daemon->new( 
	LocalHost => "192.168.209.129",  # remove this to listen from other machines 
				   # (i.e. open-relay... be careful of spammers!)
	LocalPort => 8293
) || die;
print localtime(time) . " - Listening on ", $d->url, "\n";

# Avoid dying from browser cancel
$SIG{PIPE} = 'IGNORE';

# Dirty pre-fork implementation
fork(); fork(); fork();  # 2^3 = 8 processes

while (my $c = $d->accept) {
	while (my $r = $c->get_request) {

		# add the request to the xab queue file
		addxabqueue($r->method,$r->uri->as_string,"$xabqueue");
		print localtime() . " - " . $r->uri->as_string . " - added to queue, request id $seq\n";

		#$r->push_header( Via => "1.1 ". $c->sockhost );
		#$response = "HTTP/1.1 200 OK\r\nConnection: Close\r\n";
	
		# continuously loop to see if the file is there	
		print localtime() . " - " . $r->uri->as_string . " - waiting for retrieval of $xabdump$seq.seg";

		# do not buffer stdout
		$| = 1;
		$there = 0;
		$waittime = 0;
		while($there == 0 && $waittime <= $timeout) {	
			sleep 1;
			$waittime++;
			print ".";
			if (-f "$xabdump$seq.seg") {
				$there = 1;
				open(F, "$xabdump$seq.seg") or warn "Can't open $xabdump/$seq.seg, therefore the response will fail\n";
				while (<F>) {
					$content .= $_;
				}
				close F;
				#$content = "$xabdump$seq.seg";
			}
		}

		if ($there == 0) {
			print "We could not find $xabdump/$seq.seg in $timeout seconds, not sending anything\n";
			last;
		}

		# if we get here, we found the file
		print "\n" . localtime() . " - " . $r->uri->as_string . " - found $xabdump$seq.seg\n";

		# Set content-type here
		$type = "text/html";
		open(T, "$xabcon") or debug ("Can't open queue content type file $xabcon $!");
		while(<T>) {
			if ($_ =~ /^(\d+),(\S+)$/) {
				if ($1 == $seq) {
					$type = "$2";
					print "type is $type\n";
				}
			}
		}

					print "type is $type 2\n";
		# Originally used file to determine the content type.  Now we just store it in queuecon
		#open(T, "file $xabdump$seq.seg|") or debug ("Can't file $xabdump$seq.seg $!");
		#$_ = <T>;
		#SWITCH: {
			#/png/i && do { $type = "image/png"; last SWITCH; };
			#/jpeg/i && do { $type = "image/jpeg"; last SWITCH; };
			#/gif/i && do { $type = "image/gif"; last SWITCH; };
			#/flash/i && do { $type = "application/x-shockwave-flash"; last SWITCH; };
			#/ASCII assembler program text/i && do { $type = "text/css"; last SWITCH; };
			#/exported SGML document text/i && do { $type = "text/javascript"; last SWITCH; };
			#/ASCII C\+\+ program text/i && do { $type = "text/javascript"; last SWITCH; };
			#/text/i && do { $type = "text/html"; last SWITCH; };
		#};
		#close T;

		# lets build the request
		$code = "200";
		$msg = "";
		$header = new HTTP::Headers Content_Type => "$type",
		$response = HTTP::Response->new( $code, $msg, $header, $content );
		
		# send the file
		$c->send_response( $response );
		
		#$c->send_file_response( $response );
		print localtime() . " - " . $r->uri->as_string . " - sent $xabdump$seq.seg\n";
		$content = "";
	}

	# close up the request
	$c->close;
	undef($c);
}

sub addxabqueue {
	my ($meth, $url, $q) = @_;
	open(FILE, '>>', "$q") or die "Can't open: $!\n";
	$seq = Time::HiRes::time();
	$seq =~ s/\.//g;
	print FILE "$seq,$meth,$url\n";
	close FILE;
}

