    /* (c) 2007 Benjamin Crowell, GPL v 2 or later */

    var choices;
    var responses;
    var clicked;

    function populate(mc) {
      var n = mc.length/2;
      choices = new Array(n);
      responses = new Array(n);
      clicked = new Array(n);
      for (var i=0; i<mc.length; i+=2) {
        choices[i/2] = mc[i];
        responses[i/2] = mc[i+1];
      }
      t = '';
      for (var i=0; i<n; i++) {
        t = t + '<div id="mc_'+i+'" style="cursor:pointer" onclick="response('+i+')">   </div>';
      }
      document.getElementById("container").innerHTML = t;
      for (var i=0; i<n; i++) {
        update_choice(choices[i],responses[i],false,i);
      }
      var instr = "Click on your answer, and the computer will tell you whether you're right or wrong. If you're wrong, you can keep trying.";
      if (typeof(instructions) == 'string') {instr = instructions}
      document.getElementById("instructions").innerHTML = "<i>"+instr+"</i>";
    }

    function response(i) {
      if (clicked[i]) {return} /* clicking a second time on same answer */
      clicked[i] = true;
      update_choice(choices[i],responses[i],clicked[i],i);
    }

    function update_choice(text,response,clicked,i) {
      var correct = (response==null) || (response=="");
      var letter = '('+number_to_letter(i)+') ';
      var rstyle = 'style="margin-left: 2ex"';
      var html = '';
      var logged_in = (user != '');
      if (clicked) {
        if (correct) {
          html = '<p>'+letter+text+'</p><p '+rstyle+'>Correct.</p>';
        }
        else {
          html = '<p>'+letter+text+'</p><p '+rstyle+'>Incorrect. '+response+'</p>';
        }
      }
      else {
          html = '<p>'+letter+text+'</p>';
      }
      choice_element(i).innerHTML = html;
      /* Do the ajax stuff at the end, because it may not work in all browsers. */
      if (clicked && correct && logged_in) {do_get_request('Spotter_record_work_lightweight.cgi?username='+user+'&'+query+'&correct='+1)}
    }

    function number_to_letter(n) {
      return String.fromCharCode('a'.charCodeAt(0)+n);
    }

    function choice_element(n) {
      return document.getElementById("mc_"+n);
    }

