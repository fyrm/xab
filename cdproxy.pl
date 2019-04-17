#!/usr/bin/perl

# XABACD - 2009 v2.0

##########################################################################################
#                                                                                        #
# AJAX Cross Domain - ACD                                                                #
# ---------------------------------------------------------------------------------------#
# Full documentation see http://www.ajax-cross-domain.com/                               #
# ---------------------------------------------------------------------------------------#
# Copyright (c) 2007 Bart Van der Donck - http://www.dotinternet.be/                     #
# ---------------------------------------------------------------------------------------#
# For installation procedure, see http://www.ajax-cross-domain.com/#Installation         #
# ---------------------------------------------------------------------------------------#
# Permission to use, copy, modify, and distribute this include file and its              #
# documentation for any purpose without fee is granted provided that the above copyright #
# notice appears in all copies. This software is provided "as is" without any express    #
# or implied warranty.                                                                   #
#                                                                                        #
##########################################################################################


##########################################################################################
# Configuration area                                                                     #
##########################################################################################

# which query-strings are allowed to call this script ?
my @allowed_uris = (
                      'uri=.*',
                   );

# which timeout to use for the remote request (in seconds) ?
my $timeout = 30;

# which is the default request method when not specified (case sensitive) ?
my $method = 'GET';

# which is the default Content-Type to send when not specified ?
my $content_type = 'text/html';

# wat is the maximum size of the response in KB ?
my $maxsize = 10000;

# as which content-type should ACD.js be served ?
my $js_content_type = 'application/x-javascript';

# In which character set should ACD.js be served ?  e.g. 'UTF-8', 'ISO-8859-1', ...
# Set " my $charset = undef; " if you want to keep the character set of the remote
# resource
my $charset = undef;

# What is the default User-Agent header that is offerd to the remote resource ?
my $useragent = 'AJAX Cross Domain';

my $ct = "text/html";


##########################################################################################
# Load needed modules, those should be present in default Perl 5.6+ installations        #
##########################################################################################

use strict;
use warnings;
use CGI::Carp qw(fatalsToBrowser);
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Headers;
use MIME::Base64;
use subs 'format_output';


##########################################################################################
# Decide which remote resources we allow                                                 #
##########################################################################################

my $OKflag;
my $auth_failed = 'AJAX Cross Domain discovered that you cannot perform the remote request. The query-string after ACD.js must be set as an allowed query-string in the configuration area of ACD.js.';

# Check '&' versus '&amp;' versions
my $amp = $ENV{'QUERY_STRING'};
$amp =~s/&/&amp;/ig;
my $amp2 = $ENV{'QUERY_STRING'};
$amp2 =~s/&amp;/&/ig;

for (@allowed_uris)  {
	# Jeff Yestrumskas - changed the following to allow regexes for URls
  $OKflag = 1 if ($ENV{'QUERY_STRING'} =~ /^$_/ || $_ eq $amp || $_ eq $amp2);
}

if ($OKflag != 1)  {
  format_output($auth_failed, $auth_failed, $auth_failed, $auth_failed, $auth_failed);
}


##########################################################################################
# Parse the query-string                                                                 #
##########################################################################################

# Parse bracket separated parts
# -----------------------------

my $uri = $ENV{'QUERY_STRING'};
#$uri =~ s/(.*)(uri=\()(.*?)(\))(.*)/$3/ig;
$uri =~ s/uri=//g;

my $postdata = $ENV{'QUERY_STRING'};
$postdata =~ s/(.*)(postdata=\()(.*?)(\))(.*)/$3/ig;
$postdata = '' if $postdata eq $ENV{'QUERY_STRING'};

my $headers = $ENV{'QUERY_STRING'};
$headers =~ s/(.*)(headers=\()(.*?)(\))(.*)/$3/ig;
$headers = '' if $headers eq $ENV{'QUERY_STRING'};

for ($headers)  {
  tr/+/ /;
  s/%([A-Fa-f\d]{2})/chr hex $1/eg;
}


# Parse the remaining parts
# -------------------------

my %param;

my $rest = $ENV{'QUERY_STRING'};
for ($postdata, $uri, $headers)  {
  $rest =~ s/\Q$_//g if $_ ne '';
}

for (split/&/, $rest)  {
    my ($name, $value) = split /=/, $_;
    for ($name, $value)  {
      tr/+/ /;
      s/%([A-Fa-f\d]{2})/chr hex $1/eg;
    }
    $param{$name} = $value;
}

$method = uc $param{method} if defined $param{method};
$method = 'POST' if $postdata ne '';


##########################################################################################
# Escapes for left and right brackets inside $uri, $headers and $postdata                #
##########################################################################################

for ($uri, $headers, $postdata) {
  s/%28/(/g;
  s/%29/)/g;
  s/%2528/%28/g;
  s/%2529/%29/g;
}


###########################################################################################
# Split headers in name/value pairs                                                       #
###########################################################################################

my %add_header;
$add_header{'User-Agent'} = $useragent;

for (split /&/, $headers)  {
  my ($name, $value) = split /=/, $_;
  for ($name, $value)  {
    tr/+/ /;
    s/%([A-Fa-f\d]{2})/chr hex $1/eg;
  }
  $add_header{$name} = $value;
}

###########################################################################################
# Fire off the request                                                                    #
###########################################################################################

# General parameters of request
# -----------------------------

my $ua = new LWP::UserAgent;
$ua->max_size($maxsize * 1024);
$ua->timeout($timeout);
$ua->parse_head(undef);

# Perform request
# ---------------

my $req = HTTP::Request->new($method, $uri);
$req->content_type($content_type);
$req->header(%add_header);
$req->content($postdata);

# Receive response
# ----------------

my $res = $ua->request($req);

if ($res->is_success) {
  format_output($res->content, $res->as_string, $res->status_line, '', $req->as_string);
} 
else  {
  format_output($res->content, $res->as_string, $res->status_line, 'Request failed', $req->as_string);
}       


###########################################################################################
# Last possibility: if no content has been outputted yet, show error                      #
###########################################################################################

format_output($res->content, $res->as_string, $res->status_line, 'Unexpected error', $req->as_string);

  
###########################################################################################
# Output formatter                                                                        #
###########################################################################################

sub format_output  {

    # General regexes and headers
    # ---------------------------

    my @inp = @_;
    for (@inp)  {
      #s/\\/\\\\/g;
      #s/'/\\'/g;
      #s/\//\\\//g;
      #s/(\r\n|\r)/\n/g;
    }

    my ($responseText, $getAllResponseHeaders, $status, $error, $fullrequest) = @inp;
    $responseText = encode_base64($responseText);

    my $output = "Content-Type: $js_content_type\r\n\r\n";

    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{// INITIALIZATION\r\n};
    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{var ACD = new Object();\r\n\r\n\r\n};



    # What was the sent request ?
    # ---------------------------

    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{// ACD.request - FULL REQUEST THAT WAS SENT\r\n};
    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{ACD.request = '';\r\n};
    if (defined $fullrequest)  {
      for (split /\n/, $fullrequest)  {
        $output.=qq{ACD.request += '$_\\r\\n';\r\n};
      }
    }
    $output.=qq{\r\n\r\n};
    
    
    # What was the HTTP status code of the response ?
    # -----------------------------------------------

    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{// ACD.status - HTTP RESPONSE STATUS CODE\r\n};
    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{ACD.status = '$status';\r\n};
    $output.=qq{\r\n\r\n};


    # What are the headers of the response ?
    # --------------------------------------

    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{// ACD.getAllResponseHeaders - FULL HEADERS OF RESPONSE\r\n};
    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{ACD.getAllResponseHeaders = '';\r\n};

    my %getResponseHeader;
    my $spaces = 0;

    if (defined $getAllResponseHeaders)  {
      $getAllResponseHeaders = (split /\n\n/, $getAllResponseHeaders)[0];
      for (split /\n/, $getAllResponseHeaders)  {
        $output.=qq{ACD.getAllResponseHeaders += '$_\\r\\n';\r\n};
        my @key_property = split /: /, $_;
        if ($key_property[1] ne '')  {
          $getResponseHeader{$key_property[0]} = $key_property[1];
          $spaces = length($key_property[0]) if $spaces < length($key_property[0]);
        }
      }
      $output.=qq{\r\n\r\n};
      $output.=qq{// ----------------------------------------------------------------\r\n};
      $output.=qq{// ACD.getResponseHeader - METHOD WITH EVERY KEY/VALUE HEADER\r\n};
      $output.=qq{// ----------------------------------------------------------------\r\n};
      $output.=qq{ACD.getResponseHeader = {};\r\n};
      while ( my ($key, $val) = each %getResponseHeader)  {
        $output.=qq{ACD.getResponseHeader['$key'] } . ' ' x ($spaces - length($key)) . qq{= '$val';\r\n};
				if (uc $key eq 'CONTENT-TYPE') {
					$content_type = $val;
				}

        if (uc $key eq 'CONTENT-TYPE' && $val =~ /charset=/i && $charset eq undef)  {
          $charset = $val;
          $charset =~ s/(.*)(charset=)(.+)/$3/i;
        }
      }
    }

    $output.=qq{\r\n\r\n};
    $output =~ s/\Q$js_content_type/$js_content_type; charset=$charset/ if defined $charset;


    # What was the body of the response ?
    # -----------------------------------

    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{// ACD.responseText - BODY OF RESPONSE\r\n};
    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{ACD.responseText = '';\r\n};

    if (defined $responseText)  {
      for (split /\n/, $responseText)  {
        $output.=qq{ACD.responseText += '$_';\r\n};
      }
    }

		$ct = $content_type;
	  $ct =~ s/\//_/g;
  
    #$output.=qq{ACD.responseText += '&c=$content_type';\r\n};
    $output.=qq{\r\n\r\n};
    
    $output.=qq{var data=ACD.responseText;\r\n};
    $output.=qq{var datalen=data.length;\r\n};
    $output.=qq{var baseurllen=baseurl.length;\r\n};
    $output.=qq{var contenttype='$ct';\r\n};
		$output.=qq{sendData(data);\r\n};



    # Were there any errors ?
    # -----------------------

    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{// ACD.error - ERRORS\r\n};
    $output.=qq{// ----------------------------------------------------------------\r\n};
    $output.=qq{ACD.error = '$error';\r\n};
    $output.=qq{\r\n\r\n};


    # Output & end
    # ------------

    print $output;
    exit;
}


__END__
