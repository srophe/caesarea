xquery version "3.1";

module namespace sf = "http://srophe.org/srophe/facets";
import module namespace functx="http://www.functx.com";
import module namespace config="http://srophe.org/srophe/config" at "../config.xqm";
import module namespace slider = "http://srophe.org/srophe/slider" at "date-slider.xqm";

declare namespace srophe="https://srophe.app";
declare namespace facet="http://expath.org/ns/facet";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $sf:QUERY_OPTIONS := map {
    "leading-wildcard": "yes",
    "filter-rewrite": "yes"
};

(: Add sort fields to browse and search options. Used for sorting, add sort fields and functions, add sort function:)
declare variable $sf:sortFields := map { "fields": ("title", "author","pubDate","pubPlace","publisher","citationNo","sortField") };

(: ~ 
 : Build indexes for fields and facets as specified in facet-def.xml and search-config.xml files
 : Note: Investigate boost? 
:)
declare function sf:build-index(){
<collection xmlns="http://exist-db.org/collection-config/1.0">
    <index xmlns="http://exist-db.org/collection-config/1.0" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:srophe="https://srophe.app">
        <lucene diacritics="no">
            <module uri="http://srophe.org/srophe/facets" prefix="sf" at="xmldb:exist:///{$config:app-root}/modules/lib/facets.xql"/>
            <text qname="tei:TEI">{
            let $facets :=     
                for $f in collection($config:app-root)//facet:facet-definition
                let $path := document-uri(root($f))
                group by $facet-grp := $f/@name
                return 
                    if($f[1]/facet:group-by/@function != '') then 
                       <facet dimension="{functx:words-to-camel-case($facet-grp)}" expression="sf:facet(., {concat("'",$path[1],"'")}, {concat("'",$facet-grp,"'")})"/>
                    else if($f[1]/facet:range) then
                       <facet dimension="{functx:words-to-camel-case($facet-grp)}" expression="sf:range(., {concat("'",$path[1],"'")}, {concat("'",$facet-grp,"'")})"/>                
                    else 
                        <facet dimension="{functx:words-to-camel-case($facet-grp)}" expression="{replace($f[1]/facet:group-by/facet:sub-path/text(),"&#34;","'")}"/>      
                return $facets
                }  
                <!-- Predetermined sort fields -->               
                <field name="title" expression="sf:field(.,'title')"/>
                <field name="author" expression="sf:field(., 'author')"/>
                <field name="pubDate" expression="sf:field(., 'pubDate')"/>
                <field name="pubPlace" expression="sf:field(., 'pubPlace')"/>
                <field name="publisher" expression="sf:field(., 'publisher')"/>
                <field name="citationNo" expression="sf:field(., 'citationNo')"/>
                <field name="sortField" expression="sf:field(., 'sortField')"/>
                <field name="online" expression="sf:field(., 'online')"/>
                <field name="placeName" expression="sf:field(., 'placeName')"/>
            </text>
            <!--
            <text qname="tei:fileDesc"/>
            <text qname="tei:biblStruct"/>
            <text qname="tei:div"/>
            <text qname="tei:author" boost="5.0"/>
            <text qname="tei:origPlace" boost="5.0"/>
            <text qname="tei:title" boost="10.5"/>
            <text qname="tei:desc" boost="2.0"/>
            -->
        </lucene> 
        <range>
            <create qname="@syriaca-computed-start" type="xs:date"/>
            <create qname="@syriaca-computed-end" type="xs:date"/>
            <create qname="@type" type="xs:string"/>
            <create qname="@ana" type="xs:string"/>
            <create qname="@syriaca-tags" type="xs:string"/>
            <create qname="@srophe:tags" type="xs:string"/>
            <create qname="@when" type="xs:string"/>
            <create qname="@target" type="xs:string"/>
            <create qname="@who" type="xs:string"/>
            <create qname="@ref" type="xs:string"/>
            <create qname="@uri" type="xs:string"/>
            <create qname="@where" type="xs:string"/>
            <create qname="@active" type="xs:string"/>
            <create qname="@passive" type="xs:string"/>
            <create qname="@mutual" type="xs:string"/>
            <create qname="@name" type="xs:string"/>
            <create qname="@xml:lang" type="xs:string"/>
            <create qname="@level" type="xs:string"/>
            <create qname="@status" type="xs:string"/>
            <create qname="@role" type="xs:string"/>
            <create qname="tei:idno" type="xs:string"/>
            <create qname="tei:title" type="xs:string"/>
            <create qname="tei:geo" type="xs:string"/>
            <create qname="tei:relation" type="xs:string"/>
            <create qname="tei:persName" type="xs:string"/>
            <create qname="tei:placeName" type="xs:string"/>
            <create qname="tei:author" type="xs:string"/>
        </range>
    </index>
</collection>
};

(:~ 
 : Update collection.xconf file for data application, can be called by post install script, or index.xql
 : Save collection to correct application subdirectory in /db/system/config
 : Trigger a re-index.
 : 
 : @note reindex does not seem to work... investigate 
 :)
declare function sf:update-index(){
    let $updateXconf := 
      try {
            let $configPath := concat('/db/system/config',replace($config:data-root,'/data',''))
            return xmldb:store($configPath, 'collection.xconf', sf:build-index())
        } catch * {('error: ',concat($err:code, ": ", $err:description))}
    return 
        if(starts-with($updateXconf,'error:')) then
            $updateXconf
        else xmldb:reindex($config:data-root)
};

(: Main facet function, for generic facets :)

(: Build facet path based on facet definition file. Used by collection.xconf to build facets at index time. 
 : @param $path - path to facet definition file, if empty assume root.
 : @param $name - name of facet in facet definition file. 
 :
 : TODO: test custom facets/fields
:)
declare function sf:facet($element as item()*, $path as xs:string, $name as xs:string){
    let $facet-definition :=  
        if(doc-available($path)) then
            doc($path)//facet:facet-definition[@name=$name]
        else () 
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()    
    return 
        if(not(empty($facet-definition))) then  
            if($facet-definition/facet:group-by/@function != '') then 
              try { 
                    util:eval(concat('sf:facet-',string($facet-definition/facet:group-by/@function),'($element,$facet-definition, $name)'))
                } catch * {concat($err:code, ": ", $err:description)}
            else util:eval(concat('$element/',$xpath))
        else ()
};

(: For sort fields, or fields not defined in search-config.xml :)
declare function sf:field($element as item()*, $name as xs:string){
    try { 
        util:eval(concat('sf:field-',$name,'($element,$name)'))
    } catch * {concat($err:code, ": ", $err:description)}
};

(:~ 
 : Build fields path based on search-config.xml file. Used by collection.xconf to build facets at index time. 
 : @param $path - path to facet definition file, if empty assume root.
 : @param $name - name of facet in facet definition file. 
 : 
 : @note not currently implemented
:)
declare function sf:field($element as item()*, $path as xs:string, $name as xs:string){
    let $field-definition :=  
        if(doc-available($path)) then
            doc($path)//*:field[@name=$name]
        else () 
    let $xpath := $field-definition/*:expression/text()    
    return 
        if(not(empty($field-definition))) then  
            if($field-definition/@function != '') then 
                try { 
                    util:eval(concat('sf:field-',string($field-definition/@function),'($element,$field-definition, $name)'))
                } catch * {concat($err:code, ": ", $err:description)}
            else util:eval(concat('$element/',$xpath)) 
        else ()  
};


(: Custom search fields :)
(: Could be just shortened to  tokenize(util:eval(concat('$element/',$xpath)),' ')  do not need to group for Lucene facets i think?:)
declare function sf:facet-group-by-array($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()    
    return tokenize(util:eval(concat('$element/',$xpath)),' ') 
};
(: Fit values into a specified range 
example: 
    <range type="xs:year">
        <bucket lt="0001" name="BC dates" order="22"/>
        <bucket gt="1600-01-01" lt="1700-01-01" name="1600-1700" order="5"/>
        <bucket gt="1700-01-01" lt="1800-01-01" name="1700-1800" order="4"/>
        <bucket gt="1800-01-01" lt="1900-01-01" name="1800-1900" order="3"/>
        <bucket gt="1900-01-01" lt="2000-01-01" name="1900-2000" order="2"/>
        <bucket gt="2000-01-01" name="2000 +" order="1"/>
    </range>
:)

declare function sf:range($element as item()*, $path as xs:string, $name as xs:string){
    let $facet-definition :=  
        if(doc-available($path)) then
            doc($path)//facet:facet-definition[@name=$name]
        else () 
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()  
    let $range := $facet-definition/facet:range 
    for $r in $range/facet:bucket
    let $path := if($r/@lt and $r/@lt != '' and $r/@gt and $r/@gt != '') then
                    concat('$element/',$facet-definition/descendant::facet:sub-path/text(),'[. >= "', sf:type($r/@gt, $range/@type),'" and . <= "',sf:type($r/@lt, $range/@type),'"]')
                 else if($r/@lt and $r/@lt != '' and (not($r/@gt) or $r/@gt ='')) then 
                    concat('$element/',$facet-definition/descendant::facet:sub-path/text(),'[. <= "',sf:type($r/@lt, $range/@type),'"]')
                 else if($r/@gt and $r/@gt != '' and (not($r/@lt) or $r/@lt ='')) then 
                    concat('$element/',$facet-definition/descendant::facet:sub-path/text(),'[. >= "', sf:type($r/@gt, $range/@type),'"]')
                 else if($r/@eq) then
                    concat('$element/',$facet-definition/descendant::facet:sub-path/text(),'[', $r/@eq ,']')
                 else ()
    let $f := util:eval($path)
    return if($f) then $r/@name else()
};

(: Display, output functions  :)
declare function sf:display($result as item()*, $facet-definition as item()*) {
    let $facet-definitions := 
        if($facet-definition/self::facet:facet-definition) then 'definition' 
        else $facet-definition/facet:facets/facet:facet-definition
    for $facet in $facet-definitions
    let $name := string($facet/@name)
    let $count := if(request:get-parameter(concat('all-',$name), '') = 'on' ) then () else string($facet/facet:max-values/@show)
    let $f := ft:facets($result, $name, ())
    let $sortedFacets :=  
                        for $key at $p in map:keys($f)
                        let $value := map:get($f, $key)
                        order by $key ascending
                        return 
                            <facet label="{$key}" value="{$value}"/>
    let $total := count($sortedFacets)                            
    return 
        if($facet[@display = 'none']) then () 
        else if($facet[@display = 'slider']) then 
            slider:browse-date-slider($result,$facet/facet:group-by/facet:sub-path)
        else if (map:size($f) > 0) then
            <span class="facet-grp">
                <span class="facet-title">{string($facet/@label)}</span>
                <span class="facet-list">
                {(
                    for $facet at $n in subsequence($sortedFacets,1,5)
                    let $label := string($facet/@label)
                    let $count := string($facet/@value)
                    let $param-name := concat('facet-',$name)
                    let $facet-param := concat($param-name,'=',encode-for-uri($label))
                    let $active := if(request:get-parameter($param-name, '') = $label) then 'active' else ()
                    let $url-params := 
                                    if($active) then replace(replace(replace(request:get-query-string(),encode-for-uri($label),''),concat($param-name,'='),''),'&amp;&amp;','&amp;')
                                    else if(request:get-parameter('start', '')) then '&amp;start=1'
                                    else if(request:get-query-string() != '') then concat($facet-param,'&amp;',request:get-query-string())
                                    else $facet-param
                    return 
                        <a href="?{$url-params}" class="facet-label btn btn-default {$active}" num="{$n}">
                                    {if($active) then (<span class="glyphicon glyphicon-remove facet-remove"></span>)else ()}
                                    {$label} <span class="count"> ({$count})</span> </a>,
                                    
                    <div id="view{$name}" class="collapse">
                        {
                        for $facet at $n in subsequence($sortedFacets,6,$total)
                        let $label := string($facet/@label)
                        let $count := string($facet/@value)
                        let $param-name := concat('facet-',$name)
                        let $facet-param := concat($param-name,'=',encode-for-uri($label))
                        let $active := if(request:get-parameter($param-name, '') = $label) then 'active' else ()
                        let $url-params := 
                                        if($active) then replace(replace(replace(request:get-query-string(),encode-for-uri($label),''),concat($param-name,'='),''),'&amp;&amp;','&amp;')
                                        else if(request:get-parameter('start', '')) then '&amp;start=1'
                                        else if(request:get-query-string() != '') then concat($facet-param,'&amp;',request:get-query-string())
                                        else $facet-param
                        return 
                            <a href="?{$url-params}" class="facet-label btn btn-default {$active}" num="{$n}">
                                        {if($active) then (<span class="glyphicon glyphicon-remove facet-remove"></span>)else ()}
                                        {$label} <span class="count"> ({$count})</span> </a>
                        }
                    </div>,
                    if($total gt 5) then 
                    <a href="#" data-toggle="collapse" data-target="#view{$name}" class="facet-label btn btn-info viewMore">View All</a>
                    else (),
                    <br/>
                    )}
                </span>
            </span>
        else () 
};

(:~ 
 : Add sort option to facets 
 : Work in progress, need to pass sort options from facet-definitions to sort function.
:)
declare function sf:sort($facets as map(*)?, $type, $direction) {
array {
        if (exists($facets)) then
            for $key in map:keys($facets)
            let $value := map:get($facets, $key)
            order by $key ascending
            return
                map { $key: $value }
        else
            ()
    }
(:
if($type = 'value') then
    array {
        if (exists($facets)) then
            for $key in map:keys($facets)
            let $value := map:get($facets, $key)
            order by $key ascending
            return
                map { $key: $value }
        else
            ()
    }
else 
 array {
        if (exists($facets)) then
            for $key in map:keys($facets)
            let $value := map:get($facets, $key)
            order by $value descending
            return
                map { $key: $value }
        else
            ()
    }
:)    
};

(:~
 : Build map for search query
 : Used by search functions
 :)
declare function sf:facet-query() {
    map:merge((
        $sf:QUERY_OPTIONS,
        $sf:sortFields,
        map {
            "facets":
                map:merge((
                    for $param in request:get-parameter-names()[starts-with(., 'facet-')]
                    let $dimension := substring-after($param, 'facet-')
                    return
                        map {
                            $dimension: request:get-parameter($param, ())
                        }
                ))
        }
    ))
};
declare function sf:facets() {
        map {
            "facets":
                map:merge((
                    for $param in request:get-parameter-names()[starts-with(., 'facet-')]
                    let $dimension := substring-after($param, 'facet-')
                    return
                        map {
                            $dimension: request:get-parameter($param, ())
                        }
                ))
        }
};

(:~
 : Adds type casting when type is specified facet:facet:group-by/@type
 : @param $value of xpath
 : @param $type value of type attribute
:)
declare function sf:type($value as item()*, $type as xs:string?) as item()*{
    if($type != '') then  
        if($type = 'xs:string') then xs:string($value)
        else if($type = 'xs:string') then xs:string($value)
        else if($type = 'xs:decimal') then xs:decimal($value)
        else if($type = 'xs:integer') then xs:integer($value)
        else if($type = 'xs:long') then xs:long($value)
        else if($type = 'xs:int') then xs:int($value)
        else if($type = 'xs:short') then xs:short($value)
        else if($type = 'xs:byte') then xs:byte($value)
        else if($type = 'xs:float') then xs:float($value)
        else if($type = 'xs:double') then xs:double($value)
        else if($type = 'xs:dateTime') then xs:dateTime($value)
        else if($type = 'xs:date') then xs:date($value)
        else if($type = 'xs:gYearMonth') then xs:gYearMonth($value)        
        else if($type = 'xs:gYear') then xs:gYear($value)
        else if($type = 'xs:gMonthDay') then xs:gMonthDay($value)
        else if($type = 'xs:gMonth') then xs:gMonth($value)        
        else if($type = 'xs:gDay') then xs:gDay($value)
        else if($type = 'xs:duration') then xs:duration($value)        
        else if($type = 'xs:anyURI') then xs:anyURI($value)
        else if($type = 'xs:Name') then xs:Name($value)
        else $value
    else $value
};

(: Syriaca.org strip non sort characters :)
declare function sf:build-sort-string($titlestring as xs:string?) as xs:string* {
    let $s1 := replace(replace(normalize-space($titlestring), '^\s+|^[tT]he\s+|[aA]\s+|^[oO]n\s+[aA]\s+|^[aA]n\s|^\d*\W|^[^\p{L}]',''),'[^a-zA-Z0-9\s]+','')
    let $s2 := replace(normalize-space($s1), '^\s+|^[tT]he\s+|[aA]\s+|^[oO]n\s+[aA]\s+|^[aA]n\s|^\d*\W|^[^\p{L}]','')
    return $s2
};


(:~
 : TEI Title field, specific to Srophe applications 
 :)
declare function sf:field-title($element as item()*, $name as xs:string){
    if($element/descendant::tei:profileDesc/tei:creation/tei:title[@type='uniform']/@ref) then
        let $value := $element/descendant::tei:profileDesc/tei:creation/tei:title[@type='uniform']/@ref
        return $value/parent::*[1][@ref=$value]//text() 
    else if($element/descendant::tei:profileDesc/tei:creation/tei:title[@type='uniform']) then 
        $element/descendant::tei:profileDesc/tei:creation/tei:title[@type='uniform']
    else if($element/descendant-or-self::*[contains(@syriaca-tags,'#syriaca-headword')][contains(@xml:lang,'en')][not(empty(node()))]) then 
        let $en := $element/descendant-or-self::*[contains(@syriaca-tags,'#syriaca-headword')][contains(@xml:lang,'en')][not(empty(node()))][1]
        let $syr := string-join($element/descendant::*[contains(@syriaca-tags,'#syriaca-headword')][matches(@xml:lang,'^syr')][1],' ')
        return sf:build-sort-string(concat($en, if($syr != '') then  concat(' - ', $syr) else ()))
    else if($element/descendant-or-self::*[contains(@srophe:tags,'#headword')][contains(@xml:lang,'en')][not(empty(node()))]) then
        let $en := $element/descendant-or-self::*[contains(@srophe:tags,'#headword')][contains(@xml:lang,'en')][not(empty(node()))][1]
        let $syr := string-join($element/descendant::*[contains(@srophe:tags,'#headword')][matches(@xml:lang,'^syr')][1],' ')
        return sf:build-sort-string(concat($en, if($syr != '') then  concat(' - ', $syr) else ()))
    else if($element/descendant-or-self::*[contains(@srophe:tags,'#syriaca-headword')][contains(@xml:lang,'en')][not(empty(node()))]) then
        let $en := $element/descendant-or-self::*[contains(@srophe:tags,'#syriaca-headword')][contains(@xml:lang,'en')][not(empty(node()))][1]
        let $syr := string-join($element/descendant::*[contains(@srophe:tags,'#syriaca-headword')][matches(@xml:lang,'^syr')][1],' ')
        return sf:build-sort-string(concat($en, if($syr != '') then  concat(' - ', $syr) else ()))       
    else if($element/descendant::tei:biblStruct) then 
        for $title in $element/descendant::tei:biblStruct/descendant::tei:title
        return sf:build-sort-string($title)         
    else sf:build-sort-string($element/descendant::tei:titleStmt/tei:title[1])
};
(: Author field :)
declare function sf:field-author($element as item()*, $name as xs:string){
    if($element/descendant::tei:biblStruct) then 
        for $author in $element/descendant::tei:body/tei:biblStruct/descendant-or-self::tei:author | 
        $element/descendant::tei:body/tei:biblStruct/descendant-or-self::tei:editor
        let $name := 
            if($author/descendant-or-self::tei:surname) then 
                normalize-space(concat($author/descendant-or-self::tei:surname, if($author/descendant-or-self::tei:forename) then concat(', ',$author/descendant-or-self::tei:forename) else ()))  
            else normalize-space(string-join($author//text(),' '))
        return if($name != '') then $name else ()    
    else if($element/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']/@ref) then
        let $value := $element/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']/@ref
        return $value/parent::*[1][@ref=$value]//text() 
    else if($element/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']) then 
        $element/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']
    else $element/descendant::tei:titleStmt/descendant::tei:author
};

(: pubDate :)
declare function sf:field-pubDate($element as item()*, $name as xs:string){
    if($element/descendant::tei:biblStruct) then 
        for $date in $element/descendant::tei:body/tei:biblStruct/descendant-or-self::tei:imprint/tei:date
        let $regex := "\d{4}"
        let $d := analyze-string($date, $regex)//*:match//text()
        return if($d != '') then $d else ()    
    else ()
};

(: pubPlace :)
declare function sf:field-pubPlace($element as item()*, $name as xs:string){
    if($element/descendant::tei:imprint/tei:pubPlace) then 
        $element/descendant::tei:imprint/tei:pubPlace 
    else ()
};
(: pubPlace :)
declare function sf:field-publisher($element as item()*, $name as xs:string){
    if($element/descendant::tei:imprint/tei:publisher) then 
        $element/descendant::tei:imprint/tei:publisher 
    else ()
};

(: Author facet :)
declare function sf:facet-author($element as item()*, $facet-definition as item(), $name as xs:string){
    if($element/descendant::tei:biblStruct) then 
        for $author in $element/descendant::tei:body/tei:biblStruct/descendant-or-self::tei:author | 
        $element/descendant::tei:body/tei:biblStruct/descendant-or-self::tei:editor
        let $name := 
            if($author/descendant-or-self::tei:surname) then 
                normalize-space(concat($author/descendant-or-self::tei:surname, if($author/descendant-or-self::tei:forename) then concat(', ',$author/descendant-or-self::tei:forename) else ()))  
            else normalize-space(string-join($author//text(),' '))
        return if($name != '') then $name else ()    
    else if($element/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']/@ref) then
        let $value := $element/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']/@ref
        return $value/parent::*[1][@ref=$value]//text() 
    else if($element/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']) then 
        $element/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']
    else $element/descendant::tei:titleStmt/descendant::tei:author
};

(:~
 : TEI author facet, specific to Srophe bibl module
 :)
declare function sf:facet-biblAuthors($element as item()*, $facet-definition as item(), $name as xs:string){
    if($element/descendant::tei:biblStruct) then 
        $element/descendant::tei:biblStruct/descendant::tei:author | $element/descendant::tei:biblStruct/descendant::tei:editor
    else $element/descendant::tei:titleStmt/descendant::tei:author
}; 

(: pubPlace facet :)
declare function sf:facet-pubPlace($element as item()*, $facet-definition as item(), $name as xs:string){
    if($element/descendant::tei:imprint/tei:pubPlace) then 
        $element/descendant::tei:imprint/tei:pubPlace 
    else ()
};

(: **** Caesrea Custom **** :)

declare function sf:facet-controlled-labels($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text() 
    return util:eval(concat('$element/',$xpath))
};

(: Caesarea facets :)
declare function sf:facet-eraComposed($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()
    for $value in tokenize(util:eval(concat('$element/',$xpath)),' ')[normalize-space(.) != '']
    let $v := replace($value,'#','')
    let $label := normalize-space(string-join($element/descendant::tei:category[@xml:id = $v]//text(),''))
    return if($label != '') then $label else if($label != ' ') then $label else if($v != '') then $v else 'no label'
};

(: Caesarea facets :)
declare function sf:facet-eraMentioned($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()
    for $value in tokenize(util:eval(concat('$element/',$xpath)),' ')[normalize-space(.) != '']
    let $v := replace($value,'#','')
    let $label := normalize-space(string-join($element/descendant::tei:category[@xml:id = $v]//text(),''))
    return if($label != '') then $label else if($label != ' ') then $label else if($v != '') then $v else 'no label'
};

(: Get text value of a element with ref attribute :)
declare function sf:facet-refLabel($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()    
    let $value := util:eval(concat('$element/',$xpath))
    return normalize-space(string-join($value[1]/parent::*[@ref=$value]))
    (:('TEST: ', normalize-space($value/parent::*[1][@ref=$value]//text()),' : ',$value):)  
};

(: Get text value of a element with ident attribute :)
declare function sf:facet-identLabel($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()    
    let $value := util:eval(concat('$element/',$xpath))
    return $value/parent::*[1][@ident=$value][1]//text() 
};

(:~
 : TEI Title field, specific to Srophe applications 
 :)
declare function sf:field-citationNo($element as item()*, $name as xs:string){
    (:profileDesc/creation/ref:)
    if($element/tei:teiHeader/tei:profileDesc/tei:creation/tei:ref) then 
        $element/tei:teiHeader/tei:profileDesc/tei:creation/tei:ref[1]
    else ()
};

declare function sf:field-online($element as item()*, $name as xs:string){
    if($element[descendant::tei:idno[not(matches(.,'^(https://biblia-arabica.com|https://www.zotero.org|https://api.zotero.org)'))] or descendant::tei:ref/@target[not(matches(.,'^(https://biblia-arabica.com|https://www.zotero.org|https://api.zotero.org)'))]]) then 
        'online'
    else ()
};

declare function sf:field-placeName($element as item()*, $name as xs:string){
    $element/descendant::tei:placeName 
};

(:~
 : TEI Title field, specific to Srophe applications 
 :)
declare function sf:field-sortField($element as item()*, $name as xs:string){
    normalize-space(string-join(concat($element/tei:teiHeader/tei:profileDesc/tei:creation/tei:persName[@role='author'],' ',
    $element/tei:teiHeader/tei:profileDesc/tei:creation/tei:title, ' ', 
    $element/tei:teiHeader/tei:profileDesc/tei:creation/tei:ref/@n),' '))
};