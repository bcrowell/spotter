function load_external_js(s) {
  // usage: load_external_js({src:"http://foo.com/bar.js",element:"head",type:"text/javascript"});
  //           ... defaults (the values shown above) are provided for element and type
  // http://stackoverflow.com/a/15521523/1142217
  // src can be a url or a filename
  var js = document.createElement("script");
  js.src = s.src;
  js.type = (typeof s.type === 'undefined') ? 'text/javascript' : s.type;
  var element = (typeof s.element === 'undefined') ? 'head' : s.element;
  var e = document.getElementsByTagName(element)[0];
  e.appendChild(js);
    // BUG -- no error handling if src doesn't exist
}
var is_mobile = (screen.width<480); // mathjax won't perform acceptably on mobile devices
if (!is_mobile) {
  load_external_js({src:"/spotter_js/3.0.4/mathjax_config.js",type:"text/x-mathjax-config"});
    // FIXME -- This will break as soon as the version number changes.
    // If I do it without a directory, I get this in the js console:
    //   Loading failed for the <script> with http://localhost/cgi-bin/spotter3/mathjax_config.js
    // BUG -- The script doesn't actually seem to get executed. I think the idea is that because the
    //   type is not text/javascript, it doesn't get immediately executed, and that's intentional.
    //   It's supposed to get executed after mathjax loads. But now that never seems to happen...?
    //   This causes the noticeable bug where typing hbar gives [Math Processing Error].
  load_external_js({src:"https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=AM_HTMLorMML.js"});
          // URL may change from time to time, see https://www.mathjax.org/cdn-shutting-down/
}

  
