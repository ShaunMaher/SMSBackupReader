/*****************************************************************************
Copyright (c) 2010, BlueChip, Cyborg Systems

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
******************************************************************************
v1.3  Release - Inspired by http://pastie.org
*****************************************************************************/

function createCookie (name, value, days) {
  if (days) {
    var date = new Date();
    date.setTime(date.getTime() + (days * (24*60*60*1000)) );
    var expires = "; expires="+date.toGMTString();
  }
  else expires = "";
  document.cookie = name + "=" + value + expires + "; path=/";
}


function readCookie (name)
{
   var nameEQ = name + "=";
   var ca = document.cookie.split(';');
   for(var i=0;  i < ca.length;  i++) {
      var c = ca[i];
      while (c.charAt(0) == ' ')  c = c.substring(1,c.length) ;
      if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length, c.length);
   }
   return null;
}


function  setTheme (which) {
  var i, a;
  // Scan all "<link" elements
  for(i = 0;  (a = document.getElementsByTagName("link")[i]);  i++) {
    // if the "rel" attribute contains "stylesheet" and there is a "title" attribute
    if ( (a.getAttribute("rel").indexOf("stylesheet") != -1) && (a.getAttribute("id")) ) {
      // Enable the one we're after and disable all the others
      if (a.getAttribute("id") == which)  a.disabled = false ;
      else                                a.disabled = true ;
    }
  }
  // Remember which theme we last used
  createCookie("sms_theme", which, 365);
}


function  setDefaultTheme () {
  var cookie = readCookie("sms_theme");
  setTheme(cookie);

//   $('themeList').value = cookie;

//   document.all.themeList.value=cookie;

//   var combo = document.getElementById('themeList');
//   for (var i=0 ; i <= combo.length; i++)
//      if (combo.value==cookie)  combo.selectedIndex = i ;

//   var combo = document.forms[0].elements['themeList'];
//   for (var i=0 ; i <= combo.length; i++)
//      if (combo[combo.selectedIndex].value==cookie)  combo.selectedIndex = i ;

//   for (var i = 0;  i < themeList.options.length;  i++) {
//     if (themeList.options[i].value == cookie)
//        themeList.options[i].selected = true;
//   }

/// HHHHHHHHHHHHeeeeeeeeeeeeeelllllllllllllppppppppppppp !!!!!!!!!!!!
}
