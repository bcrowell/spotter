/*
	Copyright (c) 2007 Benjamin Crowell, GPL v 2 or later
*/



import java.awt.*;
import java.applet.*;
import java.awt.event.*;
import java.util.*;
import java.io.*;
import java.net.*;
//import java.net.URL;
import netscape.javascript.JSObject;
import netscape.javascript.JSException;

/*

*/

public class MC extends Applet {
  Checkbox a,b,c,d;
  Button butt = new Button("Submit");
  Label l = new Label("--");
  String optionFoo;

  //===============================================================
  //				init
  //===============================================================
  public void init() {
    try {optionFoo = getParameter("foo");}
    catch (Exception ee) {}
    setLayout(new FlowLayout());
    add(butt);
    add(l);
    repaint();
  }
 
  //===============================================================
  //				paint
  //===============================================================
  public void paint(Graphics g) {
  }






}

