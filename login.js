    /* (c) 2007 Benjamin Crowell, GPL v 2 or later */
    /*------------------------------------------------------------------------------------------------------------
       login stuff
       -----------
       The main point of checking all this login stuff is so that we can report the student's activity from the
       script. The nature of the qualitative questions is such that the student can always end up getting the
       answer by trial and error; however, it can be useful to record whether the student is even bothering to
       do them. The student can also always read the JS code and see how the question is written, so there
       really aren't any secrets here.

       A secondary purpose of checking the login stuff is that I might have some resources that are expensive
       to serve up, e.g., video. Users who aren't logged in could, for instance, be served a lower-resolution
       version, or sent to a mirror on you-tube, or whatever, in order to save on bandwidth. (Well designed bots
       presumably wouldn't request video data anyway, but poorly designed or malicious ones might.)

       We do not actually have enough data on the client side to check whether the login is valid. However,
       we can send back the authorization code, and the server can check that.

       The login cookie consists of username, caret, date, caret, sha1_base64 hash as defined in Login.pm.
       The carets are encoded in the cookie string as %5E, and the colons in the date as %3A, space as %20. Some %-style escape
       sequences may also occur in the hash: %2B for +, and %2F for /.

       User is set to a null string if they're not logged in.
    ------------------------------------------------------------------------------------------------------------- */
    function get_login_info() {
      var user = "";
      var date = "";
      var auth = "";
      var login_cookie = /spotter_login=([\w\_\+\.\-\'\,\:\ ]+)\%5E([\w\_\+\.\-\'\,\:\ \%]+)\%5E([a-zA-Z0-9\%]{27,})/.exec(document.cookie);
        /* auth may be longer than 27 because of escape sequences */
        /* there may be other cookies from the same site that come before or after this one; we won't inadvertently eat part of the next cookie in this
           match, because the semicolon delimiter won't match this regex */
      if (login_cookie) {
        user = remove_escapes_from_cookie_string(login_cookie[1]);
        date = remove_escapes_from_cookie_string(login_cookie[2]); /* e.g., 2007-02-16 15:11:49 */
        auth = remove_escapes_from_cookie_string(login_cookie[3]);
        if (auth.length!=27) {auth=""}
      }
      var login = new Array(3);
      login[0] = user;
      login[1] = date;
      login[2] = auth;
      return login;
    }

    function remove_escapes_from_cookie_string(s) {
      s = s.replace(/%5E/g,'^');
      s = s.replace(/%3A/g,':');
      s = s.replace(/%20/g,' ');
      s = s.replace(/%2B/g,'+');
      s = s.replace(/%2F/g,'/');
      return s;
    }
    /* ------------------------------------------------------------------------------------------------------------- */
