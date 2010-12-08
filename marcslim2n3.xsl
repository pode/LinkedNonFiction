<?xml version="1.0" encoding="UTF-8"?>

<!--
marcslim2n3.xsl - xslt stylesheet to render marc21 slim xml to rdf
Author: Benjamin Rokseth
Contact: benjamin@deichman.no
Date: 25.08.2010
Version XSL file: v03
Vocabulary: http://www.bibpode.no/

Current position: line 1288!

Issues: 
	dct:title, pode:subtitle, pode:responsibility has sometimes " in it, need to translate away quotes as they break rdf
		solution: translate(translate(., '&quot;',''),'&amp;','')
	260 $b dct:issued needs to remove unwanted chars, translate away everything except numbers
		solution: translate(.,translate(.,'0123456789',''),'') 
	082 $a contains dewey and sometimes unwanted content. 
		solution: check for digit in 3rd position: xsl:if test="substring(.,3,1) &gt;= '0' and substring(.,3,1) &lt;= '9'"
				  + translate . in isbn to _ for compliance to rdf
	008 $b somtimes contains 'mul' which means multi language codes of 3 digits with no separation between are in 041
		solution: double test: if pos 36-38 is 'mul' fetch datafield 041, call template splitstring to get three and three chars:
				  <xsl:call-template name="splitstring">
							<xsl:with-param name="string" select="//datafield[@tag = '041']/subfield[@code = 'a']"/>
							<xsl:with-param name="position" select="1"/>
							<xsl:with-param name="prefix" select="'dct:language&#09;&#09;podeInstance:'"/>
	    also in a few places there is no language code, so it all needs to be wrapped in an IF to check if it isn't only spaces:
		solution: <xsl:if test="string-length(normalize-space(substring(., 36 ,3))) != 0">
	    						
	019 $b is physical format and sometimes contains comma separated content
		solution: <xsl:call-template name="divide">
								<xsl:with-param name="string" select="."/>
								<xsl:with-param name="splitcharacter" select="'character-to-split-with'"/>
								<xsl:with-param name="prefix" select="'dct:format&#09;&#09;&#09;pode_ff:'"/>
								<xsl:with-param name="suffix" select="'&#09;&#10;'"/>
								
	019 $d is literary format and contains one char per format
		solution: <xsl:call-template name="splitstring">
							<xsl:with-param name="string" select="."/>
							<xsl:with-param name="position" select="1"/>
							<xsl:with-param name="prefix" select="'pode:literaryFormat&#09;pode_lf:'"/>
							<xsl:with-param name="suffix" select="''"/>
							<xsl:with-param name="splitcharnumber" select="1"/>
	instances created need to remove unwanted characters.
		solution: call template replaceUnwantedCharacters:
		first translates certain non-ascii characters into acceptable ones, then a translate against a variable containing a list of characters to remove the rest.
	<xsl:variable name="safe_ascii">-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz</xsl:variable>
		<xsl:template name="replaceUnwantedCharacters">
		  <xsl:param name="stringIn"/>
		  <xsl:variable name="replacedChars" select="translate(translate(translate(translate(translate(translate(translate(translate(translate(translate(translate(translate($stringIn,'æ','ae'),'Æ','Ae'),'ø','oe'),'Ø','Oe'),'å','aa'),'Å','Aa'),' \,','__'),'ãäàá','aaaa'),'ẽëèé','eeee'),'ĩïìí','iiii'),'ũüùú','uuuu'),'õöòóô','ooooo')"/>
		  <xsl:value-of select="translate($replacedChars, translate($replacedChars, $safe_ascii, ''), '')" />
		</xsl:template>
	
	260 $a : some instances in the marc21slim have arbitrary dividers, e.g. , [] and {}
		solution: need to write a separate divider for all? or expand the divide template?
		eg.: publicationPlace instances are sometimes divided by ;
		solution need a test="contains(string,';'), and if true, run divide template with ';' and AFTER replaceUnwantedCharacters on each instance to produce valid turtle
		
	empty instances need to be removed, not to break turtle parsing
		solution: embed a test for content - <xsl:if test="* | text()">
-->

<xsl:stylesheet version="1.0" 
			xmlns:owl="http://www.w3.org/2002/07/owl#"
			xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
			xmlns:xsd="http://www.w3.org/2001/XMLSchema#"
			xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
			xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#"
			xmlns:foaf="http://xmlns.com/foaf/0.1/"
			xmlns:xfoaf="http://www.foafrealm.org/xfoaf/0.1/"
			xmlns:lingvoj="http://www.lingvoj.org/ontology#"
			xmlns:lexvo="http://lexvo.org/id/iso639-3/"
			xmlns:mm="http://musicbrainz.org/mm/mm-2.1#" 
			xmlns:mo="http://purl.org/ontology/mo#"
			xmlns:dcmi="http://dublincore.org/documents/dcmi-terms/"
			xmlns:dcmitype="http://dublincore.org/documents/dcmi-type-vocabulary/"
			xmlns:skos="http://www.w3.org/2004/02/skos/core#"
			xmlns:geo="http://www.geonames.org/ontology#"			
			xmlns:dct="http://purl.org/dc/elements/1.1/"
			xmlns:dc="http://purl.org/dc/elements/1.1/"
			xmlns:cc="http://web.resource.org/cc/"

			xmlns:marc21slim="http://www.loc.gov/MARC21/slim"
			xmlns:bibo="http://purl.org/ontology/bibo/"
			xmlns:pode="http://www.bibpode.no/vocabulary#"
			xmlns:ff="http://www.bibpode.no/ff/"
			xmlns:lf="http://www.bibpode.no/lf/"
			xmlns:frbr="http://idi.ntnu.no/frbrizer"
			xmlns:sublima="http://xmlns.computas.com/sublima#"
			xmlns:deweyClass="http://dewey.info/class/"
			xmlns:owl2xml="http://www.w3.org/2006/12/owl2-xml#"
			xmlns:movie="http://data.linkedmdb.org/resource/movie/"	>

	<xsl:output method="text" version="1.0" encoding="UTF-8" indent="yes"/>
	
<!-- 	global variables: 
		$safe_ascii - used to clean up instances in templates 
		valid_first_char - used to create valid turtle syntax, i.e. no digits as first character 
		lower/uppercase - used to correct languages -->
		
	      <xsl:variable name="safe_ascii">-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz</xsl:variable>
	      <xsl:variable name="valid_first_char">ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz</xsl:variable>
	      <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyzæøå'" />
	      <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZÆØÅ'" />
	      
<!-- START PARSING -->	
	<xsl:template match="/">

<xsl:text>&#09;</xsl:text><xsl:text>&#64;</xsl:text>prefix rdf: 		<xsl:text>&#60;</xsl:text>http://www.w3.org/1999/02/22-rdf-syntax-ns#<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix rdfs: 		<xsl:text>&#60;</xsl:text>http://www.w3.org/2000/01/rdf-schema#<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix owl: 		<xsl:text>&#60;</xsl:text>http://www.w3.org/2002/07/owl#<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix foaf: 		<xsl:text>&#60;</xsl:text>http://xmlns.com/foaf/0.1/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix xfoaf: 		<xsl:text>&#60;</xsl:text>http://www.foafrealm.org/xfoaf/0.1/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix lingvoj: 	<xsl:text>&#60;</xsl:text>http://www.lingvoj.org/ontology#<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix lexvo: 	<xsl:text>&#60;</xsl:text>http://lexvo.org/id/iso639-3/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix lingvo: 		<xsl:text>&#60;</xsl:text>http://www.lingvoj.org/lang/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix dcmitype: 	<xsl:text>&#60;</xsl:text>http://purl.org/dc/dcmitype/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix dcmi: 		<xsl:text>&#60;</xsl:text>http://purl.org/dc/dcmitype/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix dct: 		<xsl:text>&#60;</xsl:text>http://purl.org/dc/terms/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix dc: 		<xsl:text>&#60;</xsl:text>http://purl.org/dc/terms/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix skos: 		<xsl:text>&#60;</xsl:text>http://www.w3.org/2004/02/skos/core#<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix xsd: 		<xsl:text>&#60;</xsl:text>http://www.w3.org/2001/XMLSchema#<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix mm: 		<xsl:text>&#60;</xsl:text>http://musicbrainz.org/mm/mm-2.1#<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix mo: 		<xsl:text>&#60;</xsl:text>http://purl.org/ontology/mo#<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix cc: 		<xsl:text>&#60;</xsl:text>http://creativecommons.org/ns#<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix geo:		<xsl:text>&#60;</xsl:text>http://www.geonames.org/ontology#<xsl:text>&#62; .</xsl:text> 
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix wgs84_pos:	<xsl:text>&#60;</xsl:text>http://www.w3.org/2003/01/geo/wgs84_pos#<xsl:text>&#62; .</xsl:text> 
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix ns:			<xsl:text>&#60;</xsl:text>http://creativecommons.org/ns#<xsl:text>&#62; .</xsl:text> 
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix owl2xml:	<xsl:text>&#60;</xsl:text>http://www.w3.org/2006/12/owl2-xml#<xsl:text>&#62; .</xsl:text> 
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix movie:		<xsl:text>&#60;</xsl:text>http://data.linkedmdb.org/resource/movie/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix gutenberg:		<xsl:text>&#60;</xsl:text>http://www.gutenberg.org/ebooks/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix dbpedia:		<xsl:text>&#60;</xsl:text>http://dbpedia.org/resource/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix viaf:		<xsl:text>&#60;</xsl:text>http://viaf.org/viaf/<xsl:text>&#62; .</xsl:text>
<!-- pode specific prefix -->		
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix bibo:	<xsl:text>&#60;</xsl:text>http://purl.org/ontology/bibo/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix marc21slim:	<xsl:text>&#60;</xsl:text>http://www.loc.gov/MARC21/slim<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix pode:		<xsl:text>&#60;</xsl:text>http://www.bibpode.no/vocabulary#<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix podeInstance:	<xsl:text>&#60;</xsl:text>http://www.bibpode.no/instance/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix podeAudience:	<xsl:text>&#60;</xsl:text>http://www.bibpode.no/audience/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix genre:	<xsl:text>&#60;</xsl:text>http://www.bibpode.no/genre/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix topic:	<xsl:text>&#60;</xsl:text>http://www.bibpode.no/topic/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix person:	<xsl:text>&#60;</xsl:text>http://www.bibpode.no/person/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix work:	<xsl:text>&#60;</xsl:text>http://www.bibpode.no/work/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix expression:	<xsl:text>&#60;</xsl:text>http://www.bibpode.no/expression/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix pode_ff:			<xsl:text>&#60;</xsl:text>http://www.bibpode.no/physicalFormat/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix pode_lf:			<xsl:text>&#60;</xsl:text>http://www.bibpode.no/literaryFormat/<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix sublima:	<xsl:text>&#60;</xsl:text>http://xmlns.computas.com/sublima#<xsl:text>&#62; .</xsl:text>
	<xsl:text>&#10;&#09;&#64;</xsl:text>prefix deichman:	<xsl:text>&#60;</xsl:text>http://www.deich.folkebibl.no/cgi-bin/websok?<xsl:text>&#62; .</xsl:text>
	
		<xsl:text>&#10;&#09;</xsl:text><xsl:text>&#10;</xsl:text><xsl:text>&#10;</xsl:text>

<!-- FIRST RUN -->
			<xsl:apply-templates select="collection/marc21slim:record"/>

<!-- SECOND RUN: instances -->				
	<!-- publicationPlace foaf:Organizaion-->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 260]/marc21slim:subfield[@code = 'a']"/>
	<!-- publisher geo:Feature -->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 260]/marc21slim:subfield[@code = 'b']"/>		
	<!-- language lingvoj:Lingvo -->			
	<!-- excluded
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:controlfield[@tag = '008']"/>
	-->
	<!-- foaf:Person -->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 100]"/>
	<!-- foaf:Organization -->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 110]/marc21slim:subfield[@code = 'a']"/>
	<!-- movie:film_genre -->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 655]/marc21slim:subfield[@code = 'a']"/>
	<!-- foaf:Organization -->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 710]/marc21slim:subfield[@code = 'a']"/>
	
	<!-- foaf:Person -->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 700]"/>
	
	<!-- dct:hasPart 700 $t-->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 700]/marc21slim:subfield[@code = 't']"/>		
	
	<!-- dct:hasPart 710 $t-->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 710]/marc21slim:subfield[@code = 't']"/>		
	
	<!-- skos:Concept 600-->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 600]"/>
			
	<!-- skos:Concept from $a+$x & pode:ddk from $1, tags 630, 650, 690, 692, 693, 699 -->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 630]"/>
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 650]"/>
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 690]"/>
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 692]"/>
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 693]"/>
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 699]"/>
	<!-- sublima:classification -->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 082]/marc21slim:subfield[@code = 'a']"/>
	<!-- bibo:Series -->
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 440]"/>
			<xsl:apply-templates select="collection/marc21slim:record/marc21slim:datafield[@tag = 490]"/>		
	
			<xsl:text>&#10;</xsl:text>
	</xsl:template>
<!--	END MAIN TEMPLATE		-->


<!-- 	START COLLECTION TEMPLATE -->
	<xsl:template match="collection/marc21slim:record">
<!-- URI CREATED FROM WEBSEARCH ID -->
<!--
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 996">
 test subfield for code 'u'  
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'u'">
					<dct:uri><xsl:text>&#60;</xsl:text><xsl:value-of select="."/><xsl:text>&#62;</xsl:text></dct:uri>
				</xsl:if>
			</xsl:for-each>
		</xsl:if>
		</xsl:for-each>
-->
<!-- URI CREATED FROM DEICHMAN TITLE ID -->
		<xsl:for-each select="marc21slim:controlfield">
			<xsl:if test="@tag = 001">
					<dct:uri><xsl:text>deichman:tnr_</xsl:text><xsl:value-of select="."/></dct:uri>
			
		<rdf:type><xsl:text>&#10;&#09;</xsl:text>a			bibo:Document ;</rdf:type>
		<bibo:uri><xsl:text>&#10;&#09;</xsl:text><xsl:text>bibo:uri		&#60;http://www.deich.folkebibl.no/cgi-bin/websok?tnr=</xsl:text><xsl:value-of select="."/><xsl:text>&#62; ;</xsl:text></bibo:uri>
		<dct:source><xsl:text>&#10;&#09;</xsl:text>dct:source		pode:dfb_fagposter</dct:source>
		</xsl:if>
		</xsl:for-each>

<!-- Her testes datafield mot marc 600, 700 og 740 for tittel --> 
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 700">
<!-- test subfield for code 't'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 't'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">				
						<dct:hasPart><xsl:text> ;&#10;&#09;</xsl:text>dct:hasPart 	 	deichman:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template>
						</dct:hasPart>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
		</xsl:if>
		</xsl:for-each>

			<xsl:for-each select="marc21slim:datafield">

			<xsl:if test="@tag = 740">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">				
				<dct:title><xsl:text> ;&#10;&#09;</xsl:text>dct:title 	 	"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:title>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
		</xsl:if>
			<xsl:if test="@tag = 600">
<!-- test subfield for code 't'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 't'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">				
				<dct:title><xsl:text> ;&#10;&#09;</xsl:text>dct:title 	 	"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:title>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
		</xsl:if>
		</xsl:for-each>


<!-- her testes datafield mot marc 245 for tittel,undertittel & ansvar-->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 245">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">
						<dct:title><xsl:text> ;&#10;&#09;</xsl:text>dct:title 	 	"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:title>
					</xsl:if>
				</xsl:if>
<!-- test subfield for code 'b'  -->				
				<xsl:if test="@code = 'b'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">
						<dct:subtitle><xsl:text> ;&#10;&#09;</xsl:text>pode:subtitle 	 	"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:subtitle>
					</xsl:if>
				</xsl:if>

<!-- test subfield for code 'c'  -->				
				<xsl:if test="@code = 'c'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">
						<pode:responsibility><xsl:text> ;&#10;&#09;</xsl:text>pode:responsibility 	 """<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</pode:responsibility>
					</xsl:if>
				</xsl:if>
								
			</xsl:for-each>
		</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 240 for dct:alternative -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 240">
<!-- test subfield for code 'a'  -->
				<dct:alternative><xsl:text> ;&#10;&#09;dct:alternative 	 	"""</xsl:text>
					<xsl:for-each select="marc21slim:subfield">
						<xsl:if test="@code = 'a' or @code = 'b'">
				
					<!-- test for empty node before outputting content -->
							<xsl:if test="* | text()">
								<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>
						
									<xsl:if test="position() != last()">
									<xsl:text> : </xsl:text>
									</xsl:if>
							</xsl:if>
						</xsl:if>
					</xsl:for-each>
				<xsl:text>"""</xsl:text></dct:alternative>
			</xsl:if>
		</xsl:for-each>


<!-- her testes datafield mot marc 246 $a,b for dct:alternative -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 246">
<!-- test subfield for code 'a'  -->
				<dct:alternative><xsl:text> ;&#10;&#09;dct:alternative 	 	"""</xsl:text>
					<xsl:for-each select="marc21slim:subfield">
						<xsl:if test="@code = 'a' or @code = 'b'">
				
					<!-- test for empty node before outputting content -->
							<xsl:if test="* | text()">
								<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>
						
									<xsl:if test="position() != last()">
									<xsl:text> : </xsl:text>
									</xsl:if>
							</xsl:if>
						</xsl:if>
					</xsl:for-each>
				<xsl:text>"""</xsl:text></dct:alternative>
			</xsl:if>
		</xsl:for-each>
		
		
<!-- her testes datafield mot marc 246 $c for pode:responsibility -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 246">
					<xsl:for-each select="marc21slim:subfield">
			<!-- test subfield for code 'c'  -->				
						<xsl:if test="@code = 'c'">
						<!-- test for empty node before outputting content -->
							<xsl:if test="* | text()">
								<pode:responsibility><xsl:text> ;&#10;&#09;</xsl:text>pode:responsibility 	 """<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</pode:responsibility>
							</xsl:if>
						</xsl:if>
					</xsl:for-each>
			</xsl:if>
		</xsl:for-each>		
				
<!-- her testes datafield mot marc 250 $a for bibo:edition -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 250">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">
						<bibo:edition><xsl:text> ;&#10;&#09;</xsl:text>bibo:edition 	 	"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</bibo:edition>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>


<!-- test of datafield 019 
		$a dct:audience 
			nb! is fetched from 019 $a + character 22 in 008
		$b dct:format (physical format)
		$d pode:literaryFormat 
-->

		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 019">
<!-- test subfield for code 'b'  -->
			<xsl:for-each select="marc21slim:subfield">

				<xsl:if test="@code = 'a'">
				<xsl:for-each select=".">
			<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">
						<xsl:choose>
						<!-- check for commas, and if found, run template divide -->
							<xsl:when test="contains(.,',')">
								<xsl:call-template name="divide">
								<xsl:with-param name="string" select="translate(., $uppercase, $lowercase)"/>
								<xsl:with-param name="splitcharacter" select="','"/>
								<xsl:with-param name="prefix" select="' ;&#10;&#09;dct:audience&#09;&#09;podeAudience:'"/>
								<xsl:with-param name="suffix" select="''"/>
								</xsl:call-template>
							</xsl:when>
							<xsl:otherwise>
							<dct:audience><xsl:text> ;&#10;&#09;</xsl:text>dct:audience			podeAudience:<xsl:value-of select="."/></dct:audience>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:if>
					</xsl:for-each> <!-- end @code = 'a' -->
				</xsl:if>
				
				<xsl:if test="@code = 'b'">
				<xsl:for-each select=".">
			<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">
						<xsl:choose>
						<!-- check for commas, and if found, run template divide -->
							<xsl:when test="contains(.,',')">
								<xsl:call-template name="divide">
								<xsl:with-param name="string" select="translate(., $uppercase, $lowercase)"/>
								<xsl:with-param name="splitcharacter" select="','"/>
								<xsl:with-param name="prefix" select="' ;&#10;&#09;dct:format&#09;&#09;pode_ff:'"/>
								<xsl:with-param name="suffix" select="''"/>
								</xsl:call-template>
							</xsl:when>
							<xsl:otherwise>
							<dct:format><xsl:text> ;&#10;&#09;</xsl:text>dct:format			pode_ff:<xsl:value-of select="."/></dct:format>
							</xsl:otherwise>
						</xsl:choose>
					</xsl:if>
				</xsl:for-each> <!-- end @code = 'b' -->
				</xsl:if>
<!-- test subfield for code 'd' literary format -->
<!-- nb! splitstring template spits out  ;&#10;&#09; -->

				<xsl:if test="@code = 'd'">
				<xsl:for-each select=".">
					<xsl:if test="* | text()">
						<xsl:choose>
						<xsl:when test="string-length(.) &gt; 1">
							<xsl:call-template name="splitstring">
								<xsl:with-param name="string" select="translate(., $uppercase, $lowercase)"/>
								<xsl:with-param name="position" select="1"/>
								<xsl:with-param name="prefix" select="'pode:literaryFormat&#09;pode_lf:'"/>
								<xsl:with-param name="suffix" select="''"/>
								<xsl:with-param name="splitcharnumber" select="1"/>
							</xsl:call-template>
						</xsl:when>
						<xsl:otherwise>
							<pode:literaryFormat><xsl:text> ;&#10;&#09;</xsl:text>pode:literaryFormat			pode_lf:<xsl:value-of select="."/></pode:literaryFormat>
						</xsl:otherwise>
						</xsl:choose>
					</xsl:if>
				</xsl:for-each> 
				</xsl:if> <!-- end @code = 'd' -->
				
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>

<!-- 020/025 $a bibo:isbn -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 020">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">				
				<dct:isbn><xsl:text> ;&#10;&#09;</xsl:text>bibo:isbn 	 	"""<xsl:value-of select="translate(translate(translate(., '&quot;',''),'&amp;',''),'-','')"/>"""</dct:isbn>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>

<!-- 022 $a bibo:issn -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 022">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">				
				<dct:isbn><xsl:text> ;&#10;&#09;</xsl:text>bibo:issn 	 	"""<xsl:value-of select="translate(translate(translate(., '&quot;',''),'&amp;',''),'-','')"/>"""</dct:isbn>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>
		
<!-- 025 $a bibo:isbn13 -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 025">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">				
				<dct:isbn><xsl:text> ;&#10;&#09;</xsl:text>bibo:isbn13 	 	"""<xsl:value-of select="translate(translate(translate(., '&quot;',''),'&amp;',''),'-','')"/>"""</dct:isbn>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>

<!-- Her testes controlfield mot marc 008 og 041 for lokal språkkode --> 
		<xsl:for-each select="marc21slim:controlfield">
			<xsl:if test="@tag = 008">
<!-- extra test: if 35-37 is 'mul' fetch datafield 041 -->
<!-- NB: normalize-space is needed, because blank space is treated as character, thus not empty -->
					<xsl:if test="string-length(normalize-space(substring(., 36 ,3))) != 0">
						
						<xsl:call-template name="splitstring">
							<xsl:with-param name="string" select="translate(substring(., 36 ,3), $uppercase, $lowercase)"/>
							<xsl:with-param name="position" select="1"/>
							<xsl:with-param name="prefix" select="'dct:language&#09;&#09;lexvo:'"/>
							<xsl:with-param name="splitcharnumber" select="3"/>
						</xsl:call-template>
					</xsl:if>
				
<!-- 008 position 23 contains audience in some cases -->					
					<xsl:if test="string-length(normalize-space(substring(., 23 ,1))) != 0">
						<dct:audience><xsl:text> ;&#10;&#09;</xsl:text>dct:audience			podeAudience:<xsl:value-of select="substring(., 23 ,1)"/></dct:audience>
					</xsl:if>
				
				</xsl:if>
		</xsl:for-each>
		
		<xsl:for-each select="marc21slim:datafield[@tag = '041']/marc21slim:subfield[@code = 'a']">
			<xsl:if test="string-length(.) != 0">
				<xsl:call-template name="splitstring">
							<xsl:with-param name="string" select="translate(., $uppercase, $lowercase)"/>
							<xsl:with-param name="position" select="1"/>
							<xsl:with-param name="prefix" select="'dct:language&#09;&#09;lexvo:'"/>
							<xsl:with-param name="splitcharnumber" select="3"/>
				</xsl:call-template>
			</xsl:if>
		</xsl:for-each>	
		
<!-- her testes datafield mot marc 082 for klassifisering -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 082">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- NB! test for dewey digits before outputting content -->
					<xsl:if test="translate(., translate(., '0123456789', ''), '') != ''">	
					<!-- now make an instance for each of the three dewey levels as used in dewey.info -->
					
					<!-- Top level -->
					<pode:ddkFirst><xsl:text> ;&#10;&#09;</xsl:text>pode:ddkFirst		podeInstance:DDK_<xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,1)"/></pode:ddkFirst>
					
					<!-- Second level -->					
					<pode:ddkSecond><xsl:text> ;&#10;&#09;</xsl:text>pode:ddkSecond		podeInstance:DDK_<xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,2)"/></pode:ddkSecond>
					
					<!-- Third level -->
					<pode:ddkThird><xsl:text> ;&#10;&#09;</xsl:text>pode:ddkThird		podeInstance:DDK_<xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,3)"/></pode:ddkThird>
					
					<!-- The full dewey -->
					<pode:ddk><xsl:text> ;&#10;&#09;</xsl:text>pode:ddk			podeInstance:DDK_<xsl:value-of select="translate(., translate(., '0123456789', ''), '')"/></pode:ddk>
					
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 090 $b,$c,$d for pode:location -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 090">
<!-- test subfield for code 'a'  -->
			<pode:location><xsl:text> ;&#10;&#09;pode:location		"""</xsl:text>
				<xsl:for-each select="marc21slim:subfield">
					<xsl:if test="@code = 'b' or @code = 'c' or @code = 'd'">
					<!-- test for empty node before outputting content -->
						<xsl:if test="* | text()">						
						<xsl:value-of select="translate(translate(translate(translate(., 	'&quot;',''),'&amp;',''),'&amp;',''), ' ', '')"/>
				<!-- split out values separated with space -->
						<xsl:if test="position() != last()">
							<xsl:text> </xsl:text>
						</xsl:if>
					</xsl:if>
				</xsl:if>
				</xsl:for-each>
			<xsl:text>"""</xsl:text></pode:location>
			</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 100 $a for dct:creator
		dette brukes om hovedforfatter
		instans lages som foaf:Person
 -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 100">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for accepted characters before outputting content -->
					<xsl:if test="translate(., $safe_ascii, '') != ''">
						<dct:creator><xsl:text> ;&#10;&#09;</xsl:text>dct:creator 	 	podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template></dct:creator>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
		</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 110 $a for dct:creator
		dette brukes om organisasjon
		instans lages som foaf:Organization
 -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 110">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for accepted characters before outputting content -->
					<xsl:if test="translate(., $safe_ascii, '') != ''">
						<dct:creator><xsl:text> ;&#10;&#09;</xsl:text>dct:creator 	 	podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template></dct:creator>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
		</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 710 $a for dct:creator
		dette brukes om organisasjon
		instans lages som foaf:Organization
 -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 710">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for accepted characters before outputting content -->
					<xsl:if test="translate(., $safe_ascii, '') != ''">
						<dct:creator><xsl:text> ;&#10;&#09;</xsl:text>dct:creator 	 	podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template></dct:creator>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
		</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 760 $w for bibo:series
		instans kobles mot uri deichman:tnr_
 -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 760">
<!-- test subfield for code 'w'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'w'">
					<!-- test for string-length, add zeroes to get 7 with substr -->
						<dct:isPartOf><xsl:text> ;&#10;&#09;</xsl:text>dct:isPartOf 	 	deichman:tnr_<xsl:value-of select="substring('0000000', 1, (7 - string-length(.)))"/><xsl:value-of select="."/></dct:isPartOf>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 856 $u for dct:hasVersion
 -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 856">
<!-- test subfield for code 'u'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'u'">
					<!-- test for string-length, add zeroes to get 7 with substr -->
						<dct:hasVersion><xsl:text> ;&#10;&#09;</xsl:text>dct:hasVersion 	 	<xsl:text>&#60;</xsl:text><xsl:value-of select="."/><xsl:text>&#62;</xsl:text></dct:hasVersion>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>


<!-- her testes datafield mot marc 260 for publikasjonssted,utgiver & utgiverår-->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 260">
<!-- test subfield for code 'a'  -->
<!-- her må det først testes mot skilletegn for evt å dele opp i separate instanser -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="translate(., $safe_ascii, '') != ''">
						<xsl:choose>
							<xsl:when test="contains(.,';')">
								<xsl:call-template name="divide">
									<xsl:with-param name="string" select="."/>
									<xsl:with-param name="splitcharacter" select="';'"/>
									<xsl:with-param name="prefix" select="' ;&#10;&#09;pode:publicationPlace&#09;podeInstance:'"/>
									<xsl:with-param name="suffix" select="''"/>
								</xsl:call-template>
							</xsl:when>
							<xsl:otherwise>
								<geo:feature><xsl:text> ;&#10;&#09;</xsl:text>pode:publicationPlace	podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template></geo:feature>
							</xsl:otherwise>
						</xsl:choose>
						</xsl:if>
				</xsl:if>
<!-- test subfield for code 'b' 
	 dct:publisher -->				
				<xsl:if test="@code = 'b'">
					<!-- test for empty node before outputting content -->
					<!--<xsl:if test="translate(., $safe_ascii, '') != ''">-->
					<xsl:if test="translate(., translate(., $safe_ascii, ''), '') != ''">
					
						<dct:publisher><xsl:text> ;&#10;&#09;</xsl:text>dct:publisher 	 	podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template></dct:publisher>
					</xsl:if>
				</xsl:if>
				
<!-- test subfield for code 'c'  -->				
				<xsl:if test="@code = 'c'">
<!-- NB: xsd:int demands whole integer, thus translate away everything except the four first numbers -->
<!-- also test if content not returns empty -->
					<xsl:if test="substring(translate(.,translate(.,'0123456789',''),''), 1 ,4)">
						<dct:issued><xsl:text> ;&#10;&#09;</xsl:text>dct:issued		"<xsl:value-of select="substring(translate(.,translate(.,'0123456789',''),''), 1 ,4)"/>"^^xsd:int</dct:issued>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
		</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 300 $a,b,c,e for pode:physicalDescription -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 300">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a' or @code = 'b' or @code = 'c' or @code = 'e'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">				
				<pode:physicalDescription><xsl:text> ;&#10;&#09;</xsl:text>pode:physicalDescription	"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</pode:physicalDescription>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 440 $a for dct:isPartOf
		dette brukes om hovedforfatter
		instans lages som bibo:Series
		$v angir bibo:number
 -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 440 or @tag = 490">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="translate(., $safe_ascii, '') != ''">
						<dct:isPartOf><xsl:text> ;&#10;&#09;</xsl:text>dct:isPartOf 	 	podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template></dct:isPartOf>
					</xsl:if>
				</xsl:if>
<!-- test subfield for code 'v'  -->				
				<xsl:if test="@code = 'v'">
				<bibo:number><xsl:text> ;&#10;&#09;</xsl:text>bibo:number 	 	"<xsl:value-of select="."/>"^^xsd:string</bibo:number>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>


		
<!-- her testes datafield mot marc 500-574 (men ikke 571) $a for dct:description -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag &gt;= '499' and @tag &lt;= '575' and @tag != '571' and @tag != '520' and @tag != '525'">

			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">

					<xsl:if test="* | text()">				
				<dct:description><xsl:text> ;&#10;&#09;</xsl:text>dct:description		"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:description>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 520 $a for bibo:shortDescription -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = '520'">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">
				<bibo:shortDescription><xsl:text> ;&#10;&#09;</xsl:text>bibo:shortDescription		"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</bibo:shortDescription>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 525 $a for pode:physicalDescription -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = '525'">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">
				<pode:physicalDescription><xsl:text> ;&#10;&#09;</xsl:text>pode:physicalDescription		"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</pode:physicalDescription>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>
		
<!-- her testes datafield mot marc 571 $a for bibo:identifier -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = '571'">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">
				<bibo:identifier><xsl:text> ;&#10;&#09;</xsl:text>bibo:identifier		"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</bibo:identifier>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>
		
		
<!-- her testes datafield mot marc 600 $a & 630 $a,x & 650 $a,x & 690 $a,x for dct:subject
		instance lages som skos:Concept -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 600">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="translate(., $safe_ascii, '') != ''">		
						<dct:subject><xsl:text> ;&#10;&#09;</xsl:text>dct:subject 	 	topic:<xsl:call-template name="replaceUnwantedCharacters">
						<xsl:with-param name="stringIn" select="translate(., $uppercase, $lowercase)"/>
						</xsl:call-template></dct:subject>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
			
			<xsl:if test="@tag = 630 or @tag = 650 or @tag = 690 or @tag = 692 or @tag = 693 or @tag = 695 or @tag = 699">
<!-- test subfield for code 'x' 
	 in case of $x, generate:
	 dct:subject with joint concepts as object
	 instance topic: with joint concepts and skos:broader properties for individual concepts
 -->
			<xsl:choose>
				<xsl:when test="marc21slim:subfield[@code = 'x']">
			
					<dct:subject><xsl:text> ;&#10;&#09;dct:subject 	 	topic:</xsl:text>			
				<xsl:for-each select="marc21slim:subfield[@code = 'a']">
					<!-- test for empty node before outputting content -->
						<xsl:if test="* | text()">
							<xsl:call-template name="replaceUnwantedCharacters">
								<xsl:with-param name="stringIn" select="translate(., $uppercase, $lowercase)"/>
							</xsl:call-template>
						</xsl:if>
				</xsl:for-each>	
						
					<xsl:for-each select="marc21slim:subfield[@code = 'x']">
						<xsl:if test="* | text()">
							<xsl:text>__</xsl:text>
							<xsl:call-template name="replaceUnwantedCharacters">
								<xsl:with-param name="stringIn" select="translate(., $uppercase, $lowercase)"/>
							</xsl:call-template>
						</xsl:if>
					</xsl:for-each>
				</dct:subject>
				</xsl:when>

				<xsl:otherwise>
				<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="translate(., $safe_ascii, '') != ''">		
						<dct:subject><xsl:text> ;&#10;&#09;</xsl:text>dct:subject 	 	topic:<xsl:call-template name="replaceUnwantedCharacters">
						<xsl:with-param name="stringIn" select="translate(., $uppercase, $lowercase)"/>
						</xsl:call-template></dct:subject>
					</xsl:if>
				
				</xsl:if>
				</xsl:for-each>
				</xsl:otherwise>
			</xsl:choose>
			</xsl:if>
			
		</xsl:for-each> <!-- end 650/690  $a + $x -->
		
<!-- her testes datafield mot marc 650 & 690 $1 for pode:ddk
		instance lages som podeInstance:dewey -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 630 or @tag = 650 or @tag = 690 or @tag = 692 or @tag = 693 or @tag = 695 or @tag = 699">
<!-- test subfield for code '1'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = '1'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="translate(., translate(., '0123456789', ''), '') != ''">						
						<pode:ddk><xsl:text> ;&#10;&#09;</xsl:text>pode:ddk 	 	podeInstance:dewey_<xsl:value-of select="translate(., translate(., '0123456789', ''), '')"/></pode:ddk> 
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>

<!-- 655 $a : movie:genre
			instance -> movie:film_genre
			-->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 655">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for accepted characters before outputting content -->
					<xsl:if test="translate(., $safe_ascii, '') != ''">
						<movie:genre><xsl:text> ;&#10;&#09;</xsl:text>movie:genre 	 	genre:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template></movie:genre>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
		</xsl:if>
		</xsl:for-each>

<!-- Her testes datafield mot marc 700 og 740 for tittel --> 
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 700">
<!-- test subfield for code 't'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 't'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">
				<dct:title><xsl:text> ;&#10;&#09;</xsl:text>dct:title			"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:title>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 740">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">				
				<dct:title><xsl:text> ;&#10;&#09;</xsl:text>dct:title			"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:title>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 700 for roller -->
<!-- 245 $c inneholder sammendrag av roller
     700 $a - navn
	 700 $d - pode:lifespan
	 700 $e - rolle
	 700 $j - xfoaf:nationality

	 
antakelig må vi teste først etter 700 $e og legge inn rolle som property og uri som objekt
dermed må det gjøres en test mot mapping for rolle først, og deretter hentes person fra @code = 'a'
-->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 700">

			<xsl:for-each select=".">
<!-- test subfield for @code = 'e' against roles. Map against agent in @code = 'a'  -->
				<!-- NB! test for empty node in $a before outputting content -->
				<xsl:if test="translate(marc21slim:subfield[@code = 'a'], translate(marc21slim:subfield[@code = 'a'], $safe_ascii, ''), '') != ''">
				<!--<xsl:if test="translate(marc21slim:subfield[@code = 'a'], $safe_ascii, '') != ''">-->
				<xsl:choose>
					
					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'skuesp.'">
						<pode:actedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:actor		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:actedBy>
					</xsl:when>
					
					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'arr.'">
						<pode:arrangedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:arranger		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:arrangedBy>
					</xsl:when>

					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'bearb.'">
						<pode:reworkedBy><xsl:text> ;&#10;&#09;</xsl:text>dct:contributor		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:reworkedBy>
					</xsl:when>
					
					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'biogr.'">
						<pode:biografedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:biografer		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:biografedBy>
					</xsl:when>

					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'dir.'">
						<pode:conductedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:conductor		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:conductedBy>
					</xsl:when>

					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'fordord.'">
						<pode:introducedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:introducer		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:introducedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'forf')">
						<pode:writtenBy><xsl:text> ;&#10;&#09;</xsl:text>dct:creator		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:writtenBy>
					</xsl:when>
					
					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'foto')">
						<pode:photographedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:photographer		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:photographedBy>
					</xsl:when>
					
					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'gjendikt')">
						<pode:translatedBy><xsl:text> ;&#10;&#09;</xsl:text>bibo:translator		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:translatedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'ill') or starts-with(marc21slim:subfield[@code = 'e'], 'Ill')">
						<pode:illustratedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:illustrator		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:illustratedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'innl')">
						<pode:actedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:reader		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:actedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'komm')">
						<pode:commentedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:commentator		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:commentedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'komp')">
						<pode:composedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:composer		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:composedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'manus')">
						<pode:scriptedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:scriptWriter		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:scriptedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'medarb')">
						<pode:contributedBy><xsl:text> ;&#10;&#09;</xsl:text>dct:contributor		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:contributedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'medf') or starts-with(marc21slim:subfield[@code = 'e'], 'Medf')">
						<pode:contributedBy><xsl:text> ;&#10;&#09;</xsl:text>dct:creator		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:contributedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'overs')">
						<pode:translatedBy><xsl:text> ;&#10;&#09;</xsl:text>bibo:translator		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:translatedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'oppl')">
						<pode:narratedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:reader		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:narratedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'red') or starts-with(marc21slim:subfield[@code = 'e'], 'Red')">
						<pode:editedBy><xsl:text> ;&#10;&#09;</xsl:text>bibo:editor		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:editedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'reg')">
						<pode:directedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:director		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:directedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'rev')">
						<pode:revisedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:revisor		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:revisedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'sang') or starts-with(marc21slim:subfield[@code = 'e'], 'Sang')">
						<pode:sungBy><xsl:text> ;&#10;&#09;</xsl:text>pode:performer		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:sungBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'skues')">
						<pode:actedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:actor		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:actedBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'tekstf')">
						<pode:lyricsBy><xsl:text> ;&#10;&#09;</xsl:text>pode:lyricist		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:lyricsBy>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'utg')">
						<dct:publisher><xsl:text> ;&#10;&#09;</xsl:text>dct:publisher		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></dct:publisher>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'utøv')">
						<pode:performedBy><xsl:text> ;&#10;&#09;</xsl:text>pode:performer		podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template></pode:performedBy>
					</xsl:when>
																				
				</xsl:choose>
			</xsl:if>
			</xsl:for-each>
		</xsl:if>
		</xsl:for-each>

<!-- her testes datafield mot marc 730 for dct:alternative -->
		<xsl:for-each select="marc21slim:datafield">
			<xsl:if test="@tag = 730">
<!-- test subfield for code 'a'  -->
			<xsl:for-each select="marc21slim:subfield">
				<xsl:if test="@code = 'a'">
					<!-- test for empty node before outputting content -->
					<xsl:if test="* | text()">
						<dct:alternative><xsl:text> ;&#10;&#09;</xsl:text>dct:alternative 	 	"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:alternative>
					</xsl:if>
				</xsl:if>
			</xsl:for-each>
			</xsl:if>
		</xsl:for-each>


<!-- END OF TRIPLE SERIES, PERIOD AND DOUBLE LINEFEED -->
		<xsl:text> .&#10;&#10;</xsl:text>
	</xsl:template>

<!-- END COLLECTION TEMPLATE-->



<!-- START INSTANCE TEMPLATES -->

<!-- pode:publicationPlace -->
<!-- this one needs to use 'divide' template in cases of items separated with ; -->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = 260]/marc21slim:subfield[@code = 'a']">
	<xsl:for-each select=".">
	<!-- test for empty node before outputting content -->
	<xsl:if test="* | text()">
		<dct:uri>
		<xsl:choose>
			<xsl:when test="contains(.,';')">
				<xsl:call-template name="divide">
					<xsl:with-param name="string" select="."/>
					<xsl:with-param name="splitcharacter" select="';'"/>
					<xsl:with-param name="prefix" select="'podeInstance:'"/>
					<xsl:with-param name="suffix" select="'&#10;&#09;a&#09;geo:Feature ;&#10;&#09;geo:name&#09;&quot;&quot;&quot;$string&quot;&quot;&quot; .&#10;&#10;'"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<dct:uri>podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template></dct:uri>
				<xsl:text>&#10;&#09;</xsl:text>
				<rdf:type>a			geo:Feature ;</rdf:type>
				<dct:source><xsl:text>&#10;&#09;</xsl:text>geo:name		"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:source>
				<xsl:text> .&#10;&#10;</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
		</dct:uri>
		
	</xsl:if>
	</xsl:for-each>
	</xsl:template>
	
	
<!--marc 110: dct:creator as foaf:Organization -->
<!-- this one needs to use 'divide' template in cases of items separated with ; -->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = 110]/marc21slim:subfield[@code = 'a']">
	<xsl:for-each select=".">
	<!-- test for empty node before outputting content -->
	<xsl:if test="* | text()">
		<dct:uri>
		<xsl:choose>
			<xsl:when test="contains(.,';')">
				<xsl:call-template name="divide">
					<xsl:with-param name="string" select="."/>
					<xsl:with-param name="splitcharacter" select="';'"/>
					<xsl:with-param name="prefix" select="'podeInstance:'"/>
					<xsl:with-param name="suffix" select="'&#10;&#09;a&#09;foaf:Organization ;&#10;&#09;geo:name&#09;&quot;&quot;&quot;$string&quot;&quot;&quot; .&#10;&#10;'"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<dct:uri>podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template></dct:uri>
				<xsl:text>&#10;&#09;</xsl:text>
				<rdf:type>a			foaf:Organization ;</rdf:type>
				<dct:source><xsl:text>&#10;&#09;</xsl:text>foaf:name		"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:source>
				<xsl:text> .&#10;&#10;</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
		</dct:uri>
		
	</xsl:if>
	</xsl:for-each>
	</xsl:template>

<!--marc 655: genre instance as movie:film_genre -->
<!-- this one needs to use 'divide' template in cases of items separated with ; -->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = 655]/marc21slim:subfield[@code = 'a']">
	<xsl:for-each select=".">
	<!-- test for empty node before outputting content -->
	<xsl:if test="* | text()">
			<dct:uri>genre:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template></dct:uri>
				<xsl:text>&#10;&#09;</xsl:text>
				<rdf:type>a			movie:film_genre ;</rdf:type>
				<movie:film_genre_name><xsl:text>&#10;&#09;</xsl:text>movie:film_genre_name		"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</movie:film_genre_name>
				<xsl:text> .&#10;&#10;</xsl:text>
	</xsl:if>
	</xsl:for-each>
	</xsl:template>
	
<!--marc 710: dct:creator as foaf:Organization -->
<!-- this one needs to use 'divide' template in cases of items separated with ; -->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = 710]/marc21slim:subfield[@code = 'a']">
	<xsl:for-each select=".">
	<!-- test for empty node before outputting content -->
	<xsl:if test="* | text()">
		<dct:uri>
		<xsl:choose>
			<xsl:when test="contains(.,';')">
				<xsl:call-template name="divide">
					<xsl:with-param name="string" select="."/>
					<xsl:with-param name="splitcharacter" select="';'"/>
					<xsl:with-param name="prefix" select="'podeInstance:'"/>
					<xsl:with-param name="suffix" select="'&#10;&#09;a&#09;foaf:Organization ;&#10;&#09;geo:name&#09;&quot;&quot;&quot;$string&quot;&quot;&quot; .&#10;&#10;'"/>
				</xsl:call-template>
			</xsl:when>
			<xsl:otherwise>
				<dct:uri>podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template></dct:uri>
				<xsl:text>&#10;&#09;</xsl:text>
				<rdf:type>a			foaf:Organization ;</rdf:type>
				<dct:source><xsl:text>&#10;&#09;</xsl:text>foaf:name		"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:source>
				<xsl:text> .&#10;&#10;</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
		</dct:uri>
		
	</xsl:if>
	</xsl:for-each>
	</xsl:template>
	
<!-- dct:publisher -->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = 260]/marc21slim:subfield[@code = 'b']">
	<xsl:for-each select=".">
	<!-- test for empty node before outputting content -->
	<xsl:if test="translate(., translate(., $safe_ascii, ''), '') != ''">
	
		<dct:uri><xsl:text>podeInstance:</xsl:text>
		<xsl:call-template name="replaceUnwantedCharacters">
			<xsl:with-param name="stringIn" select="."/>
		</xsl:call-template>
		</dct:uri>
		<xsl:text>&#10;&#09;</xsl:text>
		<rdf:type>a			foaf:Organization ;</rdf:type>
		<dct:source><xsl:text>&#10;&#09;</xsl:text>foaf:name		"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:source>
	<xsl:text> .&#10;&#10;</xsl:text>
	</xsl:if>
	</xsl:for-each>
	</xsl:template>


<!-- lingvo:Lingvoj -->
	<xsl:template match="collection/marc21slim:record/marc21slim:controlfield[@tag = '008']">
		<xsl:if test="string-length(normalize-space(substring(., 36 ,3))) != 0">
			<dct:uri><xsl:text>podeInstance:</xsl:text>
			<xsl:value-of select="substring(., 36, 3)"/>
			</dct:uri>
			<xsl:text>&#10;&#09;</xsl:text>
			<lingvoj:Lingvo>a			lingvoj:Lingvo</lingvoj:Lingvo>
		<xsl:text> .&#10;&#10;</xsl:text>
		</xsl:if>
	</xsl:template>

<!-- foaf:Person - from 100 $a-->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = 100]">
	<xsl:for-each select=".">
	<!-- test for empty node before outputting content, otherwise turtle will break -->
		<xsl:if test="marc21slim:subfield[@code = 'a']">
			<xsl:if test="* | text()">	
				<dct:uri><xsl:text>podeInstance:</xsl:text>
				<xsl:call-template name="replaceUnwantedCharacters">
				<xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/>
				</xsl:call-template>
			</dct:uri>
			<xsl:text>&#10;&#09;</xsl:text>
			<rdf:type>a			foaf:Person ;</rdf:type>
			<foaf:name><xsl:text>&#10;&#09;</xsl:text>foaf:name		"""<xsl:value-of select="translate(marc21slim:subfield[@code = 'a'], '&quot;','')"/>"""</foaf:name>
			</xsl:if>
			<xsl:if test="marc21slim:subfield[@code = 'b']">
				<bibo:suffixName><xsl:text> ;&#10;&#09;</xsl:text>bibo:suffixName 	 "<xsl:value-of select="marc21slim:subfield[@code = 'd']"/>"^^xsd:string</bibo:suffixName>
			</xsl:if>
			<xsl:if test="marc21slim:subfield[@code = 'c']">
				<foaf:title><xsl:text> ;&#10;&#09;</xsl:text>foaf:title 	 "<xsl:value-of select="marc21slim:subfield[@code = 'd']"/>"^^xsd:string</foaf:title>
			</xsl:if>
			<xsl:if test="marc21slim:subfield[@code = 'd']">
				<pode:lifespan><xsl:text> ;&#10;&#09;</xsl:text>pode:lifespan 	 "<xsl:value-of select="marc21slim:subfield[@code = 'd']"/>"^^xsd:string</pode:lifespan>
			</xsl:if>

			<xsl:if test="marc21slim:subfield[@code = 'j']">
				<xfoaf:nationality><xsl:text> ;&#10;&#09;</xsl:text>xfoaf:nationality	"<xsl:value-of select="marc21slim:subfield[@code = 'j']"/>"^^xsd:string</xfoaf:nationality>
			</xsl:if>
			<xsl:text> .&#10;&#10;</xsl:text>
		</xsl:if>
	</xsl:for-each>
	</xsl:template>
<!-- END foaf:Person - from 100 $a-->

	
<!-- skos:Concept - from 600 $a
	instance is skos:Concept, rest is skos:definition
-->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = 600]">
	<xsl:for-each select=".">
	<!-- test for empty node before outputting content, otherwise turtle will break -->
	
		<xsl:if test="marc21slim:subfield[@code = 'a']">
			<xsl:if test="* | text()">	
				<dct:uri><xsl:text>topic:</xsl:text>
				<xsl:call-template name="replaceUnwantedCharacters">
				<xsl:with-param name="stringIn" select="translate(marc21slim:subfield[@code = 'a'], $uppercase, $lowercase)"/>
				</xsl:call-template>
			</dct:uri>
			<xsl:text>&#10;&#09;</xsl:text>
			<rdf:type>a			skos:Concept ;</rdf:type>
			<skos:prefLabel><xsl:text>&#10;&#09;</xsl:text>skos:prefLabel		"""<xsl:value-of select="translate(marc21slim:subfield[@code = 'a'], '&quot;','')"/>"""</skos:prefLabel>
			</xsl:if>		
			<foaf:focus>
				<xsl:text> ;&#10;&#09;</xsl:text>foaf:focus		person:<xsl:call-template name="replaceUnwantedCharacters">
				<xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/>
				</xsl:call-template>
			</foaf:focus>
			<xsl:text> .&#10;&#10;</xsl:text>
			<!-- end topic instance, start new instance for person using foaf:focus -->
			
		<dct:uri><xsl:text>person:</xsl:text>
				<xsl:call-template name="replaceUnwantedCharacters">
				<xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/>
				</xsl:call-template>
			</dct:uri>
			<xsl:text>&#10;&#09;</xsl:text>
			<rdf:type>a			foaf:Person ;</rdf:type>
			<foaf:name><xsl:text>&#10;&#09;</xsl:text>foaf:name		"""<xsl:value-of select="translate(marc21slim:subfield[@code = 'a'], '&quot;','')"/>"""</foaf:name>

			<xsl:if test="marc21slim:subfield[@code = 'b']">
				<bibo:suffixName><xsl:text> ;&#10;&#09;</xsl:text>bibo:suffixName 	 "<xsl:value-of select="marc21slim:subfield[@code = 'd']"/>"^^xsd:string</bibo:suffixName>
			</xsl:if>
			<xsl:if test="marc21slim:subfield[@code = 'c']">
				<foaf:title><xsl:text> ;&#10;&#09;</xsl:text>foaf:title 	 "<xsl:value-of select="marc21slim:subfield[@code = 'd']"/>"^^xsd:string</foaf:title>
			</xsl:if>
			<xsl:if test="marc21slim:subfield[@code = 'd']">
				<pode:lifespan><xsl:text> ;&#10;&#09;</xsl:text>pode:lifespan 	 "<xsl:value-of select="marc21slim:subfield[@code = 'd']"/>"^^xsd:string</pode:lifespan>
			</xsl:if>

			<xsl:if test="marc21slim:subfield[@code = 'j']">
				<xfoaf:nationality><xsl:text> ;&#10;&#09;</xsl:text>xfoaf:nationality	"<xsl:value-of select="marc21slim:subfield[@code = 'j']"/>"^^xsd:string</xfoaf:nationality>
			</xsl:if>
			<xsl:text> .&#10;&#10;</xsl:text> <!-- end foaf:Person instance from foaf:focus -->
		</xsl:if>
	</xsl:for-each>
	</xsl:template>
<!-- END skos:Concept - from 600 $a-->			
		
<!-- skos:Concept 
 	 topic: from $a & $x
 	 podeInstance:dewey_ from $1
@tag = 630 or @tag = 650 or @tag = 690 or @tag = 692 or @tag = 693 or @tag = 695 or @tag = 699
		sublima:classification - from 650/690 $1 -->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = 630] | collection/marc21slim:record/marc21slim:datafield[@tag = 650] | collection/marc21slim:record/marc21slim:datafield[@tag = 690] | collection/marc21slim:record/marc21slim:datafield[@tag = 692] | collection/marc21slim:record/marc21slim:datafield[@tag = 693] | collection/marc21slim:record/marc21slim:datafield[@tag = 695] | collection/marc21slim:record/marc21slim:datafield[@tag = 699]">
	<xsl:for-each select=".">
	<!-- test for empty node before outputting content, otherwise turtle will break -->
		<xsl:choose> 
		<xsl:when test="marc21slim:subfield[@code = 'x']">
			<xsl:if test="* | text()">	
			<dct:uri><xsl:text>topic:</xsl:text>
			<!-- topic uri generated from 650 $a & $x -->
					<xsl:for-each select="marc21slim:subfield[@code = 'a']">
					<!-- test for empty node before outputting content -->
						<xsl:if test="* | text()">
							<xsl:call-template name="replaceUnwantedCharacters">
								<xsl:with-param name="stringIn" select="translate(., $uppercase, $lowercase)"/>
							</xsl:call-template>
						</xsl:if>
					</xsl:for-each>	
						
					<xsl:for-each select="marc21slim:subfield[@code = 'x']">
						<xsl:if test="* | text()">
							<xsl:text>__</xsl:text>
							<xsl:call-template name="replaceUnwantedCharacters">
								<xsl:with-param name="stringIn" select="translate(., $uppercase, $lowercase)"/>
							</xsl:call-template>
						</xsl:if>
					</xsl:for-each>
			</dct:uri>
			<xsl:text>&#10;&#09;</xsl:text>
			<rdf:type>a			skos:Concept</rdf:type>

			<xsl:for-each select="marc21slim:subfield[@code = 'a'] | marc21slim:subfield[@code = 'x']">
			<skos:broader>
				<xsl:text> ; &#10;&#09;</xsl:text>skos:broader		topic:<xsl:call-template name="replaceUnwantedCharacters">
				<xsl:with-param name="stringIn" select="translate(., $uppercase, $lowercase)"/>
				</xsl:call-template>
			</skos:broader>
			</xsl:for-each>

			<!-- create prefLabel from joint $a & $x -->
			<xsl:for-each select="marc21slim:subfield[@code = 'a']">
			<xsl:if test="* | text()">
			<skos:prefLabel>
			<xsl:text> ; &#10;&#09;skos:prefLabel		"""</xsl:text>
				<xsl:value-of select="."/>
				
				<xsl:for-each select="../marc21slim:subfield[@code = 'x']">
				<xsl:text> - </xsl:text>
				<xsl:value-of select="."/>
				</xsl:for-each>			
			<xsl:text>"""</xsl:text>
			</skos:prefLabel>
			</xsl:if>
			</xsl:for-each>

			<xsl:for-each select="marc21slim:subfield[@code = '1']">
				<xsl:text>; &#10;&#09;</xsl:text>pode:ddk		podeInstance:dewey_<xsl:value-of select="translate(., translate(., '0123456789', ''), '')"/>
			</xsl:for-each>
			
			<xsl:text> .&#10;&#10;</xsl:text>
			
			<!-- also create instances of type skos:Concept for previous skos:broader -->
			<xsl:for-each select="marc21slim:subfield[@code = 'a'] | marc21slim:subfield[@code = 'x']">
			<dct:uri><xsl:text>topic:</xsl:text>
				<xsl:call-template name="replaceUnwantedCharacters">
				<xsl:with-param name="stringIn" select="translate(., $uppercase, $lowercase)"/>
				</xsl:call-template>
				<xsl:text>&#10;&#09;</xsl:text>
				<rdf:type>a			skos:Concept</rdf:type>
				
				<!-- skos:prefLabel -->
				<skos:prefLabel>
				<xsl:text> ; &#10;&#09;skos:prefLabel		"""</xsl:text>
				<xsl:value-of select="."/><xsl:text>"""</xsl:text>
				</skos:prefLabel>
			
				<xsl:text> .&#10;&#10;</xsl:text>
			</dct:uri>
			</xsl:for-each>
			
			</xsl:if>
		</xsl:when>
		<xsl:otherwise>
			<xsl:if test="* | text()">	
				<dct:uri><xsl:text>topic:</xsl:text>
				<xsl:call-template name="replaceUnwantedCharacters">
				<xsl:with-param name="stringIn" select="translate(marc21slim:subfield[@code = 'a'], $uppercase, $lowercase)"/>
				</xsl:call-template>
			</dct:uri>
			<xsl:text>&#10;&#09;</xsl:text>
			<rdf:type>a			skos:Concept</rdf:type>
			
			<!-- skos:prefLabel -->
			<skos:prefLabel>
			<xsl:text> ; &#10;&#09;skos:prefLabel		"""</xsl:text>
				<xsl:value-of select="marc21slim:subfield[@code = 'a']"/><xsl:text>"""</xsl:text>
			</skos:prefLabel>
			
			<!-- pode:ddk -->
			<xsl:for-each select="marc21slim:subfield[@code = '1']">
				<xsl:text>; &#10;&#09;</xsl:text>pode:ddk		podeInstance:dewey_<xsl:value-of select="translate(., translate(., '0123456789', ''), '')"/>
			</xsl:for-each>
			
			<xsl:text> .&#10;&#10;</xsl:text>
			</xsl:if>
		</xsl:otherwise>
		</xsl:choose>
		
		<xsl:if test="marc21slim:subfield[@code = '1']">
			<xsl:if test="* | text()">	
				<dct:uri><xsl:text>podeInstance:dewey_</xsl:text>
				<xsl:value-of select="translate(marc21slim:subfield[@code = '1'], translate(marc21slim:subfield[@code = '1'], '0123456789', ''), '')"/>
			</dct:uri>
			<xsl:text>&#10;&#09;</xsl:text>
			<rdf:type>a			pode:DDKCode</rdf:type>
			<xsl:text> .&#10;&#10;</xsl:text>
			</xsl:if>
		</xsl:if>
	</xsl:for-each>
	</xsl:template>
<!-- END skos:Concept - from 650 $a-->			

<!-- dct:hasPart from 700 $t -->
<!-- instances for series from 700 & 710 $t -->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = 700]/marc21slim:subfield[@code = 't'] | collection/marc21slim:record/marc21slim:datafield[@tag = 710]/marc21slim:subfield[@code = 't']">
		<xsl:for-each select=".">		
	<!-- test for empty node before outputting content -->
				<xsl:if test="* | text()">	
				<dct:uri><xsl:text>deichman:</xsl:text><xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="."/></xsl:call-template>
				</dct:uri>
					<xsl:text>&#10;&#09;</xsl:text>
					<dct:hasPart>a			bibo:DocumentPart</dct:hasPart>
					<dct:title><xsl:text>; &#10;&#09;</xsl:text>dct:title			"""<xsl:value-of select="translate(translate(., '&quot;',''),'&amp;','')"/>"""</dct:title>
				
					<!-- print out dct:creator from 700/710 $a -->
					<xsl:if test="../marc21slim:subfield[@code = 'a']">
						<!-- test for accepted characters before outputting content -->
						<xsl:if test="translate(., $safe_ascii, '') != ''">
							<dct:creator><xsl:text> ;&#10;&#09;</xsl:text>dct:creator 	 	podeInstance:<xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="../marc21slim:subfield[@code = 'a']"/></xsl:call-template></dct:creator>
						</xsl:if>
					</xsl:if>
				
					<xsl:text> .&#10;&#10;</xsl:text>
				</xsl:if>	
			</xsl:for-each>
	</xsl:template>

			
<!-- foaf:Person - from 700 $a-->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = 700]">
	<xsl:for-each select=".">
	<!-- test for empty node in $a before outputting any content, otherwise turtle will break -->
	<xsl:if test="translate(marc21slim:subfield[@code = 'a'], translate(marc21slim:subfield[@code = 'a'], $safe_ascii, ''), '') != ''">
		<!--<xsl:if test="marc21slim:subfield[@code = 'a']">-->
		<!--	<xsl:if test="translate(., translate(., $safe_ascii, ''), '') != ''">-->
		
			
			<!--<xsl:if test="* | text()">	-->
				<dct:uri><xsl:text>podeInstance:</xsl:text>
				<xsl:call-template name="replaceUnwantedCharacters">
				<xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/>
				</xsl:call-template>
			</dct:uri>
			<xsl:text>&#10;&#09;</xsl:text>
			<rdf:type>a			foaf:Person ;</rdf:type>
			<foaf:name><xsl:text>&#10;&#09;</xsl:text>foaf:name		"""<xsl:value-of select="translate(marc21slim:subfield[@code = 'a'], '&quot;','')"/>"""</foaf:name>
			
			<xsl:if test="marc21slim:subfield[@code = 'b']">
				<bibo:suffixName><xsl:text> ;&#10;&#09;</xsl:text>bibo:suffixName 	 "<xsl:value-of select="marc21slim:subfield[@code = 'd']"/>"^^xsd:string</bibo:suffixName>
			</xsl:if>
			<xsl:if test="marc21slim:subfield[@code = 'c']">
				<foaf:title><xsl:text> ;&#10;&#09;</xsl:text>foaf:title 	 "<xsl:value-of select="marc21slim:subfield[@code = 'd']"/>"^^xsd:string</foaf:title>
			</xsl:if>
					
			<xsl:if test="marc21slim:subfield[@code = 'd']">
			<pode:lifespan><xsl:text> ;&#10;&#09;</xsl:text>pode:lifespan 	 "<xsl:value-of select="marc21slim:subfield[@code = 'd']"/>"^^xsd:string</pode:lifespan>
			</xsl:if>

			<xsl:if test="marc21slim:subfield[@code = 'j']">
			<xfoaf:nationality><xsl:text> ;&#10;&#09;</xsl:text>xfoaf:nationality	"<xsl:value-of select="marc21slim:subfield[@code = 'j']"/>"^^xsd:string</xfoaf:nationality>
			</xsl:if>

<!-- check for role(s) -->
		

			<xsl:if test="marc21slim:subfield[@code = 'e']">		
				

				<xsl:choose>
					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'skuesp.'">
						<pode:actorOf><xsl:text> ;&#10;&#09;</xsl:text>pode:actorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:actorOf>
					</xsl:when>
					
					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'arr.'">
						<pode:arrangerOf><xsl:text> ;&#10;&#09;</xsl:text>pode:arrangerOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:arrangerOf>
					</xsl:when>

					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'bearb.'">
						<dct:contributorOf><xsl:text> ;&#10;&#09;</xsl:text>dct:contributorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></dct:contributorOf>
					</xsl:when>
					
					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'biogr.'">
						<pode:biograferOf><xsl:text> ;&#10;&#09;</xsl:text>pode:biograferOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:biograferOf>
					</xsl:when>

					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'dir.'">
						<pode:conductorOf><xsl:text> ;&#10;&#09;</xsl:text>pode:conductorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:conductorOf>
					</xsl:when>

					<xsl:when test="marc21slim:subfield[@code = 'e'] = 'fordord.'">
						<pode:introducerOf><xsl:text> ;&#10;&#09;</xsl:text>pode:introducerOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:introducerOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'forf')">
						<dct:creatorOf><xsl:text> ;&#10;&#09;</xsl:text>dct:creatorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></dct:creatorOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'foto')">
						<pode:photograferOf><xsl:text> ;&#10;&#09;</xsl:text>pode:photograferOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:photograferOf>
					</xsl:when>
					
					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'gjendikt')">
						<bibo:translatorOf><xsl:text> ;&#10;&#09;</xsl:text>bibo:translatorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></bibo:translatorOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'ill') or starts-with(marc21slim:subfield[@code = 'e'], 'Ill')">
						<pode:illustratorOf><xsl:text> ;&#10;&#09;</xsl:text>pode:illustratorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:illustratorOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'innl')">
						<pode:readerOf><xsl:text> ;&#10;&#09;</xsl:text>pode:readerOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:readerOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'komm')">
						<pode:commenterOf><xsl:text> ;&#10;&#09;</xsl:text>pode:commenterOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:commenterOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'komp')">
						<pode:composerOf><xsl:text> ;&#10;&#09;</xsl:text>pode:composerOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:composerOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'manus')">
						<pode:scriptwriterOf><xsl:text> ;&#10;&#09;</xsl:text>pode:scriptWriterOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:scriptwriterOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'medarb')">
						<dct:contributorOf><xsl:text> ;&#10;&#09;</xsl:text>dct:contributorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></dct:contributorOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'medf') or starts-with(marc21slim:subfield[@code = 'e'], 'Medf')">
						<dct:creatorOf><xsl:text> ;&#10;&#09;</xsl:text>dct:creatorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></dct:creatorOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'overs')">
						<bibo:translatorOf><xsl:text> ;&#10;&#09;</xsl:text>bibo:translatorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></bibo:translatorOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'oppl')">
						<pode:readerOf><xsl:text> ;&#10;&#09;</xsl:text>pode:readerOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:readerOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'red') or starts-with(marc21slim:subfield[@code = 'e'], 'Red')">
						<bibo:editorOf><xsl:text> ;&#10;&#09;</xsl:text>bibo:editorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></bibo:editorOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'reg')">
						<pode:directorOf><xsl:text> ;&#10;&#09;</xsl:text>pode:directorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:directorOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'rev')">
						<pode:revisorOf><xsl:text> ;&#10;&#09;</xsl:text>pode:revisorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:revisorOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'sang') or starts-with(marc21slim:subfield[@code = 'e'], 'Sang')">
						<pode:performerOf><xsl:text> ;&#10;&#09;</xsl:text>pode:performerOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:performerOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'skues')">
						<pode:actorOf><xsl:text> ;&#10;&#09;</xsl:text>pode:actorOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:actorOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'tekstf')">
						<pode:lyricistOf><xsl:text> ;&#10;&#09;</xsl:text>pode:lyricistOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:lyricistOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'utg')">
						<dct:publisherOf><xsl:text> ;&#10;&#09;</xsl:text>dct:publisherOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></dct:publisherOf>
					</xsl:when>

					<xsl:when test="starts-with(marc21slim:subfield[@code = 'e'], 'utøv')">
						<pode:performerOf><xsl:text> ;&#10;&#09;</xsl:text>pode:performerOf		<xsl:text>&#60;</xsl:text><xsl:value-of select="../marc21slim:datafield[@tag = 996]/marc21slim:subfield[@code = 'u']"/><xsl:text>&#62;</xsl:text></pode:performerOf>
					</xsl:when>
				</xsl:choose>		
		</xsl:if>																		



<!-- end check for roles -->							
		<xsl:text> .&#10;&#10;</xsl:text>
	</xsl:if>
	</xsl:for-each>
	</xsl:template>
<!-- end foaf:Person -->

<!-- pode:ddkFirst -->
<!-- her lages instanser for klassifisering -->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = '082']/marc21slim:subfield[@code = 'a']">
		<xsl:for-each select=".">
	<!-- test for empty node before outputting content -->
			<xsl:if test="* | text()">
				
		<!-- Top level -->	
				<pode:ddkFirst><xsl:text>podeInstance:DDK_</xsl:text><xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,1)"/>
				</pode:ddkFirst>
				
				<xsl:text>&#10;&#09;</xsl:text>
					<rdf:type>a			skos:Concept</rdf:type>
				
				<dct:isVersionOf><xsl:text> ;&#10;&#09;</xsl:text>dct:isVersionOf		<xsl:text>&#60;http://dewey.info/class/</xsl:text><xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,1)"/><xsl:text>/&#62;</xsl:text></dct:isVersionOf>
				
				<xsl:text> .&#10;&#10;</xsl:text>
			
		<!-- Second level -->	
				<pode:ddkSecond><xsl:text>podeInstance:DDK_</xsl:text><xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,2)"/>
				</pode:ddkSecond>
				
				<xsl:text>&#10;&#09;</xsl:text>
					<rdf:type>a			skos:Concept</rdf:type>
				
				<dct:isVersionOf><xsl:text> ;&#10;&#09;</xsl:text>dct:isVersionOf		<xsl:text>&#60;http://dewey.info/class/</xsl:text><xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,2)"/><xsl:text>/&#62;</xsl:text></dct:isVersionOf>
				
				<skos:broader><xsl:text> ;&#10;&#09;</xsl:text>skos:broader		podeInstance:DDK_<xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,1)"/></skos:broader>
				
				<xsl:text> .&#10;&#10;</xsl:text>

		<!-- Third level -->	
				<pode:ddkSecond><xsl:text>podeInstance:DDK_</xsl:text><xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,3)"/>
				</pode:ddkSecond>
				
				<xsl:text>&#10;&#09;</xsl:text>
					<rdf:type>a			skos:Concept</rdf:type>
				
				<dct:isVersionOf><xsl:text> ;&#10;&#09;</xsl:text>dct:isVersionOf		<xsl:text>&#60;http://dewey.info/class/</xsl:text><xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,3)"/><xsl:text>/&#62;</xsl:text></dct:isVersionOf>

				<skos:broader><xsl:text> ;&#10;&#09;</xsl:text>skos:broader		podeInstance:DDK_<xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,2)"/></skos:broader>


				<xsl:text> .&#10;&#10;</xsl:text>
				
		<!-- Full throttle -->	
				<!-- The full dewey -->
				<xsl:if test="string-length(translate(., translate(., '0123456789', ''), '')) &gt; 3">
				<dct:uri>podeInstance:DDK_<xsl:value-of select="translate(., translate(., '0123456789', ''), '')"/></dct:uri>
				
				<xsl:text>&#10;&#09;</xsl:text>
					<rdf:type>a			skos:Concept</rdf:type>
				
				<skos:broader><xsl:text> ;&#10;&#09;</xsl:text>skos:broader		podeInstance:DDK_<xsl:value-of select="substring(translate(., translate(., '0123456789', ''), ''),1,3)"/></skos:broader>

				<xsl:text> .&#10;&#10;</xsl:text>
				</xsl:if>
			</xsl:if>
		</xsl:for-each>
	</xsl:template>
	
	
<!-- bibo:Series -->
<!-- her lages instanser for serier fra 440 og 490 $a -->
	<xsl:template match="collection/marc21slim:record/marc21slim:datafield[@tag = 440] | collection/marc21slim:record/marc21slim:datafield[@tag = 490]">
		<xsl:if test="marc21slim:subfield[@code = 'a']">
		<xsl:for-each select=".">		
			<xsl:if test="marc21slim:subfield[@code = 'a']">
	<!-- test for empty node before outputting content -->
				<xsl:if test="* | text()">	
				<dct:uri><xsl:text>podeInstance:</xsl:text><xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="marc21slim:subfield[@code = 'a']"/></xsl:call-template>
				</dct:uri>
					<xsl:text>&#10;&#09;</xsl:text>
					<bibo:Series>a			bibo:Series</bibo:Series>
					<dct:title><xsl:text>; &#10;&#09;</xsl:text>dct:title			"""<xsl:value-of select="translate(translate(marc21slim:subfield[@code = 'a'], '&quot;',''),'&amp;','')"/>"""</dct:title>
				</xsl:if>
			</xsl:if>
			
			<xsl:if test="marc21slim:subfield[@code = 'x']">
					<bibo:issn><xsl:text>; &#10;&#09;</xsl:text>bibo:issn			"<xsl:value-of select="marc21slim:subfield[@code = 'x']"/>"^^xsd:string</bibo:issn>
			</xsl:if>
					<xsl:text> .&#10;&#10;</xsl:text>
					
			</xsl:for-each>
			</xsl:if>
	</xsl:template>
	


<!-- END INSTANCE TEMPLATES -->

<!-- STRING MANAGEMENT TEMPLATES -->

<!-- string replace 'æ' 'ø' 'å' etc. and after strip out unwanted characters, also remove any initial digit for consistent turtle 
	INPUT PARAMETERS 
	stringIn	input string to process
-->

<xsl:template name="replaceUnwantedCharacters">
		  <xsl:param name="stringIn"/>
		  
		  <xsl:variable name="replacedChars" select="translate(translate(translate(translate(translate(translate(translate(translate(translate(translate(translate(translate($stringIn,'æ','ae'),'Æ','Ae'),'ø','oe'),'Ø','Oe'),'å','aa'),'Å','Aa'),' \,','__'),'âãäàá','aaaaa'),'êẽëèé','eeeee'),'îĩïìí','iiiii'),'ûũüùú','uuuuu'),'õöòóô','ooooo')"/>
		  <!--<xsl:variable name="first" select="substring($stringIn, 1, 1 )"/> -->
		  <xsl:variable name="first" select="substring(translate($replacedChars, translate($replacedChars, $safe_ascii, ''), ''), 1, 1 )"/>
		  
		<!-- removed for consistent turtle		
  		<xsl:value-of select="translate($replacedChars, translate($replacedChars, $valid_first_char, ''), '')" />
		-->
		
		<!-- test if first character AFTER replaceUnwantedCharacters is digit or -, and add 'x' if so -->
	<xsl:if test="translate($first, '-0123456789', '') = ''">
			<xsl:text>x</xsl:text>
	</xsl:if>
	
	<xsl:value-of select="translate($replacedChars, translate($replacedChars, $safe_ascii, ''), '')" />
  
</xsl:template>



<!-- template for splitting up multilanguage strings in field 041
	INPUT PARAMETERS 
	string		input string to process
	position 	position of character to start
	prefix 	string for prefix output for predicate and object ( ;&#10;&#09; is for now printed out in template)
	splitcharnumber number of characters in each source segment
--> 
	<xsl:template name="splitstring">
			<xsl:param name="position"/>
			<xsl:param name="string"/>
			<xsl:param name="prefix"/>
			<xsl:param name="suffix"/>
			<xsl:param name="splitcharnumber"/>
				
<!-- test if end of string, if not, recursive -->
				<xsl:if test="$position &lt;= string-length($string)">

<!-- parse exceptions first -->
<!-- language mapping: iso to lexvo -->
				<xsl:choose>
				<xsl:when test="substring($string, $position, 3) = 'alb'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>sqi</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'arm'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>hye</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'bur'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>mya</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'cat'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>kat</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'chi'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>zho</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'cze'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>ces</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'dar'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>prs</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'dut'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>nld</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'fre'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>fra</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'ger'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>deu</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'gre'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>ell</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'ice'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>isl</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'kku'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>kmr</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'kso'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>ckb</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'mac'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>mkd</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'per'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>fas</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'rum'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>ron</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'scc'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>srp</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'scr'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>hrv</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'slo'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>slk</xsl:text>
				</xsl:when>

				<xsl:when test="substring($string, $position, 3) = 'tag'">
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:text>tgl</xsl:text>
				</xsl:when>

<!-- ignore occurrences of 'mul' in tag=008 -->				
				<xsl:when test="substring($string, $position, 3) = 'mul'">
				</xsl:when>
				
	
<!-- no exception - map directly -->				
				<xsl:otherwise>
				<xsl:text> ;&#10;&#09;</xsl:text><xsl:value-of select="$prefix"/><xsl:value-of select="substring($string, $position, $splitcharnumber)"/>
				</xsl:otherwise>
				
<!-- end exception mapping -->
				</xsl:choose>
				
				
<!--				<dct:language><xsl:value-of select="$prefix"/><xsl:value-of select="substring($string, $position, $splitcharnumber)"/><xsl:value-of select="$suffix"/></dct:language>
-->
					<xsl:call-template name="splitstring">
						<xsl:with-param name="string" select="$string"/>
						<xsl:with-param name="position" select="$position + $splitcharnumber"/>
						<xsl:with-param name="prefix" select="$prefix"/>
						<xsl:with-param name="suffix" select="$suffix"/>
						<xsl:with-param name="splitcharnumber" select="$splitcharnumber"/>
					</xsl:call-template>
				
				</xsl:if>
	</xsl:template>
	

<!-- template to divide comma-separated values 
    NB: the produced string is recursed through template 'replaceUnwantedCharacters' to make sure instance becomes valid turtle
	
	INPUT PARAMETERS 
	string			input string to process
	prefix 		string for prefix output for predicate and object
	suffix 		optional string for suffix output in case of instance processing
	splitcharacter	character(s) to interpret as delimiter
--> 
 <xsl:template name="divide">
	<xsl:param name="string"/>
	<xsl:param name="splitcharacter"/>
	<xsl:param name="prefix"/>
	<xsl:param name="suffix"/>
		<xsl:choose>
			<xsl:when test="contains($string,$splitcharacter)">
	    <!-- Select the first value to process -->
              <dct:format><xsl:value-of select="$prefix"/><xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="substring-before($string,$splitcharacter)"/></xsl:call-template><xsl:value-of select="$suffix"/></dct:format>
            <!-- Recurse with remainder of string -->
				<xsl:call-template name="divide">
					<xsl:with-param name="string" select="substring-after($string,$splitcharacter)"/>
					<xsl:with-param name="prefix" select="$prefix"/>
					<xsl:with-param name="splitcharacter" select="$splitcharacter" />
					<xsl:with-param name="suffix" select="$suffix" />
				</xsl:call-template>
			</xsl:when>
			<!-- This is the last value so we don't recurse -->
			<xsl:otherwise>
				<dct:format><xsl:value-of select="$prefix"/><xsl:call-template name="replaceUnwantedCharacters"><xsl:with-param name="stringIn" select="$string"/></xsl:call-template><xsl:value-of select="$suffix"/></dct:format>
			</xsl:otherwise>
		</xsl:choose>
 </xsl:template>	
		
</xsl:stylesheet>
