(:
 : Linked Data Box
:)
declare %templates:wrap function app:linkedData($node as node(), $model as map(*)){
    let $data := $model("hits")
    let $places := $data/descendant::*[starts-with(@ref, 'https://pleiades.stoa.org/places')]
    let $persons := $data/descendant::*[starts-with(@ref,'http://viaf.org/viaf/')]
    let $history := $data/descendant::tei:teiHeader/tei:profileDesc/tei:creation/tei:title[@ref]
    let $bibl := $data/descendant::tei:bibl[tei:ptr]
    let $connections := count(distinct-values(($places/@ref,$persons/@ref,$bibl/tei:ptr/@target)))
    return 
    <div class="panel panel-default" style="margin-top:1em;" xmlns="http://www.w3.org/1999/xhtml">
        <div class="panel-heading"><a href="#" data-toggle="collapse" data-target="#showLinkedData">Linked Data  </a>
            <span class="glyphicon glyphicon-question-sign text-info moreInfo" aria-hidden="true" data-toggle="tooltip" title="This sidebar provides links via Syriaca.org to 
            additional resources beyond this record. 
            We welcome your additions, please use the e-mail button on the right to contact Syriaca.org about submitting additional links."></span>
            <button class="btn btn-default btn-xs pull-right" data-toggle="modal" data-target="#submitLinkedData" style="margin-right:1em;"><span class="glyphicon glyphicon-envelope" aria-hidden="true"></span></button>
        </div>
        <div class="panel-body">
        <p>This record has {$connections} connections.</p>
        <ul class="no-indent">{(
            for $p in $places
            group by $placeID := $p/@ref
            return
                <li>{$p[1]/text()}
                    <ul>
                        <li><a href="{$placeID}">Pleiades Gazetteer Entry</a></li>
                        <li><a href="{concat('https://peripleo.pelagios.org/ui#selected=',$placeID)}">Search Peripleo Linked Data</a></li>
                    </ul>
                </li>,
            for $a in $persons
            group by $persID := $a/@ref
            return 
                <li>{$a[1]/text()}
                    <ul>
                        <li><a href="{$persID}">VIAF Entry</a></li>
                        <li><a href="{concat('https://www.worldcat.org/identities/find?fullName=',$a[1]/text())}">Search WorldCat Identities</a></li>
                    </ul>
                </li>,
            if($bibl) then
                <li>Bibliography
                    <ul>{
                        for $b in $bibl
                        group by $biblID := $b/tei:ptr/@target
                        return 
                            <li><a href="{$biblID}">{$b[1]/tei:title/text()}</a></li>
                    }</ul>
                </li>
            else ()
                
        )}</ul>
        </div>
    </div>
};
