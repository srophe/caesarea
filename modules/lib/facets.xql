xquery version "3.1";

(:
 : Srophe application facets module. 
 :  1) Creates lucene index definitions based on facet-def.xml files living in the Srophe application.
 :  2) Creates xquery filters for passing facets to search/browse functions within the Srophe application. 
 :  3) Creates facet display for search/browse HTML pages in Srophe application
 :
 : Uses the following eXist-db specific functions:
 :      util:eval 
 :      request:get-parameter
 :      request:get-parameter-names()
 : 
 : Facet definition files based on the EXpath specs. 
 : @see http://expath.org/spec/facet
 :
 : @author Winona Salesky
 : @version .05    
:)

module namespace sf = "http://srophe.org/srophe/facets";
import module namespace functx="http://www.functx.com";
import module namespace slider = "http://srophe.org/srophe/slider" at "date-slider.xqm";
import module namespace config="http://srophe.org/srophe/config" at "../config.xqm";

declare namespace srophe="https://srophe.app";
declare namespace facet="http://expath.org/ns/facet";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $sf:QUERY_OPTIONS := map {
    "leading-wildcard": "yes",
    "filter-rewrite": "yes"
};

(: Add sort fields to browse and search options. Used for sorting, add sort fields and functions, add sort function:)
declare variable $sf:sortFields := map { "fields": ("title", "author", "publicationDate") };

(:~ 
 : Build indexes for fields and facets as specified in facet-def.xml and search-config.xml files
 : Note: Hold off on fields until boost has been added. See: https://github.com/eXist-db/exist/issues/3403
:)
declare function sf:build-index(){
<collection xmlns="http://exist-db.org/collection-config/1.0">
    <index xmlns="http://exist-db.org/collection-config/1.0" xmlns:tei="http://www.tei-c.org/ns/1.0" xmlns:srophe="https://srophe.app">
        <lucene diacritics="no">
            <module uri="http://srophe.org/srophe/facets" prefix="sf" at="xmldb:exist:///{$config:app-root}/modules/lib/facets.xql"/>
            <text qname="tei:body">{
            let $facets :=     
                for $f in collection($config:app-root)//facet:facet-definition
                let $path := document-uri(root($f))
                group by $facet-grp := $f/@name
                return 
                    if($f[1]/facet:group-by/@function != '') then 
                       <facet dimension="{functx:words-to-camel-case($facet-grp)}" expression="sf:facet(descendant-or-self::tei:body, {concat("'",$path[1],"'")}, {concat("'",$facet-grp,"'")})"/>
                    else if($f[1]/facet:range) then
                       <facet dimension="{functx:words-to-camel-case($facet-grp)}" expression="sf:facet(descendant-or-self::tei:body, {concat("'",$path[1],"'")}, {concat("'",$facet-grp,"'")})"/>                
                    else 
                        <facet dimension="{functx:words-to-camel-case($facet-grp)}" expression="{replace($f[1]/facet:group-by/facet:sub-path/text(),"&#34;","'")}"/>
            let $fields := 
                for $f in collection($config:app-root)//*:search-config/*:field
                let $path := document-uri(root($f))
                group by $field-grp := $f/@name
                where $field-grp != 'keyword' and  $field-grp != 'fullText'
                return 
                    if($f[1]/@function != '') then 
                        <field name="{functx:words-to-camel-case($field-grp)}" expression="sf:field(descendant-or-self::tei:body, {concat("'",$path[1],"'")}, {concat("'",$field-grp,"'")})"/>
                    else 
                        <field name="{functx:words-to-camel-case($field-grp)}" expression="{string($f[1]/@expression)}"/>
            return 
                ($facets(:,$fields :))
            }
                <!-- Predetermined sort fields -->
                <field name="title" expression="sf:field(descendant-or-self::tei:body,'title')"/>
                <field name="author" expression="sf:field(descendant-or-self::tei:body,'author')"/>
                <field name="publicationDate" expression="sf:field(descendant-or-self::tei:body,'publicationDate')"/>
            </text>
            <text qname="tei:fileDesc"/>
            <text qname="tei:biblStruct"/>
            <text qname="tei:div"/>
            <text qname="tei:ab"/>
            <text qname="tei:author" boost="5.0"/>
            <text qname="tei:persName" boost="5.0"/>
            <text qname="tei:placeName" boost="5.0"/>
            <text qname="tei:origPlace" boost="5.0"/>
            <text qname="tei:title" boost="10.5"/>
            <text qname="tei:desc" boost="2.0"/>
            <text qname="tei:event"/>
            <text qname="tei:note"/>
            <text qname="tei:pubPlace"/>
            <text qname="tei:publisher"/>
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
            <create qname="tei:idno" type="xs:string"/>
            <create qname="tei:title" type="xs:string"/>
            <create qname="tei:geo" type="xs:string"/>
            <create qname="tei:relation" type="xs:string"/>
            <create qname="tei:persName" type="xs:string"/>
            <create qname="tei:placeName" type="xs:string"/>
            <create qname="tei:author" type="xs:string"/>
            <create qname="tei:date" type="xs:string"/>
        </range>
    </index>
</collection>
};

(:~ 
 : Update collection.xconf file for data application, can be called by post install script, or index.xql
 : Save collection to correct application subdirectory in /db/system/config
 : Trigger a re-index.
 :  
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

(: Build facet path based on facet definition file. Used by collection.xconf to build facets at index time. 
 : @param $path - path to facet definition file, if empty assume root.
 : @param $name - name of facet in facet definition file. 
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
            else if($facet-definition/facet:range) then try { 
                   sf:facet-range($element,$facet-definition, $name)
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

(:~ 
 : Create HTML display for facets
 : Use facet-definition files for labels and sort options
:)
declare function sf:display($result as item()*, $facet-definition as item()*) {
    for $facet in $facet-definition/descendant-or-self::facet:facet-definition
    let $name := string($facet/@name)
    let $count := if(string($facet/facet:max-values/@show) != ()) then xs:integer($facet/facet:max-values/@show) else 10
    let $f := ft:facets($result, $name, ())
    return 
        if($facet[@display = 'none']) then () 
        else if($facet[@display = 'slider']) then 
            slider:browse-date-slider($result,$facet/facet:group-by/facet:sub-path)
        else if (map:size($f) > 0) then
            <span class="facet-grp">
                <span class="facet-title">{string($facet/@label)}</span>
                <span class="facet-list">
                <div class="facet-list show">{
                    for $sortedFacet in subsequence(sf:sort($f,$facet)?*,1,$count)
                    return
                        map:for-each($sortedFacet, function($label, $freq) {
                            let $param-name := concat('facet-',$name)
                            let $facet-param := concat($param-name,'=',$label)
                            let $active := if(request:get-parameter($param-name, '') = $label) then 'active' else ()
                            let $url-params := 
                                if($active) then replace(replace(replace(request:get-query-string(),encode-for-uri($label),''),concat($param-name,'='),''),'&amp;&amp;','&amp;') 
                                else concat($facet-param,'&amp;',request:get-query-string())
                            return
                                <a href="?{$url-params}" class="facet-label btn btn-default {$active}">
                                {if($active) then (<span class="glyphicon glyphicon-remove facet-remove"></span>)else ()}
                                {functx:capitalize-first(functx:camel-case-to-words($label,' '))} <span class="count"> ({$freq}) </span> </a>
                        })
                }</div>
                {
                    if(map:size($f) gt xs:integer($count)) then 
                         (<div class="facet-list collapse" id="{concat('show',replace(string($facet-definition/@name),' ',''))}">{
                            for $sortedFacet in subsequence(sf:sort($f,$facet)?*,$count + 1,map:size($f))
                            return
                                map:for-each($sortedFacet, function($label, $freq) {
                                    let $param-name := concat('facet-',$name)
                                    let $facet-param := concat($param-name,'=',$label)
                                    let $active := if(request:get-parameter($param-name, '') = $label) then 'active' else ()
                                    let $url-params := 
                                        if($active) then replace(replace(replace(request:get-query-string(),encode-for-uri($label),''),concat($param-name,'='),''),'&amp;&amp;','&amp;') 
                                        else concat($facet-param,'&amp;',request:get-query-string())
                                    return
                                        <a href="?{$url-params}" class="facet-label btn btn-default {$active}">
                                        {if($active) then (<span class="glyphicon glyphicon-remove facet-remove"></span>)else ()}
                                        {functx:capitalize-first(functx:camel-case-to-words($label,' '))} <span class="count"> ({$freq}) </span> </a>
                                })
                        }</div>,
                        <a class="facet-label togglelink btn btn-info" 
                        data-toggle="collapse" data-target="#{concat('show',replace(string($facet-definition/@name),' ',''))}" href="#{concat('show',replace(string($facet-definition/@name),' ',''))}" 
                        data-text-swap="Less"> More &#160;<i class="glyphicon glyphicon-circle-arrow-right"></i></a>)
                    else ()
                 }
                </span>
            </span>
        else ()  
};

(:~ 
 : Add sort option to facets based on facet definition 
 : Options are
 :    sort by value (ascending/descending), 
 :    sort by result count (ascending/descending) 
 :    sort on range order attribute (ascending/descending) . 
 : Range facets sort on order attribute. Example: 
 :    <range type="xs:year">
 :           <bucket lt="0001-01-01" name="BC dates" order="1"/>
 :           <bucket gt="0001-01-01" lt="0100-01-01" name="1-100" order="2"/>
 :   </range>        
:)
declare function sf:sort($facets as map(*)?, $facet-definition) {
if($facet-definition/facet:order-by/text() = 'value') then
    if($facet-definition/facet:order-by[@direction='descending']) then
        array {
            if (exists($facets)) then
                for $key in map:keys($facets)
                let $value := map:get($facets, $key)
                order by $key descending
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
                order by $key ascending
                return
                    map { $key: $value }
            else
                ()
        }
else
if($facet-definition/facet:range) then
    if($facet-definition/facet:order-by[@direction='descending']) then
        array {
            if (exists($facets)) then
                for $key in map:keys($facets)
                let $value := map:get($facets, $key)
                let $order := string($facet-definition/facet:range/facet:bucket[@name = $key]/@order)
                let $order := if($order castable as xs:integer) then xs:integer($order) else 0
                order by $order descending
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
                let $order := string($facet-definition/facet:range/facet:bucket[@name = $key]/@order)
                let $order := if($order castable as xs:integer) then xs:integer($order) else 0
                order by $order ascending
                return
                    map { $key: $value }
            else
                ()
        }
else if($facet-definition/facet:order-by[@direction='descending']) then
    array {
        if(exists($facets)) then
            for $key in map:keys($facets)
            let $value := map:get($facets, $key)
            order by $value descending
            return
                map { $key: $value }
        else
            ()
    }
else 
 array {
        if(exists($facets)) then
            for $key in map:keys($facets)
            let $value := map:get($facets, $key)
            order by $value ascending
            return
                map { $key: $value }
        else
            ()
    }
};

(:~
 : Build map for search query
 : Used by search functions to add facet query to search/browse queries. 
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

declare function sf:field-query() {
map:merge((
        $sf:sortFields
    ))
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

(:~
 : Used to lookup controlled values in the supplied odd file. See sf:facet-persNameLang() for an example
:)
declare function sf:odd2text($element as xs:string?, $label as xs:string?) as xs:string* {
    let $odd-path := $config:get-config//repo:odd/text()
    let $odd-file := 
                    if($odd-path != '') then
                        if(starts-with($odd-path,'http')) then 
                            hc:send-request(<hc:request href="{xs:anyURI($odd-path)}" method="get"/>)[2]
                        else doc($config:app-root || $odd-path)
                    else ()
    return 
        if($odd-path != '') then
            let $odd := $odd-file
            return 
                try {
                    if($odd/descendant::*[@ident = $element][1]/descendant::tei:valItem[@ident=$label][1]/tei:gloss[1]/text()) then 
                        $odd/descendant::*[@ident = $element][1]/descendant::tei:valItem[@ident=$label][1]/tei:gloss[1]/text()
                    else if($odd/descendant::tei:valItem[@ident=$label][1]/tei:gloss[1]/text()) then 
                        $odd/descendant::tei:valItem[@ident=$label][1]/tei:gloss[1]/text()
                    else ()    
                } catch * {
                    <error>Caught error {$err:code}: {$err:description}</error>
                }  
         else ()
};

(:~ 
 : Syriaca.org strip non sort characters for sorting 
 :)
declare function sf:build-sort-string($titlestring as xs:string?) as xs:string* {
    replace(normalize-space($titlestring),'^\s+|^[‘|ʻ|ʿ|ʾ]|^[tT]he\s+[^\p{L}]+|^[tT]he\s+|^[dD]e\s+|^[dD]e-|^[oO]n\s+[aA]\s+|^[oO]n\s+|^[aA]l-|^[aA]n\s|^[aA]\s+|^\d*\W|^[^\p{L}]','')
};

(: Custom search fields, some generic facets provided here, including for handling ranges, and arrays :)

(:~
 : Group by array is used for facets with multiple items in an attribute, common in TEI attributes.  
 :)
declare function sf:facet-group-by-array($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()    
    return tokenize(util:eval(concat('$element/',$xpath)),' ') 
};

(:~
 : Range facets 
 : Example range facet: 
    <range type="xs:year">
        <bucket lt="0001" name="BC dates" order="22"/>
        <bucket gt="1600-01-01" lt="1700-01-01" name="1600-1700" order="5"/>
        <bucket gt="1700-01-01" lt="1800-01-01" name="1700-1800" order="4"/>
        <bucket gt="1800-01-01" lt="1900-01-01" name="1800-1900" order="3"/>
        <bucket gt="1900-01-01" lt="2000-01-01" name="1900-2000" order="2"/>
        <bucket gt="2000-01-01" name="2000 +" order="1"/>
    </range>
:)
declare function sf:facet-range($element as item()*, $facet-definition as item(), $name as xs:string){
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

(:~
 : TEI Title field, specific to Srophe applications 
 :)
declare function sf:field-title($element as item()*,$name as xs:string){
(: Caesarea specific titles :)
    if($element/ancestor::tei:TEI/descendant::tei:profileDesc/tei:creation/tei:title[@type='uniform']) then 
        concat(sf:build-sort-string($element/ancestor::tei:TEI/descendant::tei:profileDesc/tei:creation/tei:title[@type='uniform']),' ',$element/ancestor::tei:TEI/descendant::tei:profileDesc/tei:creation/tei:title[@type='uniform']/following-sibling::tei:ref)
    else if($element/tei:biblStruct) then 
        if($element/tei:body/tei:biblStruct/descendant::tei:title[@level='a']) then 
            sf:build-sort-string($element/tei:biblStruct/descendant::tei:title[@level='a'][1])
        else sf:build-sort-string($element/tei:biblStruct/descendant::tei:title[1]) 
    else 
        sf:build-sort-string($element/ancestor::tei:TEI/descendant::tei:titleStmt/tei:title[1])
};

(:~
 : TEI title facet, specific to Srophe applications 
 :)
declare function sf:facet-title($element as item()*, $facet-definition as item()*, $name as xs:string){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:title
    else $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/tei:title
};

(:~
 : TEI author field, specific to Srophe applications 
 :)
declare function sf:field-author($element as item()*, $name as xs:string){
    if($element/ancestor-or-self::tei:TEI/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']) then 
        if($element/ancestor-or-self::tei:TEI/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']/tei:name[@sort]) then 
            normalize-space(string-join(
                for $name in $element/ancestor-or-self::tei:TEI/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']/child::*
                order by $name/@sort
                return $name
            ,' ')) 
        else if($element/ancestor-or-self::tei:TEI/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']/tei:surname) then
            $element/ancestor-or-self::tei:TEI/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']/tei:surname
        else $element/ancestor-or-self::tei:TEI/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']
    else if($element/ancestor-or-self::tei:TEI/descendant::tei:persName[@role='author']) then
        if($element/ancestor-or-self::tei:TEI/descendant::tei:persName[@role='author']/tei:surname) then
            $element/ancestor-or-self::tei:TEI/descendant::tei:persName[@role='author']/tei:surname
        else $element/ancestor-or-self::tei:TEI/descendant::tei:persName[@role='author']
    else if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct) then 
        if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:author/tei:surname) then 
            $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:author/tei:surname
        else if($element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:editor/tei:surname) then
            $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:editor/tei:surname
        else $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:author | $element/ancestor-or-self::tei:TEI/descendant::tei:biblStruct/descendant::tei:editor        
    else if($element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/tei:author[1]) then
        if($element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/tei:author[1]/descendant-or-self::tei:surname) then 
            $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/tei:author[1]/descendant-or-self::tei:surname[1]
        else $element/ancestor-or-self::tei:TEI/descendant::tei:author[1]
    else if($element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/tei:editor[1]) then
        if($element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/tei:editor[1]/descendant-or-self::tei:surname) then 
            $element/ancestor-or-self::tei:TEI/descendant::tei:titleStmt/tei:editor[1]/descendant-or-self::tei:surname[1]
        else $element/ancestor-or-self::tei:TEI/descendant::tei:editor[1]        
    else ()
};


(:~
 : TEI author field, specific to Srophe applications 
 :)
declare function sf:field-publicationDate($element as item()*, $name as xs:string){ 
$element/descendant::tei:biblStruct/descendant::tei:imprint/tei:date
(:
   let $date := $element/descendant::tei:biblStruct/descendant::tei:imprint/tei:date
   return 
        if(contains($date,',')) then 
        else ()
:)

};

(:~
 : TEI author facet, specific to Srophe bibl module
 :)
declare function sf:facet-biblAuthors($element as item()*, $facet-definition as item(), $name as xs:string){
    if($element/descendant::tei:biblStruct/descendant::tei:author) then 
        for $names in $element/descendant::tei:biblStruct/descendant::tei:author
        return 
            if($names/tei:surname) then
                concat($names/tei:surname,', ',$names/tei:forename)
            else $names
    else if($element/descendant::tei:biblStruct/descendant::tei:editor) then 
        for $names in $element/descendant::tei:biblStruct/descendant::tei:editor
        return 
            if($names/tei:surname) then
                concat($names/tei:surname,', ',$names/tei:forename)
            else $names
    else ()
};

(:~
 : Syriaca.org special facet for place and person types 
 :)
declare function sf:facet-type($element as item()*, $facet-definition as item(), $name as xs:string){
    if($element/descendant-or-self::tei:place/@type) then
        lower-case($element/descendant-or-self::tei:place/@type)    
    else if($element/descendant-or-self::tei:person/@ana) then
        for $type in tokenize(lower-case($element/descendant-or-self::tei:person/@ana),' ')
        return functx:capitalize-first(replace($type,'#syriaca-',''))
    else ()
};

(:~
 : Syriaca.org special field for place and person types 
 :)
declare function sf:field-type($element as item()*, $facet-definition as item(), $name as xs:string){
    if($element/descendant-or-self::tei:place/@type) then
        lower-case($element/descendant-or-self::tei:place/@type)    
    else if($element/descendant-or-self::tei:person/@ana) then
        tokenize(lower-case($element/descendant-or-self::tei:person/@ana),' ')
    else ()
};

(:~
 : Syriaca.org special facet for idno 
 :)
declare function sf:field-idno($element as item()*, $facet-definition as item(), $name as xs:string){
    $element/descendant-or-self::tei:idno[@type='URI'][starts-with(.,$config:base-uri)]    
};

(:~
 : Syriaca.org special facet for idno 
 :)
declare function sf:field-uri($element as item()*, $facet-definition as item(), $name as xs:string){
    $element/descendant-or-self::tei:idno[@type='URI'][starts-with(.,$config:base-uri)]    
};

(:~
 : Syriaca.org special facet for idno 
 : Get title from looking up Sryriaca.org idno. 
 : @note - does not work, perhaps because there is no index at the time of indexing? 
 :)
declare function sf:facet-idnoLookup($element as item()*, $facet-definition as item(), $name as xs:string){
    let $record := collection($config:data-root)//tei:idno[. = concat($element,'/tei')]
    let $title := $record/ancestor::tei:TEI/descendant::tei:title[1]
    return if($title != '') then $title else $element
};

(:~
 : Syriaca.org special facet for language of person names
 : Use  sf:odd2text() function to lookup controlled values in @xml:lang attribute
 :)
declare function sf:facet-persNameLang($element as item()*, $facet-definition as item(), $name as xs:string){
    for $l in $element/descendant::tei:person/tei:persName/@xml:lang
    return sf:odd2text('xmls:lang', $l[1])
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
    let $label := normalize-space(string-join($element/ancestor::tei:TEI/descendant::tei:category[@xml:id = $v]//text(),''))
    return if($label != '') then $label else if($label != ' ') then $label else $v
};

(: Get text value of a element with ref attribute :)
declare function sf:facet-refLabel($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()    
    let $value := util:eval(concat('$element/',$xpath))
    for $v in $value
    group by $facet-grp := normalize-space($v)
    return 
        let $label := $element//@ref[normalize-space(.) = $facet-grp]/parent::*[1]//text()
        return normalize-space(string-join($label,'')) 
};

(: Get text value of a element with ident attribute :)
declare function sf:facet-identLabel($element as item()*, $facet-definition as item(), $name as xs:string){
    let $xpath := $facet-definition/facet:group-by/facet:sub-path/text()    
    let $value := util:eval(concat('$element/',$xpath))
    return $value/parent::*[1][@ident=$value][1]//text() 
};

declare function sf:facet-workTestimonia($element as item()*, $facet-definition as item(), $name as xs:string){
    for $v in $element/ancestor::tei:TEI/descendant::tei:profileDesc/tei:creation/tei:title[@type='uniform']/@ref
    group by $facet-grp := normalize-space($v)
    return 
        if(string($facet-grp) != '') then 
            let $label := collection($config:data-root)//@ref[normalize-space(.) = $facet-grp][1]/parent::*[1]//text()
            return normalize-space(string-join($label[1],''))
        else 
            for $i in $v
            group by $facet-grp := normalize-space(string-join($v/parent::*[1]//text(),''))
            return $facet-grp
};

(:~
 : TEI author facet, specific to Srophe applications 
 :)
declare function sf:facet-authorTestimonia($element as item()*, $facet-definition as item(), $name as xs:string){
   for $v in $element/ancestor::tei:TEI/descendant::tei:profileDesc/tei:creation/tei:persName[@role='author']/@ref
    group by $facet-grp := normalize-space($v)
    return 
        if(string($facet-grp) != '') then         
            let $name := collection($config:data-root)//@ref[normalize-space(.) = $facet-grp][1]/parent::*[1]
            let $label := 
                if($name/tei:name[@sort]) then 
                        normalize-space(string-join(
                        for $n in $name[tei:name[@sort]][1]/child::*
                        order by $n/@sort
                        return $n,' '))
                else if($name/tei:surname) then
                    let $n := $name[tei:surname][1]
                    return concat($n/tei:surname,', ', $n[not(self::tei:surname)])
                else string-join($name[1]//text(),' ')
            return normalize-space(string-join($label[1],''))
        else 
            for $i in $v
            group by $facet-grp := normalize-space(string-join($v/parent::*[1]//text(),''))
            return $facet-grp
            (:
            
            for $i in $v
            let $name := $v/parent::*[1]
            let $label := 
                if($name/tei:name[@sort]) then 
                    normalize-space(string-join(
                        for $name in $name/child::*
                        order by $name/@sort
                        return $name
                    ,' ')) 
                else if($name/tei:surname) then
                    normalize-space(concat($name/tei:surname,', ', $name[not(self::tei:surname)] ))
                else normalize-space(string-join($name//text(),' '))
            group by $facet-grp := $label
            return $facet-grp
            :)
};