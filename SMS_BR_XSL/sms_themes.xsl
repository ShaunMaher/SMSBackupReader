<!-- ===========================================================================
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

===============================================================================
v1.3  Release - Inspired by http://pastie.org
=========================================================================== -->

<!-- ===========================================================================
TO add a new theme:

1. Copy any existing theme and change it to what you want

2. Create a Theme Title entry
         <option value="InternalName" >Theme Name</option>
   ...and place it where it says: *** Add new Theme Title here ***

3. Create a Theme Definition entry
         <link id="InternalName" href="CSSFile.css" rel="stylesheet" type="text/css" />
   ...and place it where it says: *** Add new Theme Definition here ***

.-'`;_,.-'`;_,.-'`;_,.-'`;_,.-'`;_,.-'`;_,.-'`;_,.-'`;_,.-'`;_,.-'`;_,.-'`;_,.-'`;_,.-'`;_,

Example:   CSS filename : mono.css        }- - - - - - - - - - - - - - - - - - - - -.
           Theme name   : Black and White }- - - - .                                |
           Internal name: monochrome      }- -.    |                                |
                                              |    |                                |
      ,- - - - - - - - -+- - - - - - - - - - -'    |                                |
     |                  |                          |                                |
     |                  |           ,- - - - - - - '                                |
     |                  V_________  V______________                                 |
     |   <option value="monochrome">Black and White</option>                        |
     |                                                                              |
     |   <link id="monochrome" href="mono.css" rel="stylesheet" type="text/css" />  |
     |             ^"""""""""        ^"""""""                                       |
     `- - - - - - -'                 `- - - - - - - - - - - - - - - - - - - - - - - '

=========================================================================== -->

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


   <!-- A list of available themes
        The first theme is the one that will be used by default -->
   <xsl:template name='themes'>
   <xsl:param name="block" />

      <xsl:if test="$block = 'list'">
         <option value="bubble1">Bubbles   </option>
         <option value="BC_norm">BC's Theme</option>
         <!-- *** Add new Theme Title here *** -->
      </xsl:if>

      <xsl:if test="$block = 'styles'">
         <link id="bubble1" href="sms_bubble.css" rel="a stylesheet" type="text/css" />
         <link id="BC_norm" href="sms_bc.css"     rel="a stylesheet" type="text/css" />
         <!-- *** Add new Theme Definition here *** -->
      </xsl:if>

   </xsl:template>

</xsl:stylesheet>
