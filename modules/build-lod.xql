xquery version "3.1";
(:~  
 : Build GeoJSON file for all placeNames/@key  
 : NOTE: Save file to DB, rerun occasionally? When new data is added? 
 : Run on webhook activation, add new names, check for dups. 
:)

import module namespace config="http://syriaca.org/srophe/config" at "config.xqm";
import module namespace http="http://expath.org/ns/http-client";

import module namespace functx="http://www.functx.com";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace json = "http://www.json.org";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace util="http://exist-db.org/xquery/util";


(:lat long:)
declare function local:make-place($nodes as node()*){
let $places := collection($config:data-root)//tei:placeName[@ref] | collection($config:data-root)//tei:origPlace[@ref]
for $place in $places
group by $place-grp := $place/@ref
return 
    if($place-grp != '' and starts-with($place-grp, 'https://pleiades.stoa.org')) then 
        let $url := concat($place-grp,'/json')        	
        let $placeData :=
            try{
                util:base64-decode(hc:send-request(<http:request http-version="1.1"  href="{xs:anyURI($url)}" method="get"/>)[2])
            } catch * {
                <response status="fail">
                    <message>{concat($err:code, ": ", $err:description)}</message>
                </response>
            }
        let $json := if(xs:string($placeData)) then parse-json($placeData) else $placeData    
        return 
            <place xmlns="http://www.tei-c.org/ns/1.0" xmlns:srophe="https://srophe.app">
                <idno>{string($place-grp)}</idno>
                <placeName srophe:tags="#headword">{$json?title}</placeName>
                <desc>{$json?description}</desc>
                <location type="gps">
                    <geo>{
                        let $points := $json?reprPoint
                        return concat($points?1,' ', $points?2)
                    }</geo>
                </location>
                <listRelation>{
                    for $recs in $place
                    let $id := root($recs)/descendant::tei:publicationStmt/tei:idno[@type='URI'][1]
                    group by $facet-grp := $id
                    let $relationType := 
                        if($recs/ancestor-or-self::tei:origPlace) then 'Place of Origin'
                        else 'Mention'
                    return 
                        <relation type="{$relationType}" ana="{$relationType}" active="{$facet-grp}" passive="{$place-grp}">
                          <desc>{root($recs[1])//tei:titleStmt/tei:title}</desc>
                        </relation>
          }</listRelation>
            </place>
    else () 
};

declare function local:make-record($nodes as node()*){
    <TEI xmlns="http://www.tei-c.org/ns/1.0" xmlns:srophe="https://srophe.app">
        <text>
            <body>{
                if(request:get-parameter('content', '') = 'geojson') then
                       <listPlace>{local:make-place(())}</listPlace> 
                    else if(request:get-parameter('content', '') = 'person') then
                        <listPerson>{(:local:make-person(()):)''}</listPerson>
                    else () 
                }</body>
        </text>
    </TEI>
};

(: 
 Actions needed by script
 1. Create: create new geojson record from TGN SPARQL endpoint
 2. Update: update geojson record as new records are added/edited (use webhooks)
 3. Link: add links to TEI that reference the places
:)
if(request:get-parameter('action', '') = 'create') then
    try {
        if(request:get-parameter('content', '') = 'geojson') then
            (: add single record option here, or data from webhook if() then else () :)
            let $f := local:make-record(())
            return xmldb:store(concat($config:app-root,'/resources/lodHelpers'), xmldb:encode-uri('placeNames.xml'), $f)
        else if(request:get-parameter('content', '') = 'person') then
            let $f := local:make-record(())
            return xmldb:store(concat($config:app-root,'/resources/lodHelpers'), xmldb:encode-uri('persNames.xml'), $f)
        else ()
    } catch *{
        <response status="fail">
            <message>{concat($err:code, ": ", $err:description)}</message>
        </response>
    } 
    
else if(request:get-parameter('action', '') = 'update') then
    try {
        'what do we do here?'
    } catch *{
        <response status="fail">
            <message>{concat($err:code, ": ", $err:description)}</message>
        </response>
    } 
else <div>In progress</div>

