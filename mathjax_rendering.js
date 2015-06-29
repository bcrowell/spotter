// code to render Spotter input using ASCIIMath and MathJax
// This should go near the bottom of the page so that the relevant html elements exist before it runs.

render_math("answer","out",variable_list);
  // variable_list is a global variable, which is created and initialized in the code output by the perl CGI.
  // Placing this here causes math to get rendered as soon as the page gets loaded, rather than
  // waiting for a keystroke. (Usually the un-rendered data would just look like ``, but it could also
  // have real math in it, e.g., if we hit the reload button in the browser.)

function render_math(inputId,outputId,variables) {
  var e = document.getElementById(inputId);
  if (e===null) {console.log("warning: inputId "+inputId+" not found in render_math()"); return;}
        // probably because I attempt this before the whole page is rendered, so it doesn't exist yet
  if (typeof(MathJax)==='undefined') {console.log("warning: MathJax object undefined in render_math()"); return;}
  var str = e.value;
  var math = MathJax.Hub.getAllJax(outputId)[0]; // http://docs.mathjax.org/en/latest/typeset.html
  for (var i=0; i<variables.length; i++) {
    var u = variables[i];
    var v = format_variable_name(u);
    if (u!=v) str = str.replace(new RegExp(u,"g"),v);
  }
  MathJax.Hub.Queue(["Text",math,str]);
}

// examples: alpha1 -> alpha_(1) , mus -> mu_(s) , Ftotal -> F_(total)
// problems: operators like eq will get treated as variables, rendered as e_(q)
// Escaped dollar signs in the following for use with Tint.
function format_variable_name(x) {
  var greek =  "alpha|beta|gamma|delta|epsilon|zeta|eta|theta|iota|kappa|lambda|mu|nu|xi|omicron|pi|rho|sigma|tau|upsilon|phi|chi|psi|omega|"
              +"Alpha|Beta|Gamma|Delta|Epsilon|Zeta|Eta|Theta|Iota|Kappa|Lambda|Mu|Nu|Xi|Omicron|Pi|Rho|Sigma|Tau|Upsilon|Phi|Chi|Psi|Omega";

  // just a Greek character and nothing else:
  var r = new RegExp("^("+greek+")$");
  if (r.test(x)) { return x; }

  // a Greek character followed by something, e.g., mu0:
  r = new RegExp("^("+greek+")(.+)");
  if (r.test(x)) { return x.replace(r,"\$1_(\$2)");}

  // a multi-letter variable name, e.g., Ftotal:
  r = /^(.)(.+)$/;
  if (r.test(x)) { return x.replace(r,"\$1_(\$2)");}

  return x;
}
