function load_external_js(s) {
  // usage: load_external_js({src:"http://foo.com/bar.js",element:"head",type:"text/javascript"});
  //           ... defaults (the values shown above) are provided for element and type
  // src must be a url, not just a filename
  // http://stackoverflow.com/a/15521523/1142217
  var js = document.createElement("script");
  js.src = s.src;
  js.type = (typeof s.type === 'undefined') ? 'text/javascript' : s.type;
  var element = (typeof s.element === 'undefined') ? 'head' : s.element;
  var e = document.getElementsByTagName(element)[0];
  console.log("informational message from mathjax_startup.js: loading file "+js.src);
  e.appendChild(js);
    // BUG -- no error handling if src doesn't exist
}

function relative_url(filename) {
  // https://stackoverflow.com/a/48072090/1142217
  // make a filename into a url relative to the parent script's directory
  var this_script_url = document.currentScript.src; // e.g., http://localhost/spotter_js/3.0.4/mathjax_startup.js
  return this_script_url.split('/').slice(0, -1).join('/') + '/' + filename;
}

var is_mobile = (screen.width<480); // mathjax won't perform acceptably on mobile devices
if (!is_mobile) {
  // load_external_js({src:relative_url("mathjax_config.js"),type:"text/x-mathjax-config"});
    // BUG -- The script doesn't actually seem to get executed. The idea is that because the
    //   type is not text/javascript, it doesn't get immediately executed, and that's intentional.
    //   It's supposed to get executed when mathjax loads. But now that never seems to happen...?
    //   This causes the noticeable bug where typing hbar gives [Math Processing Error].
    // Because of this bug, the JS code is currently hardcoded inside strings/boilerplate instead
    // of being dynamically loaded here.
  load_external_js({src:"https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.1/MathJax.js?config=AM_HTMLorMML.js"});
          // URL may change from time to time, see https://www.mathjax.org/cdn-shutting-down/
}

  
