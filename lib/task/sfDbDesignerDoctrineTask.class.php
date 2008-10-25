<?php

class sfDbDesignerDoctrineTask extends sfBaseTask
{
  protected function configure()
  {
    $this->namespace        = 'dbdesigner';
    $this->name             = 'convert-doctrine';
    $this->briefDescription = 'Convert DBDesigner file to doctrine schema';
    $this->detailedDescription = <<<EOF
The [doctrine:dbd-convert|INFO] task converts the DBDesigner file into a propel xml schema and converts this into a doctrine schema.
Call it with:

  [php symfony doctrine:dbd-convert|INFO]
EOF;

    $this->addArgument(
      'dbdfile', 
      sfCommandArgument::REQUIRED, 
      'The DBDesigner XML file'
    );
    
    $this->addArgument(
      'output', 
      sfCommandArgument::OPTIONAL, 
      'The doctrine schema file', 
      sfConfig::get('sf_config_dir') . DIRECTORY_SEPARATOR 
        . 'doctrine' . DIRECTORY_SEPARATOR . 'schema.yml'
    );

    $this->addOption(
      'transform',
      null,     
      sfCommandOption::PARAMETER_OPTIONAL,
      'The XSL tranformation template',
      sfConfig::get('sf_plugins_dir') . DIRECTORY_SEPARATOR 
        . 'sfDbDesignerPlugin' . DIRECTORY_SEPARATOR . 'data' 
        . DIRECTORY_SEPARATOR . 'doctrine.xsl'
    );

    $this->addOption(
      'application', 
      null, 
      sfCommandOption::PARAMETER_OPTIONAL, 
      'The application name', 
      'frontend'
    );
    
    $this->addOption(
      'env', 
      null, 
      sfCommandOption::PARAMETER_OPTIONAL, 
      'The environment', 
      'dev'
    );
  }

  protected function execute($arguments = array(), $options = array())
  {
    if(!file_exists($arguments['dbdfile']))
    {
      throw new sfException('The DBDesigner file does not exist');
    }

    $xml = new DOMDocument();
    $xml->load($arguments['dbdfile']);
    $this->logSection('xml', 'Loaded DBDesigner file');


    if(!file_exists($options['transform']))
    {                      
      throw new sfException('The XSL template does not exist');
    }

    $xsl = new DOMDocument();
    $xsl->load($options['transform']);
    $this->logSection('xsl', 'Loaded transformation file');

    $proc = new XSLTProcessor();
    $proc->importStyleSheet($xsl);
    $this->logSection('xsl', 'Processing XSL template');
    
    $xmlSchema = $proc->transformToXML($xml);
    $this->logSection('xml', 'Transforming to XML');

    unset($xml);
    unset($xsl);
    unset($proc);

    $xml = new DOMDocument();
    $xml->loadXML($xmlSchema);

    $xpath = new DOMXPath($xml);

    $doctrineSchema = array();
    $tables = $xpath->query("//table");

    for($i = 0; $i < $tables->length; $i++) 
    {
      $table = $tables->item($i);
      $tableName = $table->getAttribute('name');
      $class = sfInflector::camelize($tableName);

      $doctrineSchema[$class]['tableName'] = $tableName;

      $tableChildNodes = $table->childNodes;
      for($j = 0; $j < $tableChildNodes->length; $j++) 
      {
        $tableChild = $tableChildNodes->item($j);
        $nodeName = $tableChild->nodeName;

        if($nodeName == "column") 
        {
          $columnName = $tableChild->getAttribute('name');
                        
          switch($tableChild->getAttribute('type')) 
          {
            case 'INTEGER':
              $columnType = 'integer';
              $columnSize = $tableChild->getAttribute('size') ? $tableChild->getAttribute('size') : '4';
              break;
                                
            case 'STRING':
              $columnType = 'string';
              $columnSize = $tableChild->getAttribute('size');
              break;
                                
            case 'CHAR':
              $columnType = 'string';
              $columnSize = 1;
              break;
                                
            case 'TEXT':
              $columnType = 'string';                                                                                                                            
              $columnSize = 4000;
              break;

            case 'TIMESTAMP':
              $columnType = 'timestamp';
              break;

            case 'DATE':
              $columnType = 'date';
              break;

            case 'DATETIME':
              $columnType = 'datetime';
              break;

            case 'FLOAT':
              $columnType = 'float';
              break;

            case 'BOOLEAN':
              $columnType = 'boolean';
              break;

            default:
              $columnType = '';
              $columnSize = '';
              break;
          }

          $doctrineSchema[$class]['columns'][$columnName]['type'] = $columnType;

          if(isset($columnSize))
          {
            $doctrineSchema[$class]['columns'][$columnName]['size'] = $columnSize;
          }

          if($tableChild->hasAttribute('default')) 
          {
            $doctrineSchema[$class]['columns'][$columnName]['default'] = $tableChild->getAttribute('default');
          }

          if($tableChild->getAttribute('required') == "true")
          {
            $doctrineSchema[$class]['columns'][$columnName]['notnull'] = "true";
          }

          if($tableChild->getAttribute('primaryKey') == "true") 
          {
            $doctrineSchema[$class]['columns'][$columnName]['primary'] = "true";
          }

          if($tableChild->getAttribute('autoIncrement') == "true") 
          {
            $doctrineSchema[$class]['columns'][$columnName]['autoincrement'] = "true";
          }
        } 
        elseif($nodeName == "foreign-key") 
        {
          $foreignTable = $tableChild->getAttribute('foreignTable');
          $foreignClass = sfInflector::camelize($foreignTable);

          $foreignKeyChilds = $tableChild->childNodes;
          $referenceNode = null;

          for($k = 0; $k < $foreignKeyChilds->length; $k++) 
          {
            if($foreignKeyChilds->item($k)->nodeType == XML_ELEMENT_NODE && $foreignKeyChilds->item($k)->nodeName == "reference") 
            {
              $referenceNode = $foreignKeyChilds->item($k);
              break;
            }
          }

          if(!$referenceNode)
          {
            continue;
          }

          $onDelete = ($tableChild->getAttribute('onDelete') == 'setnull') ? 'null' : $tableChild->getAttribute('onDelete');

          $alias = sfInflector::camelize(substr($referenceNode->getAttribute('local'), 0, -3));
          
          if($alias == "") 
          {
            $alias = $foreignClass;
          }

          $doctrineSchema[$class]['relations'][$alias] = array(
            'class' => $foreignClass, 
            'foreign' => $referenceNode->getAttribute('foreign'), 
            'foreignAlias' => $class . 's', 
            'alias' => $alias, 
            'local' => $referenceNode->getAttribute('local'), 
            'onDelete' => $onDelete
          );
        } 
        elseif($nodeName == "unique") 
        {
          $indexName = $tableChild->getAttribute('name');
                        
          $foreignKeyChilds = $tableChild->childNodes;                                                                                                                       
          $fields = array();
          
          for($k = 0; $k < $foreignKeyChilds->length; $k++) 
          {
            if($foreignKeyChilds->item($k)->nodeType == XML_ELEMENT_NODE && $foreignKeyChilds->item($k)->nodeName == "unique-column") 
            {
              $fields[] = $foreignKeyChilds->item($k)->getAttribute('name');
            }
          }

          $doctrineSchema[$class]['indexes'][$indexName] = array(
            'fields' => $fields, 
            'type' => 'unique' 
          );
        }

        unset($columnSize);
      }
    }

    $this->getFilesystem()->remove($arguments['output']);

    file_put_contents($arguments['output'], sfYaml::dump($doctrineSchema, 5));
    $this->logSection('file+', $arguments['output']);
  }
}
