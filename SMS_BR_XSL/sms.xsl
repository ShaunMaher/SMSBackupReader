<?xml version="1.0" encoding="UTF-8"?>

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
v1.0  Tested & working in Opera & Firefox
      Does not work in Chrome or IE8 ...I believe this is because these
        browsers do not support xslt - specifically node-set() !?

v1.1  Split "(Unknown)" by phone number (aka @address)
      Added support for Draft Emails
      Converted to use CSS

v1.2  Converted to use div's instead of table's for full CSS/HTML compliancy
      Rewrote CSS
      Expanded CR/LF function
      Added 'parse' [wrapped crlf] function for future expandability
      Extract first name and prefix messages with sender

v1.3  Added Theme selector
      BUG: List box does NOT show current theme by default!
=========================================================================== -->

<!-- stylesheet info; we will need "exslt" -->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:exslt="http://exslt.org/common"
  exclude-result-prefixes="exslt"
  xmlns:user="http://android.riteshsahu.com"
>

   <!-- Grab the user-defined themes temnplate -->
   <xsl:import href="sms_themes.xsl" />

   <!-- Modified from the string-replace-all template found at:
        http://geekswithblogs.net/Erik/archive/2008/04/01/120915.aspx
        with help from FR^2 on Freenode/#xml -->
   <xsl:template name="crlf-to-break">
   <xsl:param name="text" />
      <xsl:choose>
         <xsl:when test="contains($text,'&#13;&#10;')">
            <!-- This is to resolve a bug in some T-Mobile (not Android) firmware -->
            <xsl:value-of select="substring-before($text,'&#13;&#10;')" />
            <br />
            <xsl:call-template name="crlf-to-break">
               <xsl:with-param name="text" select="substring-after($text,'&#13;&#10;')" />
            </xsl:call-template>
         </xsl:when>
         <xsl:when test="contains($text,'&#10;')">
            <xsl:value-of select="substring-before($text,'&#10;')" />
            <br />
            <xsl:call-template name="crlf-to-break">
               <xsl:with-param name="text" select="substring-after($text,'&#10;')" />
            </xsl:call-template>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="$text" />
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>

   <!-- I can see more parsing being added at some point ;) -->
   <xsl:template name="parse">
   <xsl:param name="msg" />
      <xsl:call-template name="crlf-to-break">
         <xsl:with-param name="text" select="$msg" />
      </xsl:call-template>
   </xsl:template>

   <!-- Extract first name -->
   <xsl:template name="getname">
   <xsl:param name="name" />
      <xsl:if test="substring-before($name,' ')">
        <xsl:value-of select="substring-before($name,' ')" />: <!-- don't miss the colon -->
      </xsl:if>
      <xsl:if test="not(substring-before($name,' '))">
        <xsl:value-of select="$name" />: <!-- don't miss the colon -->
      </xsl:if>
   </xsl:template>

   <!-- A list of all fields (we wish to use)
        This is used somehow by the sorted list -->
   <xsl:template match="sms">
      <sms>
         <xsl:copy-of select="@protocol" />
         <xsl:copy-of select="@address" />
         <xsl:copy-of select="@date" />
         <xsl:copy-of select="@type" />
         <xsl:copy-of select="@subject" />
         <xsl:copy-of select="@body" />
         <xsl:copy-of select="@toa" />
         <xsl:copy-of select="@sc_toa" />
         <xsl:copy-of select="@service_center" />
         <xsl:copy-of select="@read" />
         <xsl:copy-of select="@status" />
         <xsl:copy-of select="@readable_date" />
         <xsl:copy-of select="@contact_name" />
      </sms>
   </xsl:template>

   <!-- This is it... -->
   <xsl:template match="/">

      <!-- Create a 'variable' which contains the smses sorted by name/date
           Many thanks to Ankh on Freenode/#xml for his help with this -->
      <xsl:variable name="sorted">
         <xsl:apply-templates select="smses/sms">
            <xsl:sort select="@contact_name"/>
            <xsl:sort select="@address"/>
            <xsl:sort select="@date" />
         </xsl:apply-templates>
      </xsl:variable>

      <!-- This is where the html starts -->
      <html>
         <head>
            <xsl:call-template name="themes"><xsl:with-param name="block">styles</xsl:with-param></xsl:call-template>
            <script src="sms.js" type="text/javascript"></script>
            <title><xsl:text>SMS Database</xsl:text></title>
         </head>

         <body onload="setDefaultTheme()">
            <div class="break" />

            <!-- The theme selector -->
            <div class="theme">
               <label class="theme">Theme:</label>
               <select onchange="setTheme(this.value);" id="themeList">
                  <xsl:call-template name="themes"><xsl:with-param name="block">list</xsl:with-param></xsl:call-template>
               </select>
            </div>

            <!-- the main loop to parse each sms -->
            <xsl:for-each select="exslt:node-set($sorted)/sms">

               <!-- Put a name banner as we start each new contact/"thread" -->
               <!-- deal with name="(Unknown)" -->
               <xsl:if test="@contact_name = '(Unknown)'">
                  <xsl:if test="not(preceding-sibling::sms[1]/@address = @address)">
                     <div class="name unknown">
                       <xsl:text>Tel:&#xA0;&#xA0;</xsl:text><xsl:value-of select="@address"/>
                     </div>
                  </xsl:if>
               </xsl:if>
               <!-- deal with known names -->
               <xsl:if test="not(@contact_name = '(Unknown)')">
                  <xsl:if test="not(preceding-sibling::sms[1]/@contact_name = @contact_name)">
                     <div class="name">
                        <div class="contact"><xsl:value-of select="@contact_name"/></div>
                        <div class="number">
                           <xsl:text>(&#xA0;</xsl:text><xsl:value-of select="@address"/><xsl:text>&#xA0;)</xsl:text>
                        </div>
                     </div>
                  </xsl:if>
               </xsl:if>

               <!-- Display each message -->
               <div>
                  <xsl:if test="@type = 1"><xsl:attribute name="class">msg rcvd</xsl:attribute></xsl:if>
                  <xsl:if test="@type = 2"><xsl:attribute name="class">msg sent</xsl:attribute></xsl:if>
                  <xsl:if test="@type = 3"><xsl:attribute name="class">msg drft</xsl:attribute></xsl:if>
                  <!-- Prefix received with "You:" -->
                  <xsl:if test="@type = 1">
                     <font class="rcvd you">
                        <xsl:call-template name="getname"><xsl:with-param name="name" select="@contact_name" /></xsl:call-template>
                     </font>
                  </xsl:if>
                  <!-- Prefix sent+draft with "Me:" -->
                  <xsl:if test="not(@type = 1)">
                     <font>
                     <xsl:if test="@type = 2"><xsl:attribute name="class">sent me</xsl:attribute></xsl:if>
                     <xsl:if test="@type = 3"><xsl:attribute name="class">drft me</xsl:attribute></xsl:if>
                        <xsl:text>Me:</xsl:text>
                     </font>
                  </xsl:if>
                  <!-- The Message -->
                  <font>
                  <xsl:if test="@type = 1"><xsl:attribute name="class">rcvd</xsl:attribute></xsl:if>
                  <xsl:if test="@type = 2"><xsl:attribute name="class">sent</xsl:attribute></xsl:if>
                  <xsl:if test="@type = 3"><xsl:attribute name="class">drft</xsl:attribute></xsl:if>
                     <!-- Auto-edit message text -->
                     <xsl:call-template name="parse"><xsl:with-param name="msg" select="@body" /></xsl:call-template>
                  </font>
               </div>

               <!-- Append a footer to each message -->
               <div>
                  <xsl:if test="@type = 1"><xsl:attribute name="class">msg rcvd footer</xsl:attribute></xsl:if>
                  <xsl:if test="@type = 2"><xsl:attribute name="class">msg sent footer</xsl:attribute></xsl:if>
                  <xsl:if test="@type = 3"><xsl:attribute name="class">msg drft footer</xsl:attribute>
                                           <font class="saved">[draft saved]</font>
                  </xsl:if>
                  <xsl:text>&#xA0;&#xA0;</xsl:text>
                  <font class="date"><xsl:value-of select="@readable_date"/></font>
               </div>

               <!-- Put a gap when we get to the end of a contact/"thread" -->
               <!-- deal with name="(Unknown)" -->
               <xsl:if test="@contact_name = '(Unknown)'">
                  <xsl:if test="not(following-sibling::sms[1]/@address = @address)"><div class="break" /></xsl:if>
               </xsl:if>
               <!-- deal with known names -->
               <xsl:if test="not(following-sibling::sms[1]/@contact_name = @contact_name)"><div class="break" /></xsl:if>

            </xsl:for-each>
         </body>
      </html>
   </xsl:template>

</xsl:stylesheet>
