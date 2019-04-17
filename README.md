# XAB - Cross Site Scripting Anonymous Browser #
Cross Site Scripting Anonymous Browser (XAB) leverages sites vulnerable to XSS and client browsers to build a network of drones. It does not replace the current anonymous browsing proxies, but provides an alternative that does not require willing participants. XAB is released as a proof of concept and as a jumping point for further research in the area of Cross Site Scripting in 2009.

The tool and research behind it was presented at Blackhat and DEF CON in 2009 by Jeff Yestrumskas and Matt Flick.

### xabattacker.pl  ###
The meat of XAB

### httproxab.pl  ###
Modified version of Takaki Makino's Simple HTTP Proxy

### cdproxy.pl  ###
Modified version of cross domain proxy by Bart Van der Donck.  This solves the same-origin problem within browsers.  However, now that CORS is a thing, a cross domain proxy may not be needed in all cases.

Author
-------------
Jeff Yestrumskas, Matt Flick

LICENSE
-------------
GPL v3
