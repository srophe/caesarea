xquery version "3.0";
(:~ 
 : Date slider
 : Add jquery.js, jquery-ui.min.js, jQDateRangeSlider-min.js to page header. 
 : 
 : @dependencies
 :   jQRangeSlider javascript library
 :      https://github.com/ghusse/jQRangeSlider
 :   JQuery
 :       https://jquery.com/
 :   jQuery UI
 :      https://jqueryui.com/
 : 
 : @author Winona Salesky
 : @version 1.0 
 :
 :)

module namespace slider = "http://srophe.org/srophe/slider";
import module namespace global="http://srophe.org/srophe/global" at "global.xqm";

declare namespace facet="http://expath.org/ns/facet";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $slider:start {
    if(request:get-parameter('start-date', '')) then request:get-parameter('start-date', '')
    else if(request:get-parameter('startDate', '')) then request:get-parameter('startDate', '')
    else ()
    };
declare variable $slider:end {
    if(request:get-parameter('end-date', '')) then request:get-parameter('end-date', '')
    else if(request:get-parameter('endDate', '')) then request:get-parameter('endDate', '')
    else ()
    };

(:
 : Build date filter for date slider. 
 : @param $startDate
 : @param $endDate
 : @param $collection for finding facet definition file
:)
declare function slider:date-filter($collection) {
let $facet-config := global:facet-definition-file($collection)
let $slider := $facet-config/descendant-or-self::*[@display = 'slider']
let $xpath := $slider/facet:group-by/facet:sub-path/text()
let $startDate := $slider:start
let $endDate := $slider:end
return 
    if(not(empty($startDate)) and not(empty($endDate))) then
        if($slider != '') then 
            if(starts-with($xpath,'descendant') or starts-with($xpath,'/descendant')) then
                concat('[',$xpath,'[(. >= "', $startDate,'" and . <= "', $endDate,'")]]')
            else concat('[descendant::',$xpath,'[(. >= "', $startDate,'" and . <= "', $endDate,'")]]')
        else
           concat('[descendant::tei:state[@type="existence"][
            (@from >= "', $startDate,'" and @from <= "', $endDate,'") and
            (@to >= "', $startDate,'" and @to <= "', $endDate,'")
            ]]')
    else ()
};



(:
 : Date slider functions
:)
(:~
 : Check dates for proper formatting, conver negative dates to JavaScript format
 : @param $dates accepts xs:gYear (YYYY) or xs:date (YYYY-MM-DD)
:)
declare function slider:expand-dates($date){
let $year := 
        if(matches($date, '^\-')) then 
            if(matches($date, '^\-\d{6}')) then $date
            else replace($date,'^-','-00')
        else if(matches($date, '\-')) then   
            if(matches($date, '^\d{4}-\d{2}-\d{2}')) then $date
            else substring-before($date,'-')
        else $date
return       
    if($year castable as xs:date) then 
         $year
    else if($year castable as xs:gYear) then  
        concat($year, '-01-02')
    else if(matches($year,'^0000')) then  '0001-01-02'
    else ()
};

(:~
 : Build Javascript Date Slider. 
 : @param $hits node containing all hits from search/browse pages
 : @param $mode selects which date element to use for filter. Current modes are 'inscription' and 'bibl'
:)
declare function slider:browse-date-slider($hits, $mode as xs:string?){                  
(: Dates in current results set :)  
let $d := 
        if($mode) then 
            for $date in util:eval(concat('$hits/',$mode))
            let $expanded := slider:expand-dates($date) 
            order by xs:date($expanded)
            return $expanded    
        else 
            for $date in $hits/descendant::tei:state[@type="existence"]/@to | $hits/descendant::tei:state[@type="existence"]/@from
            let $expanded := slider:expand-dates($date) 
            order by xs:date($expanded) 
            return $expanded    
let $startDate := if($slider:start != '') then $slider:start else $d[1]
let $endDate := if($slider:end != '') then $slider:end else $d[last()]
let $min := if($startDate) then 
                slider:expand-dates($startDate) 
            else slider:expand-dates(xs:date(slider:expand-dates(string($d[1]))))
let $max := 
            if($endDate) then slider:expand-dates($endDate) 
            else slider:expand-dates(xs:date(slider:expand-dates(string($d[last()]))))        
let $minPadding := slider:expand-dates((xs:date(slider:expand-dates(string($d[1]))) - xs:yearMonthDuration('P10Y')))
let $maxPadding := slider:expand-dates((xs:date(slider:expand-dates(string($d[last()]))) + xs:yearMonthDuration('P10Y')))
let $params := 
    string-join(
    for $param in request:get-parameter-names()
    return 
        if($param = 'startDate' or $param = 'endDate' or $param = 'start' or $param = 'start-date' or $param = 'end-date') then ()
        else if(request:get-parameter($param, '') = ' ') then ()
        else 
            for $p in request:get-parameter($param, '')
            return concat('&amp;',$param[1], '=',request:get-parameter($p, '')),'')
return 
if(not(empty($d))) then
    <div>
        <h4 class="slider">Date range</h4>
        <div class="sliderContainer">
        <div id="slider"/>
        {if($startDate != '') then
                (<br/>,<a href="?start=1{$params}" class="btn btn-warning btn-sm" role="button"><i class="glyphicon glyphicon-remove-circle"></i> Reset Dates</a>,<br/>)
        else()}
        <script type="text/javascript">
        <![CDATA[
            var minPadding = "]]>{$minPadding}<![CDATA["
            var maxPadding = "]]>{$maxPadding}<![CDATA["
            var minValue = "]]>{$min}<![CDATA["
            var maxValue = "]]>{$max}<![CDATA["
            $("#slider").dateRangeSlider({  
                            bounds: {
                                       min:  new Date(minPadding),
                                   	max:  new Date(maxPadding)
                                   	},
                            defaultValues: {min: new Date(minValue), max: new Date(maxValue)},
                            //values: {min: new Date(minValue), max: new Date(maxValue)},
    		        		formatter:function(val){
    		        		     var year = val.getFullYear();
    		        		     return year;
    		        		}
                });
            console.log('minValue:' + minValue);
            
                $("#slider").bind("userValuesChanged", function(e, data){
                    var url = window.location.href.split('?')[0];
                    var minDate = data.values.min.toISOString().split('T')[0]
                    var maxDate = data.values.max.toISOString().split('T')[0]
                    console.log(url + "?startDate=" + minDate + "&endDate=" + maxDate + "]]> {$params} <![CDATA[");
                    window.location.href = url + "?startDate=" + minDate + "&endDate=" + maxDate + "]]> {$params} <![CDATA[" ;
                    //$('#browse-results').load(window.location.href + "?startDate=" + data.values.min.toISOString() + "&endDate=" + data.values.max.toISOString() + " #browse-results");
                });
            ]]>
        </script>     
        </div>
    </div>
else ()
};
 
