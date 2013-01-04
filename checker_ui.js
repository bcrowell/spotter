    /* (c) 2007 Benjamin Crowell, GPL v 2 or later */
    /*------------------------------------------------------------------------------------------------------------
       checker_ui.js
       -----------
    **********************************************************************************************
    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!


     When changing this code, change the version number at the top of Spotter.cgi, and also
     rename the directory on spotter_js/x.y.z on the server. Otherwise, users will keep getting
     the old version from their browsers' caches.


    !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    **********************************************************************************************
    ------------------------------------------------------------------------------------------------------------- */

ui = document.getElementById("check_ui_div");
ui.innerHTML = '';
var deepest = hier.length-3; // the deepest level of the hierarchy except for problem and find; typically is the index of 'chapter'
// Elsewhere, we've set something like this:
//    cgi_params = {what:'check',book:'1',file:'lm',chapter:'4'};
delete cgi_params['login']; // otherwise we get login=set_cookie carried along forever, and logins get messed up
var checking = (cgi_params['what']=='check');
cgi_params['what'] = 'check'; // for use in generating all the links into the toc
var depth_specified = -1;
var pars_where = {}; // the subset of the cgi-params that refer to chapters, etc.
for (var i=0; i<=hier.length-1; i++) {
  if (cgi_params[hier[i]]!=null) {
    pars_where[hier[i]]=cgi_params[hier[i]];
    if (i>depth_specified) {depth_specified=i;}
  }
}
var pars_other = {}; // the subset of the cgi-params that refer to stuff other than chapters, etc.
for (var i in cgi_params) {
  var nono = 0;
  for (var j=0; j<=hier.length-1; j++) {
    if (hier[j]==i) {nono=1;}
  }
  if (!nono) {pars_other[i]=cgi_params[i];}
}

pr("<p>\n");
var do_toc = function(toc,depth,p) { // recursive function to print table of contents
  var c = toc.contents; // array
  if ( depth<=deepest+1 && (toc.type===null || cgi_params[toc.type]==toc.num || depth==depth_specified+2)) {
    var p2 = {};
    for (var i in p) {p2[i]=p[i];}
    if (toc.type!=null) {p2[toc.type]=toc.num}
    var m='';
    for (var i=1; i<=depth-1; i++) {m=m+'&mdash; '}
    var describe_num = '';
    if (toc.type!=null && number_style[depth-1]=='1') {describe_num = toc.type+' '+toc.num+': '}
    var foo = '<br/>';
    if (depth==0) {foo='</p><p>';}
    pr(m+bold(link(p2,describe_num+format(toc.title)+foo)));
    for (var i in c) {do_toc(c[i],depth+1,p2);}
  }
};
do_toc(toc,0,pars_other);
pr("</p>\n");

var for_real = (depth_specified==deepest+2 && checking); // they've specified enough to do a real answer check, and an answer check is what they're trying to do
var the_problem;

pr("<p>\n");
var do_toc2 = function(toc,depth,p) {
  var c = toc.contents; // array
  if (toc.type===null || cgi_params[toc.type]==toc.num || (depth>deepest+1 && depth==depth_specified+2) || (depth_specified==deepest && depth==depth_specified+3)) {
    var p2 = {};
    for (var i in p) {p2[i]=p[i];}
    if (depth>deepest+1) {
      if (toc.type=='problem') {
        p2['problem']=toc.num;
        var singleton = (c.length==2); // a problem with only one part, so the problem number can be a link to that part
        if (singleton) {
          p2['find'] = 1;
        }
        else {
          delete p2['find'];
        }
        var singleton_flag = '';
        if (!singleton) {singleton_flag=''}
        pr(link(p2,singleton_flag+'problem '+toc.num+'<br/>'));
      }
      if (toc.type=='find') {
        p2['find']=toc.num;
        var q = format(toc.title);
        if (for_real) {
          pr(do_images(q));
          the_problem = toc;
        }
        else {
          pr('&mdash; '+link(p2,truncate(q)+'<br/>'))
        }
      }
    }
    for (var i in c) {do_toc2(c[i],depth+1,p2);}
  }
};
do_toc2(toc,0,cgi_params);
pr("</p>\n");

//toc1_2_2_1 = new Toc('find',toc1_2_2,1,{},[{min:'0',sym:'R',max:'1',min_imag:'0',max_imag:'0',type:'float',description:'the radius of the Earth',units:'m'},{min:'0',sym:'theta',max:'1',min_imag:'0',max_imag:'0',type:'float',description:'the latitude',units:''}],'(a) Distance traveled by a point on the Earth\'s surface in one day. In addition to the variables listed below, your answer will involve the constant pi.');

if (for_real) {
  var options = the_problem.options;
  var vars = the_problem.vars;
  if (vars.length>0) {
    pr("<p>Variables:</p><ul>");
    for (var i in vars) {
      var v = vars[i];
      var d = v['description'];
      if (d===null || d===undefined) {d=''} else {d=' = '+format(d);}
      pr("<li>"+v['sym']+d+"</li>\n");
    }
    pr("</ul>\n");
  }
  pr(answer_feedback);
}

function link(p,s) {
  var z = [];
  for (var i in p) {
    z.push(i+'='+p[i]);
  }
  return '<a href="Spotter.cgi?'+z.join('&')+'">'+s+'</a>'; // *********************** change this to Spotter2.cgi for testing, Spotter.cgi for live *********************************
}

// could actually do this with CSS
function bold(s) {
  return "<b>"+s+"</b>";
}

function pr(s) {
  if (s!=null) {ui.innerHTML = ui.innerHTML + s;}
}

// duplicated in SpotterHTMLUtil.pm
function format(s) {
  s = s.replace(new RegExp('\\^\{([^\}]+)\}',"g"),'<sup>\$1</sup>');
  s = s.replace(new RegExp('\_\{([^\}]+)\}',"g"),'<sub>\$1</sub>');
  s = s.replace(new RegExp('i\{([^\}]+)\}',"g"),'<i>\$1</i>');
  s = s.replace(new RegExp('b\{([^\}]+)\}',"g"),'<b>\$1</b>');
  s = s.replace(new RegExp('e\{([^\}]+)\}',"g"),'&\$1;');
  return s;
}

function do_images(s) {
  s = s.replace(new RegExp('f\{([^\}]+)\}',"g"),'\n<br/><img src="\$1"/><br/>\n');
  s = s.replace(new RegExp('\{',"g"),'<');
  s = s.replace(new RegExp('\}',"g"),'>');
  return s;
}

// This function is duplicated in Spotter.cgi.
function truncate(data) {
  var max_length = 60;
  var display = data;
  if (data.length>max_length) {
    display = data.substring(0,max_length-3); // -3 to allow for ... at end
    // first regex: close off any tag that we chopped off in the middle
    // second regex: chopped off in the middle of an &lt; or something (bug: ignorant of quotes)
    while (display.length<data.length && ( /\<[^\>]*$/.test(display) || /\&\w*$/.test(display) ) ) {
      display = data.substring(0,(1+display.length));
    }
    // add any trailing tags
    // bug: misunderstands quoted angle brackets
    // bug: leaves in trailing open-tag-close-tag pairs
    var did_it;
    do {
      did_it = 0;
      var tail = data.substring(display.length);
      var m = /(\<[^\>]+\>)/g.exec(tail);
      if (m!=null && m.length>=2) {display = display+m[1]; did_it = 1;}
    }
    while (did_it);
    display = display + '...';
  }
  return display;
}


    /* ------------------------------------------------------------------------------------------------------------- */
