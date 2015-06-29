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
}
var is_mobile = (screen.width<480); // mathjax won't perform acceptably on mobile devices
if (!is_mobile) {
  load_external_js({src:"mathjax_config.js",type:"text/x-mathjax-config"});
  load_external_js({src:"https://cdn.mathjax.org/mathjax/latest/MathJax.js?config=AM_HTMLorMML.js"});
}

  
