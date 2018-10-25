<?xml version="1.0"?>

<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:template match="/">
  <html>
  <body>
	<div style="border: 1px #603 dashed; clear: both; margin: 2px; border-radius: 13px;">
      <xsl:for-each select="rss/channel/item">
        <div style="border: 1px #000 solid; margin: 3px; border-radius: 7px;">
          <p style="float:left; margin-left: 7px;"><xsl:value-of select="title"/></p><p style="float: right; padding-right: 2em;">(For publication on <xsl:value-of select="pubDate"/>) [category: <xsl:value-of select="category"/>]</p>
		  <p style="clear: both; height: 1px; margin-top: -1em;"></p>
          <img style="width: 400px; height: 400px; float: right; margin-top: -1em; margin-right: 7px; "> <xsl:attribute name="src">
			<xsl:value-of select="link"/>
		  </xsl:attribute></img>
          <pre style="float: left; margin-left: 5px;" ><xsl:value-of select="description"/></pre>
		  <p style="clear: both;"></p>
        </div>
      </xsl:for-each>
    </div>
  </body>
  </html>
</xsl:template>

</xsl:stylesheet> 