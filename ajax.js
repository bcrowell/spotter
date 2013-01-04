    /* (c) 2007 Benjamin Crowell, GPL v 2 or later */
    /*------------------------------------------------------------------------------------------------------------
       communication back to the server
       --------------------------------
       A simple ajaxy thing to record when the student has attempted a problem.
       The url is relative, e.g., 'foo.cgi'.
    ------------------------------------------------------------------------------------------------------------- */
    function do_get_request(url) { 
      var xhr = null;
      try  { 
        xhr = new XMLHttpRequest(); 
      }
      catch(e) {
        try {
           xhr  = new ActiveXObject("Microsoft.XMLHTTP");
        }
        catch(e) {}
      }
      xhr.onreadystatechange  = function() {}; /* don't need the response */
      xhr.open("GET", url,  true); 
      xhr.send(null); 
    } 
