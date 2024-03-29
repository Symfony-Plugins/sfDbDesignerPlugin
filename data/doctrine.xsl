<?xml version="1.0" ?>

<!--

DB Designer XML to Doctrine Schema YML

This XSL template is stolen from the propel converter written by Jonathan Graham 
(http://blog.tooleshed.com/?p=6), but i will port it more and more directly to 
doctrine.

@version 0.0.1
@author Thomas Boerger <tb@mosez.net>
@author Jonathan Graham <jkgraham@gmail.com>

-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  
  <xsl:output method="xml" version="1.0" encoding="UTF-8" indent="yes" />
  <xsl:strip-space elements="*" />

  <!-- ======================================================================= -->
  <!-- DATABASE template -->
  <!-- ======================================================================= -->
  <xsl:template match="/">
    <database defaultIdMethod="native">
      <xsl:attribute name="name">
        <xsl:value-of select="/DBMODEL/SETTINGS/GLOBALSETTINGS/@ModelName" />
      </xsl:attribute>

      <xsl:apply-templates />
    </database>
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- TABLES template -->
  <!-- ======================================================================= -->
  <xsl:template match="/DBMODEL/METADATA/TABLES/TABLE">
    <table>
      <xsl:attribute name="name">
        <xsl:value-of select="@Tablename" />
      </xsl:attribute>

      <xsl:if test="@Comments != ''">
        <xsl:attribute name="description">
          <xsl:value-of select="@Comments" />
        </xsl:attribute>
      </xsl:if>

      <xsl:apply-templates />
    </table>
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- COLUMNS template -->
  <!-- ======================================================================= -->
  <xsl:template match="COLUMNS/COLUMN">
    <column>
      <!-- get data type -->
      <xsl:variable name="datatype">
        <xsl:call-template name="get_datatype">
          <xsl:with-param name="id">
            <xsl:value-of select="@idDatatype" />
          </xsl:with-param>
        </xsl:call-template>
      </xsl:variable>
                
      <!-- remove parents from datatypeparams -->
      <xsl:variable name="dtpclean">
        <xsl:call-template name="clean_dataparams">
          <xsl:with-param name="dtp">
            <xsl:value-of select="@DatatypeParams" />
          </xsl:with-param>
        </xsl:call-template>
      </xsl:variable>

      <!-- name -->
      <xsl:attribute name="name">
        <xsl:value-of select="@ColName" />
      </xsl:attribute>
                
      <!-- type -->
      <xsl:attribute name="type">
        <xsl:choose>
          <xsl:when test="$datatype = 'ENUM'">
            <xsl:value-of select="'CHAR'" />
          </xsl:when>

          <xsl:otherwise>
            <xsl:value-of select="$datatype" />
          </xsl:otherwise>
        </xsl:choose>
      </xsl:attribute>

      <xsl:if test="$dtpclean != ''">
        <!-- size --> 
        <xsl:attribute name="size">
          <xsl:call-template name="get_datasize">
            <xsl:with-param name="dtpc">
              <xsl:value-of select="$dtpclean" />
            </xsl:with-param>

            <xsl:with-param name="dtype">
              <xsl:value-of select="$datatype" />
            </xsl:with-param>
          </xsl:call-template>
        </xsl:attribute>

        <xsl:if test="contains('FLOAT,DOUBLE,DECIMAL',$datatype)">
          <!-- scale --> 
          <xsl:attribute name="scale">
            <xsl:value-of select="substring-after($dtpclean,',')"/>
          </xsl:attribute>
        </xsl:if>
      </xsl:if>
                                
      <!-- primaryKey -->
      <xsl:if test="@PrimaryKey = '1'">
        <xsl:attribute name="primaryKey">true</xsl:attribute>
      </xsl:if>
                
      <!-- required -->
      <xsl:if test="@NotNull = '1'">
        <xsl:attribute name="required">true</xsl:attribute>
      </xsl:if>

      <!-- default -->
      <xsl:if test="@DefaultValue != ''">
        <xsl:attribute name="default">
          <xsl:value-of select="@DefaultValue" />
        </xsl:attribute>
      </xsl:if>
                
      <!-- autoIncrement -->
      <xsl:if test="@AutoInc = '1'">
        <xsl:attribute name="autoIncrement">true</xsl:attribute>
      </xsl:if>

      <!-- description -->
      <xsl:if test="@Comments != ''">
        <xsl:attribute name="description">
          <xsl:value-of select="@Comments" />
        </xsl:attribute>
      </xsl:if>
    </column>
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- RELATIONS template -->
  <!-- ======================================================================= -->
  <xsl:template match="RELATIONS_END/RELATION_END">
    <xsl:variable name="id">
      <xsl:value-of select="@ID" />
    </xsl:variable>
        
    <xsl:call-template name="show_ForeignKey">
      <xsl:with-param name="relation" select="/DBMODEL/METADATA/RELATIONS/RELATION[@ID=$id]" />
    </xsl:call-template>
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- INDEX template -->
  <!-- ======================================================================= -->
  <xsl:template match="INDICES/INDEX">
    <xsl:choose>
      <xsl:when test="@IndexKind = '1' and @FKRefDef_Obj_id='-1'">
        <index>
          <xsl:attribute name="name">
            <xsl:value-of select="@IndexName" />
          </xsl:attribute>
          <xsl:apply-templates select="INDEXCOLUMNS/INDEXCOLUMN" mode="normal" />
        </index>
      </xsl:when>

      <xsl:when test="@IndexKind = '2'">
        <unique>
          <xsl:attribute name="name">
            <xsl:value-of select="@IndexName" />
          </xsl:attribute>
          <xsl:apply-templates select="INDEXCOLUMNS/INDEXCOLUMN" mode="unique" />
        </unique>
      </xsl:when>

      <xsl:when test="@IndexKind = '3'">
        <index>
          <xsl:attribute name="name">
            <xsl:value-of select="@IndexName" />
          </xsl:attribute>
          <xsl:apply-templates select="INDEXCOLUMNS/INDEXCOLUMN" mode="normal" />

          <vendor type="mysql">
            <parameter name="Index_type" value="FULLTEXT" />
          </vendor>
        </index>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- columns within an normal index -->
  <!-- ======================================================================= -->
  <xsl:template match="INDICES/INDEX/INDEXCOLUMNS/INDEXCOLUMN" mode="normal">
    <xsl:variable name="columnId">
      <xsl:value-of select="@idColumn" />
    </xsl:variable>

    <index-column>
      <xsl:attribute name="name">
        <xsl:value-of select="//COLUMNS/COLUMN[@ID=$columnId]/@ColName" />
      </xsl:attribute>
    </index-column>
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- columns within an unique index -->
  <!-- ======================================================================= -->
  <xsl:template match="INDICES/INDEX/INDEXCOLUMNS/INDEXCOLUMN" mode="unique">
    <xsl:variable name="columnId">
      <xsl:value-of select="@idColumn" />
    </xsl:variable>

    <unique-column>
      <xsl:attribute name="name">
        <xsl:value-of select="//COLUMNS/COLUMN[@ID=$columnId]/@ColName" />
      </xsl:attribute>
    </unique-column>
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- show_ForeignKey -->
  <!-- ======================================================================= -->
  <xsl:template name="show_ForeignKey">
    <xsl:param name="relation" />

    <foreign-key>
      <!-- foreignTable -->
      <xsl:attribute name="foreignTable">
        <xsl:value-of select="/DBMODEL/METADATA/TABLES/TABLE[@ID=$relation/@SrcTable]/@Tablename" />
      </xsl:attribute>

      <!-- name -->
      <xsl:attribute name="name">
        <xsl:value-of select="translate($relation/@RelationName, ' ', '_')" />
      </xsl:attribute>

      <!-- onDelete -->
      <xsl:attribute name="onDelete">
        <xsl:variable name="actionId">
          <xsl:call-template name="str_replace">
            <xsl:with-param name="stringIn" select="substring-before(substring-after($relation/@RefDef,'\n'), '\n')" />
            <xsl:with-param name="charsIn" select="'OnDelete='" />
            <xsl:with-param name="charsOut" select="''" />
          </xsl:call-template>
        </xsl:variable>

        <xsl:call-template name="get_actiontype">
          <xsl:with-param name="id" select="$actionId" />
        </xsl:call-template>
      </xsl:attribute>

      <!-- reference tag -->
      <xsl:call-template name="build_fk">
        <xsl:with-param name="stringIn" select="$relation/@FKFields"/>
      </xsl:call-template>
    </foreign-key>
  </xsl:template>


  <!-- ======================================================================= -->
  <!-- template functions -->
  <!-- ======================================================================= -->


  <!-- ======================================================================= -->
  <!-- get_datatype -->
  <!-- ======================================================================= -->
  <xsl:template name="get_datatype">
    <xsl:param name="id" />

    <xsl:variable name="type">
      <xsl:value-of select="/DBMODEL/SETTINGS/DATATYPES/DATATYPE[@ID=$id]/@TypeName" />
    </xsl:variable>

    <xsl:choose> 
      <xsl:when test="$type = 'BOOL'">BOOLEAN</xsl:when> 
      <xsl:when test="$type = 'GEOMETRY'">BLOB</xsl:when> 
      <xsl:when test="$type = 'INT'">INTEGER</xsl:when>
      <xsl:when test="$type = 'VARCHAR'">STRING</xsl:when>
      <xsl:when test="$type = 'DATETIME'">TIMESTAMP</xsl:when>
      <xsl:otherwise> 
        <xsl:value-of select="$type"/>
      </xsl:otherwise> 
    </xsl:choose> 
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- get_datasize -->
  <!-- ======================================================================= -->
  <xsl:template name="get_datasize">
    <xsl:param name="dtpc" />
    <xsl:param name="dtype" />

    <xsl:choose> 
      <xsl:when test="contains('FLOAT,DOUBLE,DECIMAL',$dtype)"> 
        <xsl:value-of select="substring-before($dtpc,',')" />
      </xsl:when>
      <xsl:when test="$dtype = 'ENUM'">
        <xsl:value-of select="''" />
      </xsl:when>     
      <xsl:otherwise> 
        <xsl:value-of select="$dtpc" />
      </xsl:otherwise> 
    </xsl:choose> 
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- clean_dataparams -->
  <!-- ======================================================================= -->
  <xsl:template name="clean_dataparams">
    <xsl:param name="dtp" />

    <xsl:variable name="dtp2">
      <xsl:call-template name="str_replace">
        <xsl:with-param name="stringIn" select="$dtp" />
        <xsl:with-param name="charsIn" select="'('" />
        <xsl:with-param name="charsOut" select="''" />
      </xsl:call-template>
    </xsl:variable>

    <xsl:call-template name="str_replace">
      <xsl:with-param name="stringIn" select="$dtp2" />
      <xsl:with-param name="charsIn" select="')'" />
      <xsl:with-param name="charsOut" select="''" />
    </xsl:call-template>
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- str_replace -->
  <!-- ======================================================================= -->
  <xsl:template name="str_replace">
    <xsl:param name="stringIn" />
    <xsl:param name="charsIn" />
    <xsl:param name="charsOut" />

    <xsl:choose>
      <xsl:when test="contains($stringIn,$charsIn)">
        <xsl:value-of select="concat(substring-before($stringIn,$charsIn),$charsOut)" />
        <xsl:call-template name="str_replace">
          <xsl:with-param name="stringIn" select="substring-after($stringIn,$charsIn)" />
          <xsl:with-param name="charsIn" select="$charsIn" />
          <xsl:with-param name="charsOut" select="$charsOut" />
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$stringIn" />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- build_fk -->
  <!-- ======================================================================= -->
  <xsl:template name="build_fk">
    <xsl:param name="stringIn" />

    <xsl:variable name="FKClean">
      <xsl:value-of select="substring-before($stringIn, '\n')" />
    </xsl:variable>

    <reference>
      <xsl:attribute name="local">
        <xsl:value-of select="substring-after($FKClean, '=')" />
      </xsl:attribute>
      <xsl:attribute name="foreign">
        <xsl:value-of select="substring-before($FKClean, '=')" />
      </xsl:attribute>
    </reference>

    <xsl:if test="contains(substring-after($stringIn,'\n'),'=')">
      <xsl:call-template name="build_fk">
        <xsl:with-param name="stringIn" select="substring-after($stringIn,'\n')" />
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- ======================================================================= -->
  <!-- get_actiontype -->
  <!-- ======================================================================= -->
  <xsl:template name="get_actiontype">
    <xsl:param name="id" />

    <xsl:choose>
      <xsl:when test="$id = 0">restrict</xsl:when>
      <xsl:when test="$id = 1">cascade</xsl:when>
      <xsl:when test="$id = 2">setnull</xsl:when>
      <xsl:otherwise>restrict</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
