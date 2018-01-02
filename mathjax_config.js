var mathjax_config_debugging_messages = true;
function mathjax_config_debug(message) {
  if (mathjax_config_debugging_messages) {
    console.log("informational message from mathjax_config.js: "+message);
  }
}
mathjax_config_debug("mathjax_config is being executed.");
MathJax.Hub.Register.StartupHook("AsciiMath Jax Config",function () {
  mathjax_config_debug("StartupHook is being executed.");
  var AM = MathJax.InputJax.AsciiMath.AM;
  var sym = AM.symbols;
   // Treat the following as functions, i.e., don't italicize them.
  var functions_to_add = ["asin","acos","atan","asinh","acosh","atanh"];
  function add_function(name) {
    sym.push(
      {input:name,  tag:"mo", output:name, tex:null, ttype:AM.TOKEN.UNARY, func:true}
    );
  }
  for (var i=0; i < functions_to_add.length; i++) {
    add_function(functions_to_add[i]);
  }
  // Don't treat the following as symbols.
  var functions_to_delete = ["Lim","det","dim","mod","gcd","lcm","lub","glb","min","max",
                             "hat","bar","vec","ul"];
  function delete_function(name) {
    for (var i=0; i < sym.length; i++) {
      if (name===sym[i].input) { sym.splice(i,1); break; }
    }
  }
  for (var i=0; i < functions_to_delete.length; i++) {
    delete_function(functions_to_delete[i]);
  }
});
