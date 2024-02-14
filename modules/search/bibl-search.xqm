xquery version "3.0";
(:~
 : Builds search information for spear sub-collection
 : Search string is passed to search.xqm for processing.  
 :)
module namespace bibls="http://srophe.org/srophe/bibls";
import module namespace functx="http://www.functx.com";

import module namespace config="http://srophe.org/srophe/config" at "../config.xqm";
import module namespace data="http://srophe.org/srophe/data" at "../lib/data.xqm";
import module namespace global="http://srophe.org/srophe/global" at "../lib/global.xqm";
import module namespace sf="http://srophe.org/srophe/facets" at "../lib/facets.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $bibls:idno {request:get-parameter('idno', '')};
declare variable $bibls:subject {request:get-parameter('subject', '')};
declare variable $bibls:id-type {request:get-parameter('id-type', '')};
declare variable $bibls:publisher {request:get-parameter('publisher', '')};
declare variable $bibls:date {request:get-parameter('date', '')};
declare variable $bibls:start-date {request:get-parameter('start-date', '')};
declare variable $bibls:end-date {request:get-parameter('end-date', '')};
declare variable $bibls:online {request:get-parameter('online', '')};

declare variable $bibls:ft-query-options := map {
    "default-operator": "and",
    "phrase-slop": 1,
    "leading-wildcard": "yes",
    "filter-rewrite": "yes"
};


(:
 : NOTE: Forsee issues here if users want to seach multiple ids at one time. 
 : Thinking of how this should be enabled. 
:)
declare function bibls:idno() as xs:string? {
    if($bibls:idno != '') then  
            if($bibls:id-type != '') then concat("[descendant::tei:idno[@type='",$bibls:id-type,"'][matches(.,'",$bibls:idno,"$')]]")
            else concat("[descendant::tei:idno[matches(.,'",$bibls:idno,"$')]]")        
    else ()    
};

declare function bibls:format-dates($date as xs:string?){
let $date := substring($date,1,4)
return 
    if(matches($date,'\d{4}')) then concat($date,'-01-01')
    else if(matches($date,'\d{3}')) then concat('0',$date,'-01-01')
    else if(matches($date,'\d{2}')) then concat('00',$date,'-01-01')
    else if(matches($date,'\d{1}')) then concat('000',$date,'-01-01')
    else '0100-01-01'
};
(:~     
 : Build query 
:)
declare function bibls:query() {                 
    let $sort := if(request:get-parameter('sort-element', '') != '') then
                    request:get-parameter('sort-element', '')
                 else ()
    let $fields := 
        string-join(for $p in request:get-parameter-names()
        where request:get-parameter($p, '') != ''
        return 
            if($p = 'title') then concat("title:", data:clean-string(request:get-parameter($p, '')))
            else if($p = 'author') then concat("author:", data:clean-string(request:get-parameter($p, '')))
            else if($p = 'pub-place') then concat("pubPlace:", data:clean-string(request:get-parameter($p, '')))
            else if($p = 'publisher') then concat("publisher:", data:clean-string(request:get-parameter($p, '')))
            else if($p = 'online' and request:get-parameter($p, '') = 'on') then "online:on"
            else (),' AND ')            
    let $query-configuration := 
        map {
            "fields": $sf:sortFields,
            "facets": sf:facets(),
            "query-string": $fields
        } 
    let $query-options := 
        map:merge((
            $bibls:ft-query-options,
            $query-configuration?fields,
            $query-configuration?facets
        ))
    let $keyword := 
        if(request:get-parameter('keyword', '') != '') then 
            if($fields != '') then 
                concat(data:clean-string(request:get-parameter('keyword', '')), ' AND ', $fields)
            else data:clean-string(request:get-parameter('keyword', '')) 
        else if($fields != '') then $fields 
        else ()
    let $subject := 
        if(request:get-parameter('subject', '') != '') then data:clean-string(request:get-parameter('subject', ''))
        else ()
    let $startDate := if(request:get-parameter('start-date','') != '') then bibls:format-dates(request:get-parameter('start-date','')[1])
                      else if(request:get-parameter('startDate','') != '') then bibls:format-dates(request:get-parameter('startDate','')[1])
                      else ()
    let $endDate :=   if(request:get-parameter('end-date','') != '') then bibls:format-dates(request:get-parameter('end-date','')[1])
                      else if(request:get-parameter('endDate','') != '') then bibls:format-dates(request:get-parameter('endDate','')[1])
                      else ()                                
    let $hits := 
        if($startDate and $endDate) then 
            collection($config:data-root || '/bibl/tei')//tei:TEI[descendant::tei:idno[. = 'https://caesarea-maritima.org/bibl/comprehensive']]
            [ft:query(.,  $keyword, $query-options)]
            [descendant::tei:imprint/tei:date[(. >= $startDate) and (. <= $endDate)]]
        else if($startDate and not($endDate)) then
            collection($config:data-root || '/bibl/tei')//tei:TEI[descendant::tei:idno[. = 'https://caesarea-maritima.org/bibl/comprehensive']]
            [ft:query(.,  $keyword, $query-options)]
            [descendant::tei:imprint/tei:date[(. >= $startDate)]]
        else if($endDate and not($startDate)) then
            collection($config:data-root || '/bibl/tei')//tei:TEI[descendant::tei:idno[. = 'https://caesarea-maritima.org/bibl/comprehensive']]
            [ft:query(.,  $keyword, $query-options)]
            [descendant::tei:imprint/tei:date[(. <= $endDate)]]
        else collection($config:data-root || '/bibl/tei')//tei:TEI[descendant::tei:idno[. = 'https://caesarea-maritima.org/bibl/comprehensive']][ft:query(.,  $keyword, $query-options)]
    for $hit in $hits
    let $s :=
        if(contains($sort, 'author')) then ft:field($hit, "author")[1]
        else if($sort = 'pubDate') then  ft:field($hit, "pubDate")[1]
        else if(contains($sort, 'title')) then ft:field($hit, "title")[1]
        else ft:score($hit)  
    order by $s ascending
    return $hit
};

(:~
 : Build a search string for search results page from search parameters
:)
declare function bibls:search-string(){
    let $parameters :=  request:get-parameter-names()
    for  $parameter in $parameters
        return 
            if(request:get-parameter($parameter, '') != '') then
                if($parameter = 'start' or $parameter = 'sort-element') then ()
                else if($parameter = 'q') then 
                    (<span class="param">Keyword: </span>,<span class="match">{request:get-parameter($parameter, '')}&#160; </span>)
                else if ($parameter = 'author') then 
                    (<span class="param">Author/Editor: </span>,<span class="match">{$bibls:author}&#160; </span>)
                else if ($parameter = 'subject-exact') then 
                    (<span class="param">Subject: </span>,<span class="match">{request:get-parameter($parameter, '')}&#160; </span>)    
                else (<span class="param">{replace(concat(upper-case(substring($parameter,1,1)),substring($parameter,2)),'-',' ')}: </span>,<span class="match">{request:get-parameter($parameter, '')}&#160; </span>)    
            else ()               
};

(: BA specific function to list all available subjects for dropdown list in search form :)
declare function bibls:get-subjects(){
 for $s in collection($config:data-root)//tei:relation[@ref='dc:subject']/descendant::tei:desc
 group by $subject-facet := $s/text()
 order by global:build-sort-string($subject-facet,'')
 return <option value="{$subject-facet}">{$subject-facet}</option>
};

(:~
 : Builds advanced search form for persons
 :)
declare function bibls:search-form() {   
<form method="get" action="{$config:nav-base}/bibl/search.html" xmlns:xi="http://www.w3.org/2001/XInclude"  class="form-horizontal" role="form">
    <div class="well well-small">
        {let $search-config := 
                if(doc-available(concat($config:app-root, '/bibl/search-config.xml'))) then concat($config:app-root, '/bibl/search-config.xml')
                else concat($config:app-root, '/search-config.xml')
            let $config := 
                if(doc-available($search-config)) then doc($search-config)
                else ()                            
            return 
                if($config != '' or doc-available($config:app-root || '/searchTips.html')) then 
                    (<button type="button" class="btn btn-info pull-right clearfix search-button" data-toggle="collapse" data-target="#searchTips">
                        Search Help <span class="glyphicon glyphicon-question-sign" aria-hidden="true"></span></button>,                       
                    if($config//search-tips != '') then
                        <div class="panel panel-default collapse" id="searchTips">
                            <div class="panel-body">
                            <h3 class="panel-title">Search Tips</h3>
                            {$config//search-tips}
                            </div>
                        </div>
                    else if(doc-available($config:app-root || '/searchTips.html')) then doc($config:app-root || '/searchTips.html')
                    else ())
                else ()}
        <div class="well well-small search-inner well-white">
        <!-- Keyword -->
            <div class="form-group">            
                <label for="q" class="col-sm-2 col-md-3  control-label">Keyword: </label>
                <div class="col-sm-10 col-md-6 ">
                    <div class="input-group">
                        <input type="text" id="qs" name="q" class="form-control keyboard" placeholder="Any word in citation"/>
                        <div class="input-group-btn">{global:keyboard-select-menu('qs')}</div>
                    </div>                 
                </div>
            </div> 
            <hr/>         
            <div class="form-group">            
                <label for="title" class="col-sm-2 col-md-3  control-label">Title: </label>
                <div class="col-sm-10 col-md-6 ">
                    <div class="input-group">
                        <input type="text" id="title" name="title" class="form-control keyboard"  placeholder="Title of article, journal, book, or series"/>
                        <div class="input-group-btn">{global:keyboard-select-menu('title')}</div>
                    </div>                 
                </div>
            </div>
            <div class="form-group">            
                <label for="author" class="col-sm-2 col-md-3  control-label">Author/Editor: </label>
                <div class="col-sm-10 col-md-6 ">
                    <div class="input-group">
                        <input type="text" id="author" name="author" class="form-control keyboard" placeholder="First Last or Last, First"/>
                        <div class="input-group-btn">{global:keyboard-select-menu('author')}</div>
                    </div>                
                </div>
            </div>  
            <!--
            <div class="form-group">            
                <label for="subject" class="col-sm-2 col-md-3  control-label">Subject: </label>
                <div class="col-sm-10 col-md-6 ">
                    <div class="input-group">
                        <input type="text" id="subject" name="subject" class="form-control keyboard"  placeholder="Subject"/>
                        <div class="input-group-btn">
                                <button type="button" class="btn btn-default dropdown-toggle" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false" title="Select Keyboard">
                                    &#160;<span class="syriaca-icon syriaca-keyboard">&#160; </span><span class="caret"/>
                                </button>
                                {global:keyboard-select-menu('subject')}
                        </div>
                    </div>                 
                </div>
            </div>        
            <div class="form-group">            
                <label for="subject-exact" class="col-sm-2 col-md-3  control-label">Select Subject: </label>
                <div class="col-sm-10 col-md-6 ">
                    <div class="input-group">
                    <select name="subject-exact">
                        <option value="">Any subject</option>
                        {bibls:get-subjects()}
                    </select>
                    </div>                 
                </div>
            </div>
            <div class="form-group">            
                <label for="mss" class="col-sm-2 col-md-3  control-label">Manuscript: </label>
                <div class="col-sm-10 col-md-6 ">
                    <div class="input-group">
                        <input type="text" id="mss" name="mss" class="form-control keyboard"  placeholder="Manuscript"/>
                        <div class="input-group-btn">{global:keyboard-select-menu('mss')}</div>
                    </div>                 
                </div>
            </div>        
              -->
            <div class="form-group">            
                <label for="pub-place" class="col-sm-2 col-md-3  control-label">Publication Place: </label>
                <div class="col-sm-10 col-md-6 ">
                    <div class="input-group">
                        <input type="text" id="pubPlace" name="pub-place" class="form-control keyboard" placeholder="Place Name"/>
                        <div class="input-group-btn">{global:keyboard-select-menu('pubPlace')}</div>
                    </div>                
                </div>
            </div>
            <div class="form-group">            
                <label for="publisher" class="col-sm-2 col-md-3  control-label">Publisher: </label>
                <div class="col-sm-10 col-md-6 ">
                    <div class="input-group">
                    <input type="text" id="publisher" name="publisher" class="form-control keyboard" placeholder="Publisher Name"/>
                    <div class="input-group-btn">{global:keyboard-select-menu('publisher')}</div>
                    </div>                 
                </div>
            </div>
            <!--
            <div class="form-group">            
                <label for="date" class="col-sm-2 col-md-3  control-label">Date: </label>
                <div class="col-sm-10 col-md-6 ">
                    <input type="text" id="date" name="date" class="form-control" placeholder="Year as YYYY"/>
                </div>
            </div> 
            -->
            <div class="form-group">
                <label for="start-date" class="col-sm-2 col-md-3  control-label">Date: </label>
                <div class="col-sm-10 col-md-6 form-inline">
                    <input type="text" id="start-date" name="start-date" placeholder="Start Date" class="form-control"/>&#160;
                    <input type="text" id="end-date" name="end-date" placeholder="End Date" class="form-control"/>&#160;
                    <p class="hint">* Dates should be entered as YYYY or YYYY-MM-DD. Add a minus sign (-) in front of BCE dates. <span><a href="$nav-base/documentation/wiki.html?wiki-page=/Encoding-Guidelines-for-Approximate-Dates&amp;wiki-uri=https://github.com/srophe/caesarea-data/wiki">more <i class="glyphicon glyphicon-circle-arrow-right"></i></a></span></p>
                </div>
            </div>  
            <hr/>
            <div class="form-group">            
                <label for="idno" class="col-sm-2 col-md-3  control-label">ISBN / DOI / URI: </label>
                <div class="col-sm-10 col-md-2 ">
                    <input type="text" id="idno" name="idno" class="form-control"  placeholder="Ex: 3490"/>
                </div>
            </div>
            <div class="form-group">     
                <label for="idno" class="col-sm-2 col-md-3  control-label">Only items viewable online: </label>
                <div class="col-sm-10 col-md-2 ">
                    <label class="switch">
                        <input id="online" name="online" type="checkbox"/>
                        <span class="slider round"></span>
                    </label>
                </div>
            </div> 
        </div>
        <div class="pull-right">
            <button type="submit" class="btn btn-info">Search</button>&#160;
            <button type="reset" class="btn">Clear</button>
        </div>
        <br class="clearfix"/><br/>
    </div>
</form>
};