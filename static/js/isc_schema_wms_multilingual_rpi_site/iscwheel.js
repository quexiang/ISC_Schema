//For background infromation about D3.js go to: https://github.com/mbostock/d3/wiki/API-Reference
var w = 780,
    h = w,
    r = w / 2,
    x = d3.scale.linear().range([0, 2 * Math.PI-0.08]),  //(start at 0.08  to set a break in the wheel <- time is not a closed wheel
    y = d3.scale.pow().exponent(1.3).domain([0, 1]).range([0, r]),
    p = 2,
    duration = 1000;

var VizFunctionSwitch = 0;   //a switch to trigger different functions in the click function of the Viz, 0-sparql query, 1-spaql query and sld file to wms map layer

var langId = "en";	
	
var div = d3.select("#vis"); //select the div in the html file

var vis = div.append("svg")
    .attr("width", w + p * 20)
    .attr("height", h + p * 20)
    .append("g")
    .attr("transform", "translate(" + (r + p * 10) + "," + (r + p * 10) + ")");

div.append("p")
    .attr("id", "intro");
//    .text("Click to zoom!");

var partition = d3.layout.partition()
    .sort(null)
//	.size([2 * Math.PI, w/2])	
    .value(function(d) { return 1; });  //return 'return 5.8 - d.depth' shows a falut result

// x - start Angle, dx - extent between start and end Angle		   >>> of a arc 'cell'
// y - inner Radius, dy - extent between inner and outer Radius    >>> of a arc 'cell'
var arc = d3.svg.arc()
    .startAngle(function(d) { return Math.max(0, Math.min(2 * Math.PI-0.08, x(d.x))); })
    .endAngle(function(d) { return Math.max(0, Math.min(2 * Math.PI-0.08, x(d.x + d.dx))); })
    .innerRadius(function(d) { return Math.max(0, d.y ? y(d.y) : d.y); })
    .outerRadius(function(d) { return Math.max(0, y(d.y + d.dy)); });

var jsonDoc = "../static/js/isc_schema_wms_multilingual_rpi_site/iscwheel.json";
	
d3.json(jsonDoc, initialJson);

function initialJson(json) {
  var nodes = partition.nodes({children: json});

  var path = vis.selectAll("path").data(nodes);  //these are the cells on the user interface
  path.enter()
	  .append("path")
      .attr("id", function(d, i) { return "path-" + i; })
	  .attr("pathname", function(d, i) { return d.name; })
      .attr("d", arc) // see the defintion of 'arc'
      .attr("fill-rule", "evenodd")
      .style("fill", colour)
	  .style("stroke", "#ffffff")
	  //.style("stroke-opacity", 0.5)   //more styles:  * the display attribute  * the opacity style   * the fill-opacity and stroke-opacity styles
	  .style("stroke-width",1)
	  .on("mouseover", mouseoverpath)//
	  .on("mouseout", mouseoutpath)  
	  
      .on("click", click);  

  var text = vis.selectAll("text").data(nodes);  //these are the labels in the cells on the user interface
  var textEnter = text.enter()
      .append("text")
	  .attr("id", function(d, i) { return "text-" + i; }) //give each text object an id
	  .attr("textname", function(d, i) { return d.name; })
      .style("fill-opacity", 1)
      .style("fill", function(d) {
        return brightness(d3.rgb(colour(d))) < 125 ? "#fff" : "#000"; //change the color of text to contrast with background color
      })
	  
	  // x - start Angle, dx - extent between start and end Angle		 >>> of a arc 'cell'
	  // y - inner Radius, dy - extent between inner and outer Radius    >>> of a arc 'cell'
      .attr("text-anchor", function(d) {
        return x(d.x + d.dx / 2) > Math.PI ? "end" : "start";   //x(d.x + d.dx / 2) is the angle of the text object
      })
      .attr("dy", ".2em")
      .attr("transform", function(d) {
        var multiline = (d.name || "").split(" ").length > 1,
            angle = x(d.x + d.dx / 2) * 180 / Math.PI - 90,
			endorstart = x(d.x + d.dx / 2) > Math.PI ? 0.5 : -0.5,   //differnt rotation settings for multiline text objects anchored to end or to start
			rotate = angle + (multiline ? endorstart : 0);
        return "rotate(" + rotate + ")translate(" + (y(d.y) + p) + ")rotate(" + (angle > 90 ? -180 : 0) + ")";
      })
	  
	  .on("mouseover", mouseovertext)
	  .on("mouseout", mouseouttext)
	  
	  .on("click", click);
  
  textEnter.append("tspan")
      .attr("x", 0)
      .text(function(d) { return d.depth ? d.name.split(" ")[0] : ""; });
  textEnter.append("tspan")
      .attr("x", 0)
      .attr("dy", "1em")
      .text(function(d) { return d.depth ? d.name.split(" ")[1] || "" : ""; });
	  
  function click(d) {
	//alert (d.name);
	document.getElementById('DBpediaLink').innerHTML = '<br /><a href="http://www.dbpedia.org" target="_blank">DBpedia</a>';
	document.getElementById('GeoscimlLink').innerHTML = '<br /><a href="http://resource.geosciml.org/classifierscheme/ics/ischart/2010" target="_blank">GeoSciML Vocabulary</a>';
    document.getElementById('WikipediaLink').innerHTML = '<br /><a href="http://www.wikipedia.org" target="_blank">Wikipedia</a>';
	document.getElementById('DBpediaQuery').innerHTML = "";
	// here need (1) a global variable to store the language code of map and 
	//(2) function to get a label (in the language of the map) for SLD to be sent back to the map  
	sparqlQuery(d.name); 
	
	//alert (VizFunctionSwitch);
	if (VizFunctionSwitch ==1) //build an sld file and sent to wms map layer
	{ 
	//alert(d.name); alert (d.colour);
		var sldBgn = '<?xml version="1.0" encoding="UTF-8"?><sld:StyledLayerDescriptor version="1.0.0" xmlns="http://www.opengis.net/ogc" xmlns:sld="http://www.opengis.net/sld" xmlns:ogc="http://www.opengis.net/ogc" xmlns:gml="http://www.opengis.net/gml" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd"><sld:NamedLayer><sld:Name>GBR_BGS_625k_BA</sld:Name><sld:UserStyle><sld:FeatureTypeStyle>';
		var sldEnd = '</sld:FeatureTypeStyle></sld:UserStyle></sld:NamedLayer></sld:StyledLayerDescriptor>';
				
		var ptyEqualToNameBgn = '<sld:Rule><ogc:Filter><ogc:PropertyIsEqualTo><ogc:PropertyName>';
		var ptyEqualToNameEndValueBgn = '</ogc:PropertyName><ogc:Literal>';
		var ptyEqualToVauleEndFillBgn = '</ogc:Literal></ogc:PropertyIsEqualTo></ogc:Filter><sld:PolygonSymbolizer><sld:Fill><sld:CssParameter name="fill">';
		var ptyEqualToFillEnd = '</sld:CssParameter><sld:CssParameter name="fill-opacity">1</sld:CssParameter></sld:Fill></sld:PolygonSymbolizer></sld:Rule>';
		var filterByTermSpt = ptyEqualToNameBgn + "AGE_ONEGL" + ptyEqualToNameEndValueBgn + d.name.toUpperCase() + 
								 ptyEqualToVauleEndFillBgn + d.colour + ptyEqualToFillEnd;  //get a part of the SLD_BODY text as a xml script
  
		document.getElementById('filterSLDtoWMS').value = sldBgn+ filterByTermSpt + sldEnd;   //do not forget heard and tail, show the SLD_BODY xml in the textbox on user interface
		updateFilterSLDtoWMS();  //filter the map	
	}
  }                            
}

function updateFilterSLDtoWMS() {

	var filter = document.getElementById('filterSLDtoWMS').value;
                
	// by default, reset all filter
	var filterParams = {
		SLD_BODY: null,
		CQL_FILTER: null,
		FILTER: null,
		SLD: null
    };
				
    if (OpenLayers.String.trim(filter) != "") 
	{
		filterParams["SLD_BODY"] = filter.toString();					
    }
    // merge the new filter definitions
    ukbedrockageTiled.mergeNewParams(filterParams);
	ukbedrockageUntiled.mergeNewParams(filterParams);
}

function sparqlQuery(inputLabel){
	//sparql query sent to graph isc2010test (original vocabulary developed by Simon Cox-creator of GeoSciML geologic time ontology) on TW site; results seralized in JSON format
	/* the query is like this, the program replace the label and language code with variables
	//using the union to tolerate labels like "Upper Triassic", because in the triple store
	//the corresponding label is "Late/Upper Triassic". By setting the conditions in the union
	//we can find the concept even a input label is not in English
	prefix skos: <http://www.w3.org/2004/02/skos/core#> 
	prefix gts: <http://resource.geosciml.org/schema/cgi/gts/3.0/> 
	select ?cpt
	where
	{
	graph<http://sparql.tw.rpi.edu/20120831/isc2010test>
	{
	{
	?cpt a gts:GeochronologicEra.
	?cpt skos:prefLabel "Triassic"@en.
	}
	union
	{
	?cpt a gts:GeochronologicEra.
	?cpt skos:prefLabel ?name.
	filter regex("Triassic", " ")
	filter regex(?name, "Triassic")
	}
	}
	}	
	*/	
	var TWqueryUrl = 'http://sparql.tw.rpi.edu/virtuoso/sparql?default-graph-uri=&should-sponge=&query=prefix+skos%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F2004%2F02%2Fskos%2Fcore%23%3E+%0D%0Aprefix+gts%3A+%3Chttp%3A%2F%2Fresource.geosciml.org%2Fschema%2Fcgi%2Fgts%2F3.0%2F%3E+%0D%0Aselect+%3Fcpt%0D%0Awhere%0D%0A{%0D%0Agraph%3Chttp%3A%2F%2Fsparql.tw.rpi.edu%2F20120831%2Fisc2010test%3E%0D%0A{%0D%0A{%0D%0A%3Fcpt+a+gts%3AGeochronologicEra.%0D%0A%3Fcpt+skos%3AprefLabel+'
					 + "\"" + inputLabel + "\"" + "%40" + langId + '.%0D%0A}%0D%0Aunion%0D%0A{%0D%0A%3Fcpt+a+gts%3AGeochronologicEra.%0D%0A%3Fcpt+skos%3AprefLabel+%3Fname.%0D%0Afilter+regex%28'
	                 + "\"" + inputLabel + "\"" + '%2C+%22+%22%29%0D%0Afilter+regex%28%3Fname%2C+'
	                 + "\"" + inputLabel + "\"" + '%29%0D%0A}%0D%0A}%0D%0A}&debug=on&timeout=';
	TWqueryUrl += "&output=json";	
	//alert (TWqueryUrl);
    $.ajax({ 
      dataType: "jsonp",
      url: TWqueryUrl,
      success: function(data) {  
        // grab the actual results from the data.                                          
		var linkGeoscimlVoc = "http://def.seegrid.csiro.au/sissvoc/isc2010/resource?uri=" + data.results.bindings[0]["cpt"].value;  //to use the 2010 vocabulary resource on the seegrid.csiro.au site
 		document.getElementById('GeoscimlLink').getElementsByTagName("a")[0].attributes.getNamedItem("href").nodeValue = linkGeoscimlVoc;
		document.getElementById('GeoscimlLink').getElementsByTagName("a")[0].textContent = inputLabel;
      }
    });	

	//sparql query sent to DBpedia; results seralized in JSON format, get the link of the concept
	/* the query is like this (the following program just replaces the term and language code with variables)
	select ?s 
	where
	{
	graph<http://dbpedia.org>
	{
	?s rdfs:label "Triassic"@en.
	?s dbpedia-owl:abstract ?Dbpedia.
	filter (lang(?Dbpedia)="en")
	}
	}
	*/
  
	var LblqueryUrl = "http://dbpedia.org/sparql?default-graph-uri=&query=SELECT+%3Fs%0D%0AWHERE%0D%0A{%0D%0AGRAPH%3Chttp%3A%2F%2Fdbpedia.org%3E%0D%0A{%0D%0A%3Fs+rdfs%3Alabel+"
					+ "\"" + inputLabel + "\"" + "%40" + langId + ".%0D%0A%3Fs+dbpedia-owl%3Aabstract+%3FDBpedia.%0D%0AFILTER+%28lang%28%3FDBpedia%29%3D"
					+ "\"" + langId + "\"" + "%29%0D%0A}%0D%0A}&timeout=0&debug=on";	
	LblqueryUrl += "&output=json";		
 
    $.ajax({ 
      dataType: "jsonp",
      url: LblqueryUrl,
      success: function(data) {  
        // grab the actual concept link from the json.                                          
		var linkDBpedia = data.results.bindings[0]["s"].value;
		document.getElementById('DBpediaLink').getElementsByTagName("a")[0].attributes.getNamedItem("href").nodeValue = linkDBpedia;
		document.getElementById('DBpediaLink').getElementsByTagName("a")[0].textContent = inputLabel;
		
		//logic here: if the DBpedia entry exists, then we can build a Wikipeida link for the label in the following way
		var linkWikipedia = "http://" + langId + ".wikipedia.org/wiki/" + inputLabel;
		document.getElementById('WikipediaLink').getElementsByTagName("a")[0].attributes.getNamedItem("href").nodeValue = linkWikipedia;
		document.getElementById('WikipediaLink').getElementsByTagName("a")[0].textContent = inputLabel;
      }
    });
	
	//sparql query sent to DBpedia; results seralized in JSON format, get the abstract in corresponding language
	//the query can be merged with the above DBpedia query to reduce length of codes, but here we want to test different functions
	/* the query is like this (the following program just replaces the term and language code with variables)
	select ?Dbpedia 
	where
	{
	graph<http://dbpedia.org>
	{
	?s rdfs:label "Triassic"@en.
	?s dbpedia-owl:abstract ?Dbpedia.
	filter (lang(?Dbpedia)="en")
	}
	}
	*/
	document.getElementById('DBpediaQuery').innerHTML = "";
	var queryUrl = "http://dbpedia.org/sparql?default-graph-uri=&query=SELECT+%3FDBpedia%0D%0AWHERE%0D%0A{%0D%0AGRAPH%3Chttp%3A%2F%2Fdbpedia.org%3E%0D%0A{%0D%0A%3Fs+rdfs%3Alabel+"
					+ "\"" + inputLabel + "\"" + "%40" + langId + ".%0D%0A%3Fs+dbpedia-owl%3Aabstract+%3FDBpedia.%0D%0AFILTER+%28lang%28%3FDBpedia%29%3D"
					+ "\"" + langId + "\"" + "%29%0D%0A}%0D%0A}&timeout=0&debug=on";	
	queryUrl += "&output=json";				
    $.ajax({ 
      dataType: "jsonp",
      url: queryUrl,
      success: function(data) {  
	  
	    // get the table element
        var table = $("#DBpediaQuery");              
        
        // get the sparql variables from the 'head' of the data.
        var headerVars = data.head.vars; 
   
        // using the vars, make some table headers and add them to the table;
        var trHeaders = getTableHeaders(headerVars);
 
        table.append(trHeaders);  
        
        // grab the actual results from the data.                                          
        var bindings = data.results.bindings;
                                                 
        // for each result, make a table row and add it to the table.
        for(rowIdx in bindings){
          table.append(getTableRow(headerVars, bindings[rowIdx]));
        }
      }
    });
}

function getTableHeaders(headerVars) {                                
	var trHeaders = $("<tr></tr>");     
	for(var i in headerVars) {    
		trHeaders.append( $("<th>" + headerVars[i] + "</th>") ); 
	}
	return trHeaders;
}                              
     
 function getTableRow(headerVars, rowData) {
	var tr = $("<tr></tr>");                                 
       
	for(var i in headerVars) {             
		tr.append(getTableCell(headerVars[i], rowData));
	} 
       
	return tr;     
}  

function getTableCell(fieldName, rowData){
	var td = $("<td></td>");
	var fieldData = rowData[fieldName];
	td.html(fieldData["value"]);  
	return td;      
} 

function loadEN(){
	VizFunctionSwitch = 0;
	d3.select("#vis").selectAll("path").remove(); //clean the cells
	d3.select("#vis").selectAll("text").remove(); //clean the labels
	jsonDoc = "iscwheel.json";
	langId = "en";
	d3.json(jsonDoc, initialJson);
}

function loadJP(){
	VizFunctionSwitch = 0;
	d3.select("#vis").selectAll("path").remove();
	d3.select("#vis").selectAll("text").remove();
	jsonDoc = "iscwheeljp.json";
	langId = "ja";
	d3.json(jsonDoc, initialJson);
}

function loadCN(){
	VizFunctionSwitch = 0;
	d3.select("#vis").selectAll("path").remove();
	d3.select("#vis").selectAll("text").remove();
	jsonDoc = "iscwheelcn.json";
	langId = "zh";
	d3.json(jsonDoc, initialJson);
}

function loadES(){
	VizFunctionSwitch = 0;
	d3.select("#vis").selectAll("path").remove();
	d3.select("#vis").selectAll("text").remove();
	jsonDoc = "iscwheeles.json";
	langId = "es";
	d3.json(jsonDoc, initialJson);
}

function loadDE(){
	VizFunctionSwitch = 0;
	d3.select("#vis").selectAll("path").remove();
	d3.select("#vis").selectAll("text").remove();
	jsonDoc = "iscwheelde.json";
	langId = "de";
	d3.json(jsonDoc, initialJson);
}

function loadFR(){
	VizFunctionSwitch = 0;
	d3.select("#vis").selectAll("path").remove();
	d3.select("#vis").selectAll("text").remove();
	jsonDoc = "iscwheelfr.json";
	langId = "fr";
	d3.json(jsonDoc, initialJson);
}

function loadNL(){
	VizFunctionSwitch = 0;
	d3.select("#vis").selectAll("path").remove();
	d3.select("#vis").selectAll("text").remove();
	jsonDoc = "iscwheelnl.json";
	langId = "nl";
	d3.json(jsonDoc, initialJson);
}

function isParentOf(p, c) {
  if (p === c) return true;
  if (p.children) {
    return p.children.some(function(d) {
      return isParentOf(d, c);
    });
  }
  return false;
}

function colour(d) {
/*  if (d.children) {   //this is a function to set the color of a parent node by using colors of its child nodes
    // There is a maximum of two children!
    var colours = d.children.map(colour),
        a = d3.hsl(colours[0]),
        b = d3.hsl(colours[1]);
    // L*a*b* might be better here...
    return d3.hsl((a.h + b.h) / 2, a.s * 1.2, a.l / 1.2);
  } */
  return d.colour || "#fff";
}

// Interpolate the scales!
function arcTween(d) {
  var my = maxY(d),
      xd = d3.interpolate(x.domain(), [d.x, d.x + d.dx]),
      yd = d3.interpolate(y.domain(), [d.y, my]),
      yr = d3.interpolate(y.range(), [d.y ? 20 : 0, r]);
  return function(d) {
    return function(t) { x.domain(xd(t)); y.domain(yd(t)).range(yr(t)); return arc(d); };
  };
}

function maxY(d) {
  return d.children ? Math.max.apply(Math, d.children.map(maxY)) : d.y + d.dy;
}

// http://www.w3.org/WAI/ER/WD-AERT/#color-contrast
function brightness(rgb) {
  return rgb.r * .299 + rgb.g * .587 + rgb.b * .114;
}

function mouseoverpath(d, i) {
	if(d.name){ 
		//change the style of the path (the cell)
		this.parentNode.appendChild(this); //bring the node of the path to the front on screen
 
		if (d3.select(this).style("stroke") == "rgb(255, 255, 255)") {
		d3.select(this)
			.style("stroke", "#0000ff")
			.style("stroke-opacity", 0.3)
			.style("stroke-width",4);
		}
		//.style("display","none");   //hidden/visible
		
		//change the style of the text
		var selNode = vis.select("#text-"+i).node(); //get the node of the text
		selNode.parentNode.appendChild(selNode); //bring the text to the front on screen
		vis.select("#text-"+i)  //get the text by using text id
		.style("fill", "#000000")
		.style("font-size", "12px")
		.style("font-weight","bold");
	}
}

function mouseoutpath(d, i) { 
	if(d.name){
		//change the style of the path (the cell)
		if (d3.select(this).style("stroke") == "rgb(0, 0, 255)") {
		d3.select(this)
			.style("stroke", "#ffffff")
			.style("stroke-opacity", 1)
			.style("stroke-width",1); 
		}
		//change the style of the text 				
		vis.select("#text-"+i)   //get the text by using text id
		.style("font-size", "4px")
		.style("font-weight", null)
		//.style("stroke", null)
		.style("fill", function(d) {
			return brightness(d3.rgb(colour(d))) < 125 ? "#fff" : "#000"; //change the color of text to contrast with background color
		});
	}
}
	  
function mouseovertext(d, i) {
	if(d.name){ 
		//change the style of the path (the cell)
		var selNode = vis.select("#path-"+i).node();  //get the node of the path that the text is in
		selNode.parentNode.appendChild(selNode);  //bring this node to the front on screen
		
		if (vis.select("#path-"+i).style("stroke") == "rgb(255, 255, 255)") {
		vis.select("#path-"+i)  //get the path by using path id
			.style("stroke", "#0000ff")
			.style("stroke-opacity", 0.3)
			.style("stroke-width",4);
		}
		//change the style of the text	
		this.parentNode.appendChild(this);  //bring the text to the front on screen
		d3.select(this)
		.style("fill", "#000000")
		.style("font-size", "12px")
		.style("font-weight","bold");
		//.style("stroke", "#000000")
		//.style("stroke-opacity", 0.8)
		//.style("stroke-width",1)
		//.style("display","hidden");   //hidden/visible
	}
}
		
function mouseouttext(d, i) { 
	if(d.name){
		//change the style of the path (the cell)
		if (vis.select("#path-"+i).style("stroke") == "rgb(0, 0, 255)") {
		vis.select("#path-"+i)  //get the node by using node id
			.style("stroke", "#ffffff")
			.style("stroke-opacity", 1)
			.style("stroke-width",1);	  
		}
		//change the style of the text	
		d3.select(this).style("font-size", "4px")
		.style("font-weight", null)
		//.style("stroke", null)
		.style("fill", function(d) {
			return brightness(d3.rgb(colour(d))) < 125 ? "#fff" : "#000"; //change the color of text to contrast with background color
		}); 
		}
}

function hightlightLabel(inputLabel) {
	//This sparql query will get the concept uri
	//sparql query sent to graph isc2010test (original vocabulary developed by Simon Cox-creator of GeoSciML geologic time ontology) on TW site; results seralized in JSON format
	/* the query is like this, the program replace the label and language code with variables
	//using the union to tolerate labels like "Upper Triassic", because in the triple store
	//the corresponding label is "Late/Upper Triassic". By setting the conditions in the union
	//we can find the concept even a input label is not in English
	//Note the two str functions are important, if not use the latter str, the query will not work for labels in chinese 'zh' or japanese 'ja'
//here the query can be further improved to union queries to altLabel
prefix skos: <http://www.w3.org/2004/02/skos/core#> 
prefix gts: <http://resource.geosciml.org/schema/cgi/gts/3.0/> 
select ?cpt
where
{
graph<http://sparql.tw.rpi.edu/20120831/isc2010test>
{
{
?cpt a gts:GeochronologicEra.
?cpt skos:prefLabel ?name.
filter sameTerm(str(?name), str("Triassic"))
}
union
{
?cpt a gts:GeochronologicEra.
?cpt skos:prefLabel ?name.
filter regex("Triassic", " ")
filter regex(?name, "Triassic")
}
}
}
	*/	
	var cptUri;
	var TWqueryUrl = 'http://sparql.tw.rpi.edu/virtuoso/sparql?default-graph-uri=&should-sponge=&query=prefix+skos%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F2004%2F02%2Fskos%2Fcore%23%3E+%0D%0Aprefix+gts%3A+%3Chttp%3A%2F%2Fresource.geosciml.org%2Fschema%2Fcgi%2Fgts%2F3.0%2F%3E+%0D%0Aselect+%3Fcpt%0D%0Awhere%0D%0A{%0D%0Agraph%3Chttp%3A%2F%2Fsparql.tw.rpi.edu%2F20120831%2Fisc2010test%3E%0D%0A{%0D%0A{%0D%0A%3Fcpt+a+gts%3AGeochronologicEra.%0D%0A%3Fcpt+skos%3AprefLabel+%3Fname.%0D%0Afilter+sameTerm%28str%28%3Fname%29%2C+str%28'
	                 + "\"" + inputLabel + "\"" + '%29%29%0D%0A}%0D%0Aunion%0D%0A{%0D%0A%3Fcpt+a+gts%3AGeochronologicEra.%0D%0A%3Fcpt+skos%3AprefLabel+%3Fname.%0D%0Afilter+regex%28'
	                 + "\"" + inputLabel + "\"" + '%2C+%22+%22%29%0D%0Afilter+regex%28%3Fname%2C+'
	                 + "\"" + inputLabel + "\"" + '%29%0D%0A}%0D%0A}%0D%0A}&debug=on&timeout=';
	TWqueryUrl += "&output=json";	
//alert (TWqueryUrl);
    $.ajax({ 
      dataType: "jsonp",
      url: TWqueryUrl,
      success: function(data) {  
        // grab the actual results from the data.                                          
		cptUri = data.results.bindings[0]["cpt"].value;
//call another sparql query		
	//this query get the label in the language specified by langId
	//sparql query sent to graph isc2010test (original vocabulary developed by Simon Cox-creator of GeoSciML geologic time ontology) on TW site; results seralized in JSON format
	/* find the label of concept, with a specified a language
prefix skos: <http://www.w3.org/2004/02/skos/core#> 
select ?name
where
{
graph<http://sparql.tw.rpi.edu/20120831/isc2010test>
{
?cpt skos:prefLabel ?name.
filter (lang(?name)="en")
}
}	
	*/	
	var nameValue;
	TWqueryUrl = 'http://sparql.tw.rpi.edu/virtuoso/sparql?default-graph-uri=&should-sponge=&query=prefix+skos%3A+%3Chttp%3A%2F%2Fwww.w3.org%2F2004%2F02%2Fskos%2Fcore%23%3E+%0D%0Aselect+%3Fname%0D%0Awhere%0D%0A{%0D%0Agraph%3Chttp%3A%2F%2Fsparql.tw.rpi.edu%2F20120831%2Fisc2010test%3E%0D%0A{'
				  + "<" + cptUri + ">" + '+skos%3AprefLabel+%3Fname.%0D%0Afilter+%28lang%28%3Fname%29%3D'
				  + "\"" + langId + "\"" + '%29%0D%0A}%0D%0A}&debug=on&timeout=';
	TWqueryUrl += "&output=json";	
    $.ajax({ 
      dataType: "jsonp",
      url: TWqueryUrl,
      success: function(data) {  
        // grab the actual results from the data.                                          
		nameValue = data.results.bindings[0]["name"].value;
		//do the highlight job
        hightlightLabelDone(nameValue);		
      }
    });			
				
////		
      }
    });	
}

function hightlightLabelDone(gtsLabel){
	//gtsLabel is a gts term retrieved by a click in the WMS map window
	VizFunctionSwitch = 0;
	
	var n;
	vis.selectAll("path")
			.style("visibility", "visible")
			.style("stroke", "#ffffff") //set the style of stroke to clean preceding changes to strokes
			.style("stroke-opacity", 1)
			.style("stroke-width",1);
	
	vis.selectAll("text")
			.style("visibility", "visible");

	//gtsLabel =getLableinLanguage(gtsLabel);  //get the label in the specified language
 			
		vis.selectAll("path").each(function(d, i){
				if(d.name && d.name == gtsLabel)
				{
					this.parentNode.appendChild(this);
					d3.select(this)  
						.style("stroke", "#0000fe")  //use "#0000fe", so when mouse over or out, the stroke style will not change
						.style("stroke-opacity", 1)
						.style("stroke-width",4);
				}
				//special setting for inputs of 'Lower Cambrian', 'Middle Cambrian' and 'Upper Cambrian' in BGS 625k bed rock age map
				else if (((d.name == 'Series 2' || d.name  == 'Terreneuvian')&& gtsLabel == 'Lower Cambrian')
						||(d.name  == 'Series 3' && gtsLabel == 'Middle Cambrian')
						||(d.name  == 'Furongian' && gtsLabel == 'Upper Cambrian')
						)
						{
							this.parentNode.appendChild(this);
							d3.select(this)  
								.style("stroke", "#0000fe")
								.style("stroke-opacity", 1)
								.style("stroke-width",4);
						}
			});
			
/*	var strLabel = '';
	var selNode;
	vis.selectAll("path").each(function(d) //for cells (those without labels) at the sub-series level - they are a part of the parent cells at the series level
	{	
		strLabel = d.name;
		if((strLabel == 'Cambrian' || strLabel == 'Ordovician' || strLabel == 'Silurian' || strLabel == 'Devonian' ||
			strLabel == 'Permian' || strLabel == 'Triassic' || strLabel == 'Jurassic' || strLabel == 'Cretaceous' || 
			strLabel == 'Paleogene' || strLabel == 'Neogene' || strLabel == 'Quaternary')
			&& d3.select(this).style("stroke") == "rgb(0, 0, 254)") // NOTE: here the condition is different from that in the SLD info function, rgb 0,0,254 means 0000fe, judge by stroke color, not by the visibility of the cell
		{
			for (n=0; n<vis.selectAll("path").data().length; n++) //here may be re-checked because the GTS color codes are not unique for each GTS concept
			{
				if(vis.select("#path-"+n).style("fill") == d3.select(this).style("fill"))
				{alert(d3.select(this).style("fill"));
					selNode = vis.select("#path-"+n).node();  //get the node of the path that the text is in
					selNode.parentNode.appendChild(selNode);  //bring this node to the front on screen
					vis.select("#path-"+n)
						.style("stroke", "#0000fe")
						.style("stroke-opacity", 1)
						.style("stroke-width",4);						
				}
			}
		}
	});*/
			
		vis.selectAll("text").each(function(d, i){
				if(d.name && d.name  == gtsLabel)
				{
					this.parentNode.appendChild(this);
				}
				//special setting for inputs of 'Lower Cambrian', 'Middle Cambrian' and 'Upper Cambrian' in BGS 625k bed rock age map
				else if (((d.name == 'Series 2' || d.name  == 'Terreneuvian')&& gtsLabel == 'Lower Cambrian')
						||(d.name  == 'Series 3' && gtsLabel == 'Middle Cambrian')
						||(d.name  == 'Furongian' && gtsLabel == 'Upper Cambrian')
						)
						{
							this.parentNode.appendChild(this);
						}
			});	

	document.getElementById('DBpediaLink').innerHTML = '<br /><a href="http://www.dbpedia.org" target="_blank">DBpedia</a>';
	document.getElementById('GeoscimlLink').innerHTML = '<br /><a href="http://resource.geosciml.org/classifierscheme/ics/ischart/2010" target="_blank">GeoSciML Vocabulary</a>';
    document.getElementById('WikipediaLink').innerHTML = '<br /><a href="http://www.wikipedia.org" target="_blank">Wikipedia</a>';
	document.getElementById('DBpediaQuery').innerHTML = "";
	sparqlQuery(gtsLabel);  //need methods to find the language of gtsLabel and then change the langId , or ask users to choose language of the pie firstly		
}	

function showlegend(styleinfo){
	//styleinfo is a string like "Quaternary#Cambrian#Jurassic#Lower Jurassic#Sinemurian#Permian";
	VizFunctionSwitch = 1;
	
	var gtsNameArray = new Array();
	gtsNameArray = styleinfo.split("#");
	var m = 0,
	    n = 0;
		
	vis.selectAll("path")
			.style("visibility", "hidden")
			.style("stroke", "#ffffff") //set the style of stroke to clean preceding changes to strokes
			.style("stroke-opacity", 1)
			.style("stroke-width",1);
	
	vis.selectAll("text")
			.style("visibility", "hidden");
	
	for (n=0; n<gtsNameArray.length; n++) //use a nested loop to make all nodes that appear in the map legend to be visible in the pie
	{
		vis.selectAll("path").each(function(d, i){
				if(d.name && d.name == gtsNameArray[n])
				{
					d3.select(this)  
						.style("visibility", "visible");
				}
				//special setting for inputs of 'Lower Cambrian', 'Middle Cambrian' and 'Upper Cambrian' in BGS 625k bed rock age map
				else if (((d.name == 'Series 2' || d.name  == 'Terreneuvian')
						&& gtsNameArray[n] == 'Lower Cambrian')
						||(d.name  == 'Series 3' && gtsNameArray[n] == 'Middle Cambrian')
						||(d.name  == 'Furongian' && gtsNameArray[n] == 'Upper Cambrian')
						)
						{
							this.parentNode.appendChild(this);
							d3.select(this)  
								.style("visibility", "visible")
								.style("stroke", "#00ff00")
								.style("stroke-opacity", 1)
								.style("stroke-width",4);
						}
			});
			
		vis.selectAll("text").each(function(d, i){
				if(d.name && d.name  == gtsNameArray[n])
				{
					d3.select(this)
						.style("visibility", "visible");
				}
				//special setting for inputs of 'Lower Cambrian', 'Middle Cambrian' and 'Upper Cambrian' in BGS 625k bed rock age map
				else if (((d.name == 'Series 2' || d.name  == 'Terreneuvian')
						&& gtsNameArray[n] == 'Lower Cambrian')
						||(d.name  == 'Series 3' && gtsNameArray[n] == 'Middle Cambrian')
						||(d.name  == 'Furongian' && gtsNameArray[n] == 'Upper Cambrian')
						)
						{
							this.parentNode.appendChild(this);
							d3.select(this)
								.style("visibility", "visible");
						}
			});	
	}

	
	var strLabel = '';
	vis.selectAll("path").each(function(d) //for cells (those without labels) at the sub-series level - they are a part of the parent cells at the series level
	{	
		strLabel = d.name;
		if((strLabel == 'Cambrian' || strLabel == 'Ordovician' || strLabel == 'Silurian' || strLabel == 'Devonian' ||
			strLabel == 'Permian' || strLabel == 'Triassic' || strLabel == 'Jurassic' || strLabel == 'Cretaceous' || 
			strLabel == 'Paleogene' || strLabel == 'Neogene' || strLabel == 'Quaternary')
			&& d3.select(this).style("visibility") == "visible")
		{
			for (n=0; n<vis.selectAll("path").data().length; n++) //here may be re-checked because the GTS color codes are not unique for each GTS concept
			{
				if(vis.select("#path-"+n).style("fill") == d3.select(this).style("fill"))
				{
					vis.select("#path-"+n)
						.style("visibility", "visible");
				}
			}
		}
	});

    var parentItem;  var tempNode;
	vis.selectAll("path").each(function(d){  //show the cells - if a GTS child concept is shown in pie, then show its ancestor concepts in pie
		if(d.name && d.parent && d3.select(this).style("visibility") == "visible")
			{	
				parentItem = d.parent;
				while (parentItem && parentItem.name != null && parentItem.name != "" && parentItem.colour != "#FFFFFF")   //cannot do this: vis.select("#path-" + parentItem.name)
					{ 
						vis.selectAll("path").each(function(d){
						if(d.name != null && d.name != "" && d.colour != "#FFFFFF" && d.name == parentItem.name && d3.select(this).style("visibility") == "hidden") 
						{ 	 
							this.parentNode.appendChild(this);
						   d3.select(this)
							.style("visibility", "visible")
							.style("stroke", "#ff0000")
							.style("stroke-opacity", 1)
							.style("stroke-width",4);
						 }});
					 parentItem = parentItem.parent;
					}
				
			}	
	});
	
	vis.selectAll("text").each(function(d){  //show the texts - if a GTS child concept is shown in pie, then show its ancestor concepts in pie
		if(d.name && d.parent && d3.select(this).style("visibility") == "visible")
			{	
				parentItem = d.parent;
				while (parentItem && parentItem.name != null && parentItem.name != "" && parentItem.colour != "#FFFFFF")   //cannot do this: vis.select("#path-" + parentItem.name)
					{ 
						vis.selectAll("text").each(function(d){
						if(d.name != null && d.name != "" && d.colour != "#FFFFFF" && d.name == parentItem.name && d3.select(this).style("visibility") == "hidden") 
						{ 	 
							this.parentNode.appendChild(this);
						   d3.select(this)
							.style("visibility", "visible");
						 }});
					 parentItem = parentItem.parent;
					}
				
			}	
	});
	
/*	//here may add scripts for terms at serires level with red stroke -- make non-label cells at sub-series level with red stroke
	vis.selectAll("path").each(function(d) //for cells (those without labels) at the sub-series level - they are a part of the parent cells at the series level
	{	
		strLabel = d.name;
		if((strLabel == 'Cambrian' || strLabel == 'Ordovician' || strLabel == 'Silurian' || strLabel == 'Devonian' ||
			strLabel == 'Permian' || strLabel == 'Triassic' || strLabel == 'Jurassic' || strLabel == 'Cretaceous' || 
			strLabel == 'Paleogene' || strLabel == 'Neogene' || strLabel == 'Quaternary')
			&& d3.select(this).style("visibility") == "visible" && d3.select(this).style("stroke") == "rgb(255, 0, 0)")
		{
			for (n=0; n<vis.selectAll("path").data().length; n++) //here may be re-checked because the GTS color codes are not unique for each GTS concept
			{
				if(vis.select("#path-"+n).style("fill") == d3.select(this).style("fill"))
				{
					//hide the first two sentences because they will hide the label text of the parent cell
					//tempNode = vis.select("#path-"+n).node();  //get the node of the path that the text is in
					//tempNode.parentNode.appendChild(selNode);  //bring this node to the front on screen
					vis.select("#path-"+n)
						.style("visibility", "visible")
						.style("stroke", "#ff0000")
						.style("stroke-opacity", 1)
						.style("stroke-width",4);						
				}
			}
		}
	});	*/
}	