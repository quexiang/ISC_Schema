package {
	import flare.animate.FunctionSequence;
	import flare.animate.Transition;
	import flare.animate.TransitionEvent;
	import flare.animate.Transitioner;
	import flare.data.DataSet;
	import flare.data.DataSource;
	import flare.display.TextSprite;
	import flare.query.methods.eq;
	import flare.scale.ScaleType;
	import flare.util.Orientation;
	import flare.util.Shapes;
	import flare.util.palette.ColorPalette;
	import flare.vis.Visualization;
	import flare.vis.controls.ClickControl;
	import flare.vis.controls.ExpandControl;
	import flare.vis.controls.HoverControl;
	import flare.vis.controls.IControl;
	import flare.vis.controls.PanZoomControl;
	import flare.vis.controls.TooltipControl;
	import flare.vis.data.Data;
	import flare.vis.data.DataList;
	import flare.vis.data.DataSprite;
	import flare.vis.data.NodeSprite;
	import flare.vis.data.Tree;
	import flare.vis.events.SelectionEvent;
	import flare.vis.events.TooltipEvent;
	import flare.vis.operator.encoder.ColorEncoder;
	import flare.vis.operator.encoder.PropertyEncoder;
	import flare.vis.operator.encoder.ShapeEncoder;
	import flare.vis.operator.label.Labeler;
	import flare.vis.operator.label.RadialLabeler;
	import flare.vis.operator.layout.AxisLayout;
	import flare.vis.operator.layout.NodeLinkTreeLayout;
	import flare.vis.operator.layout.RadialTreeLayout;
	
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.*;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.external.ExternalInterface;
	import flash.geom.Rectangle;
	import flash.net.URLLoader;
	import flash.text.Font;
	import flash.text.TextField;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.utils.Timer;
	
	[SWF(width="2110", height="2110", backgroundColor="#ffffff", frameRate="5")]
	
	public class gtsOwl extends Sprite 
	{
//		private var output:TextField;
		/** We will be rotating text, so we embed the font. */
		//embedAsCFF="false" is necessary, otherwise 'gtsLabel.textMode = TextSprite.EMBED;' will not work
		[Embed(source="verdana.TTF", fontName="Verdana", embedAsCFF="false")]
		//[Embed(source="simkai.TTF", fontName="KaiTi", embedAsCFF="false")]
		public static var VerdanaFont:Class;
		
		
		private var vis:Visualization;
		private var ctrl:IControl;
		private var bounds:Rectangle = new Rectangle(0, 0,stage.stageWidth, stage.stageHeight);
		
		private var ctrlMapTrigger: int = 0;	  // A trigger to limit that only when the gts pie is showing legend from map
		                        				  // can it contains the 'click' response to control the wms map 
		
		private var labelToJavaScript:String = new String();
		
		// default values
		private var nodes:Object = {
			shape: Shapes.WEDGE, //layout like sunburst appearance
				//fillColor: 0x88aaaaaa,
				lineColor: 0xffffffff,
				lineWidth: 1,
				//size: 1.5,
				//alpha: 1,
				visible: true
		}
		
		private var edges:Object = {
			lineColor: 0xffff0000,
			lineWidth: 1,
			alpha: 1,
			visible: false
		}
			
		private var data:Data = gtsTree();
		
		public function gtsOwl() 
		{
/*			output = new TextField();
			output.x =25;		
			output.y = 25;
			output.width = 450;
			output.height = 325;
			output.multiline = true;
			output.wordWrap = true;
			output.border = true;
			addChild(output);
*/		

			// CREATE data and set defaults
			//var data:Data = gtsTree();
			// SET the layouts of the treeview: wedge for a 'sunburst' view
			data.nodes.setProperties(nodes);
			data.edges.setProperties(edges);
			
			// CREATE labels and links to each node in the tree except the root
			for (var j:int=0; j<data.nodes.length; ++j) 
			{
				//data.nodes[j].data.label = String(j);
				if(data.nodes[j].name != "rootOfAll" && data.nodes[j].name != "") //do not assign label to those special nodes (e.g., rootOfAll, father of phanerozoic, sons of Hadean)
				{
					data.nodes[j].data.label = data.nodes[j].name; //(label value is the name of each node)
					data.nodes[j].buttonMode = true;
				}
			}
			
			// SORT to ensure that children nodes are drawn over parents
			data.nodes.sortBy("depth");
			
			// CREATE the visualization: size and position of the view window
			vis = new Visualization(data);
			vis.bounds = bounds;
			
			// SET layout of the 'suburst' tree
			var sunTree:RadialTreeLayout = new RadialTreeLayout(140,false, false);
			sunTree.parameters = {angleWidth: 1.96*Math.PI, startAngle: 0.46*Math.PI, useNodeSize: true}; // startAngle sets the initial situation of the pie
			sunTree.layoutBounds = vis.bounds;
			vis.operators.add(sunTree);
			
			// SET layout of the 'suburst' tree
			vis.setOperator("nodes", new PropertyEncoder(nodes, "nodes")); //use data.nodes here will cause problem: nodes cannot expand or collapse
			vis.setOperator("edges", new PropertyEncoder(edges, "edges"));
			
			// ADD control of mouse over and mouse out in the view window
			vis.controls.add(new HoverControl(NodeSprite,
				// BY default, move highlighted items to front
				HoverControl.MOVE_AND_RETURN,
				// HIGHLIGHT node border on mouse over
				function(e:SelectionEvent):void { 							//if a node's line color is 0xff0000ff, means it is the result of a query, so do not change it.
					if(e.node.data.label && e.node.lineColor != 0xff0000ff  //if a node's line color is 0xffff0000, means it is the result of a inference, so do not change it.
						&& e.node.lineColor != 0xff00ff00					//if a node's line color is 0xff00ff00, means it is the result of a synonym term
						&& e.node.lineColor != 0xffff0000)                  // some nodes have no labels, as set in above scripts when assign labels by checking nodes' names
					{ 					                                    // we do not want user see these nodes, so by setting here, these nodes have no interactions with users
						e.node.lineWidth = 3;
						e.node.lineColor = 0x880000ff;
					}
				},
				// REMOVE highlight on mouse out
				function(e:SelectionEvent):void {
					if(e.node.data.label && e.node.lineColor != 0xff0000ff 
						&& e.node.lineColor != 0xff00ff00
						&& e.node.lineColor != 0xffff0000)
					{
						e.node.lineWidth = 1;
						e.node.lineColor = nodes.lineColor;
					}
				}));
			
			//Add contrl of showing tooltip when the mouse stay over a node for some time
			//!!!can be further developped to show more inforamtion of a gts term by parsing the OWL file
			vis.controls.add(new TooltipControl(NodeSprite, null,
				function(e:TooltipEvent):void {
					TextSprite(e.tooltip).htmlText = null;
					if(e.node.data.label)
					{
						TextSprite(e.tooltip).htmlText = e.node.data.label;
					}
				},
				function(e:TooltipEvent):void {
					TextSprite(e.tooltip).htmlText = null;
					if(e.node.data.label)
					{
						TextSprite(e.tooltip).htmlText = e.node.data.label;
					}
				}
			));

			vis.controls.add(new ClickControl(NodeSprite,1,   //Click control to send a string to the javascript for filter the map in wms
				function(e:SelectionEvent):void { 							
					if(ctrlMapTrigger == 1 && e.node.data.label)                  
					{ 					                                    
						labelToJavaScript = e.node.data.label;
						
						//bgn of semantic analysis, find all children gts nodes that fall into the time span of a gts father node
						var tNode:NodeSprite = new NodeSprite();
						for (var j:int=1; j<data.nodes.length; j++) 
						{
							if(data.nodes[j].data.label == labelToJavaScript)
							{
								tNode = data.nodes[j];
								break;
							}
						}
						
						findChildrenLabels(tNode); //check all the nodes in a tree with tNode as the root, and add results to labelToJavaScript 
						//end of semantic analysis/////////
						
						//ONLY for the BGS 625k bed rock age map  // when use this progam for other maps, the following script should be deleted or adapted
						//here the bgs map layer has no terms of stages in Cambrian, if there are some, we should change only the first term (the one before the first '#')
						//in the long string labelToJavaScript
						if (e.node.data.label == 'Furongian')
							labelToJavaScript = 'Upper Cambrian';
						else if (e.node.data.label == 'Series 3')
							labelToJavaScript = 'Middle Cambrian';
						else if (e.node.data.label == 'Series 2' || e.node.data.label == 'Terreneuvian')
							labelToJavaScript = 'Lower Cambrian';
						//end///only for the bgs 625k bed rock age map
							
						ExternalInterface.call("sendToJavaScript", labelToJavaScript);
					}
					else if (ctrlMapTrigger != 1 && e.node.data.label)
					{
						labelToJavaScript =  e.node.data.label+"@";  // add '@' in order to can identify this kind of query in Javascript
						ExternalInterface.call("sendToJavaScript", labelToJavaScript);
					}
				}
			));
			
			/*			
			// ADD control of expanding or collpasing a node by clicking a node on user interface
			ctrl = new ExpandControl(NodeSprite,
				function():void { vis.update(1, "nodes","main").play(); });
			vis.controls.add(ctrl);			
			*/	
			
			ctrl = new PanZoomControl();
			vis.controls.add(ctrl);
			
			// SET labels for each node in the view window 
			var gtsLabel:RadialLabeler = new RadialLabeler(
				function(d: DataSprite): String {return d.data.label;}, 
				true, new TextFormat("Verdana", "12"),   //Verdana   KaiTi
				null, Labeler.CHILD);//
			
			gtsLabel.textMode = TextSprite.EMBED;//using the embedded text font, make labels shown in vector format
			gtsLabel.rotateLabels = true;
			gtsLabel.radiusOffset = -64; //move labels along the radius
			// ADD the labels of the tree
			vis.operators.add(gtsLabel);
			
			vis.update();
			addChild(vis);
			
			/**take care here*/
			ExternalInterface.addCallback("sendToActionScript", receivedFromJavaScript); 
			
		}
		
		private function findChildrenLabels(node: NodeSprite) : void  // a recursion to visit all descendent nodes of a root node 
		{
			var tNode:NodeSprite = new NodeSprite();
			
			tNode = node.firstChildNode;
			
			while (tNode != null)
			{
				if (tNode.visible == true && tNode.data.label && tNode.lineColor != 0xffff0000)
				{
					//ONLY for the BGS 625k bed rock age map  // when use this progam for other maps, the following script should be deleted or adapted
					//in the long string labelToJavaScript
					if (tNode.data.label == 'Furongian')
						labelToJavaScript += '#' + 'Upper Cambrian';
					else if (tNode.data.label == 'Series 3')
						labelToJavaScript += '#' + 'Middle Cambrian';
					else if (tNode.data.label == 'Series 2' || tNode.data.label == 'Terreneuvian')
						labelToJavaScript += '#' + 'Lower Cambrian';
					//end///only for the bgs 625k bed rock age map
					
					else
						labelToJavaScript += '#' + tNode.data.label;
				}
				
				findChildrenLabels(tNode);	//finding the place here of the recursion killed a lot of brain cells, hahahha
				                            //and also note that the found node labels are arranged according to the recursion sequence
				tNode = tNode.nextNode;			
			}
		}
		
		// Expand the whole tree
		private function rebuildTree():void 
		{
			ctrlMapTrigger = 0;
			for (var j:int=1; j<vis.data.nodes.length; ++j) 
			{
				vis.data.nodes[j].expanded = true;
				
				vis.data.nodes[j].lineColor = 0xffffffff;
				vis.data.nodes[j].lineWidth = 1;
			}
			
			//vis.data.nodes[0].visible = false; // the root
			//vis.data.nodes[2].visible = false; // the node above phanerozoic
			//vis.data.nodes[3].firtChildNode.visible = false; //child node of hadean
			//vis.data.nodes[3].firtChildNode.nextNode.visible = false; //child node of hadean
		}
		
 
		// get information from javascript
		private function receivedFromJavaScript(value:String):void 
		{
			var tNode:NodeSprite = new NodeSprite();
			var tNode2:NodeSprite = new NodeSprite();
			var tNode3:NodeSprite = new NodeSprite();
			var tNode4:NodeSprite = new NodeSprite();
			var tNode5:NodeSprite = new NodeSprite();
			var tNode6:NodeSprite = new NodeSprite();

			rebuildTree(); // expand all nodes
			
			if (value == 'Eonothem') //Eonothem at second layer because of 'Precambrian'
			{
				tNode = vis.data.nodes[0].firstChildNode;
				while (tNode != null)
				{
					tNode2 = tNode.firstChildNode;
					while (tNode2 != null)
					{
						tNode2.expanded = false;//collapse the child of 'Eonothem'
						tNode2 = tNode2.nextNode;
					}
					tNode = tNode.nextNode;
				}
				vis.update(1, "nodes","main").play();//perform the collapse
			}
			
			else if (value == 'Erathem')
			{
				tNode = vis.data.nodes[0].firstChildNode;
				while (tNode != null)
				{
					tNode2 = tNode.firstChildNode;
					while (tNode2 != null)
					{
						tNode3 = tNode2.firstChildNode;
						while (tNode3 != null)
						{
							tNode3.expanded = false;//collapse the child of 'Erathem'
							tNode3 = tNode3.nextNode;
						}
						tNode2 = tNode2.nextNode;
					}
					tNode = tNode.nextNode;
				}
				vis.update(1, "nodes","main").play();//perform the collapse	
			}
			
			else if (value == 'System')
			{
				tNode = vis.data.nodes[0].firstChildNode;
				while (tNode != null)
				{
					tNode2 = tNode.firstChildNode;
					while (tNode2 != null)
					{
						tNode3 = tNode2.firstChildNode;
						while (tNode3 != null)
						{
							tNode4  = tNode3.firstChildNode;
							while (tNode4 != null)
							{
								tNode4.expanded = false;//collapse the child of 'System'
								tNode4 = tNode4.nextNode;
							}
							tNode3 = tNode3.nextNode;
						}
						tNode2 = tNode2.nextNode;
					}
					tNode = tNode.nextNode;
				}
				vis.update(1, "nodes","main").play();//perform the collapse					
			}
			else if (value == 'Subsystem')
			{
				tNode = vis.data.nodes[0].firstChildNode;
				while (tNode != null)
				{
					tNode2 = tNode.firstChildNode;
					while (tNode2 != null)
					{
						tNode3 = tNode2.firstChildNode;
						while (tNode3 != null)
						{
							tNode4  = tNode3.firstChildNode;
							while (tNode4 != null)
							{
								tNode5 = tNode4.firstChildNode;
								while (tNode5 != null)
								{
									tNode5.expanded = false;//collapse the child of 'Subsystem'
									tNode5 = tNode5.nextNode;
								}
								tNode4 = tNode4.nextNode;
							}
							tNode3 = tNode3.nextNode;
						}
						tNode2 = tNode2.nextNode;
					}
					tNode = tNode.nextNode;
				}
				vis.update(1, "nodes","main").play();//perform the collapse		
			}
			else if (value == 'Series')
			{
				tNode = vis.data.nodes[0].firstChildNode;
				while (tNode != null)
				{
					tNode2 = tNode.firstChildNode;
					while (tNode2 != null)
					{
						tNode3 = tNode2.firstChildNode;
						while (tNode3 != null)
						{
							tNode4  = tNode3.firstChildNode;
							while (tNode4 != null)
							{
								tNode5 = tNode4.firstChildNode;
								while (tNode5 != null)
								{
									tNode6 = tNode5.firstChildNode;
									while (tNode6 != null)
									{
										tNode6.expanded = false;//collapse the child of 'Series'
										tNode6 = tNode6.nextNode;
									}
									tNode5 = tNode5.nextNode;
								}
								tNode4 = tNode4.nextNode;
							}
							tNode3 = tNode3.nextNode;
						}
						tNode2 = tNode2.nextNode;
					}
					tNode = tNode.nextNode;
				}
				vis.update(1, "nodes","main").play();//perform the collapse		
			}
			else if (value == 'Stage')
			{
				vis.update(1, "nodes","main").play();//perform the collapse
			}
			
			else if (value.length > 150) // a part of the SLD file in XML format, recording which terms are covered in the map legend
			{                            // note the length 150 here is only a temporary choice, because a single gts term's length will not exceed 150
				ctrlMapTrigger = 1;
				var gtsNameArray : Array = new Array();
				gtsNameArray = value.split("#");
				
				//vis.update(1, "nodes","main").play();//perform the animation				
				
				for (var n:int=0; n<vis.data.nodes.length; ++n) 
				{
					vis.data.nodes[n].visible = false;   //make all nodes invisible
				}
				
				for (var m:int=0; m<gtsNameArray.length; m++) //use a nested loop to make all nodes that appear in the map legend to be visible in the pie
				{
					for (n=0; n<vis.data.nodes.length; n++) 
					{
						if(vis.data.nodes[n].data.label && vis.data.nodes[n].data.label == gtsNameArray[m])
						{
							vis.data.nodes[n].visible = true;
							//vis.data.nodes[n].lineColor = 0xff0000ff;
						}
						//special setting for inputs of 'Lower Cambrian', 'Middle Cambrian' and 'Upper Cambrian'
						else if (((vis.data.nodes[n].data.label == 'Series 2' || vis.data.nodes[n].data.label == 'Terreneuvian')
								  && gtsNameArray[m] == 'Lower Cambrian')
								  ||(vis.data.nodes[n].data.label == 'Series 3'	&& gtsNameArray[m] == 'Middle Cambrian')
								  ||(vis.data.nodes[n].data.label == 'Furongian' && gtsNameArray[m] == 'Upper Cambrian')
								)
						{
							vis.data.nodes[n].visible = true;
							vis.data.nodes[n].lineColor = 0xff00ff00;
							vis.data.nodes[n].lineWidth = 6;
						}
					}
				}
				
				//Checking the semantics: if a node is shown, but its father and ascedents are invisible, then they should be made visible
				//but in oder to mark them out, we use red line color for them 
				for (n=0; n<vis.data.nodes.length; n++) 
				{
					if(vis.data.nodes[n].data.label && vis.data.nodes[n].visible == true)
						tNode = vis.data.nodes[n].parentNode;
						while (tNode != null)
						{
							if (tNode.data.label && tNode.visible == false) //make sure that tNode is not one of those that we do not want them to show, e.g., the root
							{
								tNode.visible = true;
								tNode.lineColor = 0xffff0000;
								tNode.lineWidth = 4;  
							}
							tNode = tNode.parentNode;
						}						
				}
				
				//check the 'false' nodes at the 'subsystem' level, if a father node at 'system' node is visible, then make its son node at 'subsystem' level visible. 
				//this action has no semantic meaning, just for the user interface
				//or, in other words, we can regard these 'false' 'subsystem' nodes as a part of the 'system' nodes, in order to make the user interface perfect.
				for (n=0; n<vis.data.nodes.length; n++) 
				{	
					var strLabel:String = vis.data.nodes[n].data.label;
					if((strLabel == 'Cambrian' || strLabel == 'Ordovician' || strLabel == 'Silurian' || strLabel == 'Devonian' ||
						strLabel == 'Permian' || strLabel == 'Triassic' || strLabel == 'Jurassic' || strLabel == 'Cretaceous' || 
						strLabel == 'Paleogene' || strLabel == 'Neogene' || strLabel == 'Quaternary')
						&& vis.data.nodes[n].visible == true)
					{
						vis.data.nodes[n].firstChildNode.visible = true;
					}
				}
				
				vis.update().play();
			}
			
			else for (var j:int=0; j<vis.data.nodes.length; ++j) 
			{//.firstChildNode.nextNode.parentNode.prevNode
				if (vis.data.nodes[j].data.label == value)
				{	
					//2-12-2010 this is a simple result of search
					//vis.data.nodes[j].expanded = false;  //collapse this node // can also use it flexibily with childnode, prevnode....
					//2-12-2010//
					
					vis.data.nodes[j].expanded = false; //collapse this node
					// then collapse all its brother nodes, and brother nodes of its ascedents
					tNode = vis.data.nodes[j];
					while (tNode != null)
						{
							tNode2 = tNode.prevNode;
							while (tNode2 != null)
							{
								tNode2.expanded = false;
								tNode2 = tNode2.prevNode;
							}
							
							tNode3 = tNode.nextNode;
							while (tNode3 != null)
							{
								tNode3.expanded = false;
								tNode3 = tNode3.nextNode;
							}
							tNode = tNode.parentNode;
						}
						
					vis.update(1, "nodes","main").play();//perform the collapse
					vis.data.nodes[j].lineColor = 0xff0000ff;
					vis.data.nodes[j].lineWidth = 6;
					
					break;
				}
																										// the term from javascript a surfix '$$', means this term is the standard term of a synonym term
				else if (vis.data.nodes[j].data.label == 'Terreneuvian' &&
					     value.substring(0, value.length-2) == 'Union of Series 2 and Terreneuvian')		// and the synonym term was input as original term, here is a special condition for the 
				{ 																						// 'Lower Cambrian', because in the gtsOWL ontology its prefLabel is 'Union of Series 2 and Terreneuvian'
					vis.data.nodes[j].expanded = false; //collapse this node
					// then collapse all its brother nodes, and brother nodes of its ascedents
					tNode = vis.data.nodes[j];
					while (tNode != null)
					{
						tNode2 = tNode.prevNode;
						while (tNode2 != null)
						{
							tNode2.expanded = false;
							tNode2 = tNode2.prevNode;
						}
						
						tNode3 = tNode.nextNode;
						while (tNode3 != null)
						{
							tNode3.expanded = false;
							tNode3 = tNode3.nextNode;
						}
						tNode = tNode.parentNode;
					}
					
					vis.update(1, "nodes","main").play();//perform the collapse
					vis.data.nodes[j].lineColor = 0xff00ff00; //Mark 'Terreneuvian' with green line color
					vis.data.nodes[j].lineWidth = 6;
					
					vis.data.nodes[j].nextNode.lineColor = 0xff00ff00; //Mark 'Series 2' with green line color
					vis.data.nodes[j].nextNode.lineWidth = 6;
					
					break;

				}																			  
				
				else if (vis.data.nodes[j].data.label == value.substring(0, value.length-2))  //the term from javascript a surfix '$$', means this term is the standard term of a synonym term
				{																			  // and the synonym term was input as original term 
					vis.data.nodes[j].expanded = false; //collapse this node
					// then collapse all its brother nodes, and brother nodes of its ascedents
					tNode = vis.data.nodes[j];
					while (tNode != null)
					{
						tNode2 = tNode.prevNode;
						while (tNode2 != null)
						{
							tNode2.expanded = false;
							tNode2 = tNode2.prevNode;
						}
						
						tNode3 = tNode.nextNode;
						while (tNode3 != null)
						{
							tNode3.expanded = false;
							tNode3 = tNode3.nextNode;
						}
						tNode = tNode.parentNode;
					}
					
					vis.update(1, "nodes","main").play();//perform the collapse
					vis.data.nodes[j].lineColor = 0xff00ff00; //shown in green color
					vis.data.nodes[j].lineWidth = 6;
					
					break;
				}
				
				else if (vis.data.nodes[j].data.label == 'Terreneuvian' &&
					value.substring(0, value.length-1) == 'Union of Series 2 and Terreneuvian') // a special setting for a orginal term 'Lower Cambrian', , because in the gtsOWL ontology its prefLabel is 'Union of Series 2 and Terreneuvian'
				{	
					vis.update(1, "nodes","main").play();//perform the collapse
					vis.data.nodes[j].lineColor = 0xff0000ff;  // mark 'Terreneuvian'
					vis.data.nodes[j].lineWidth = 8;
					
					vis.data.nodes[j].nextNode.lineColor = 0xff0000ff;//mark 'Series 2'
					vis.data.nodes[j].nextNode.lineWidth = 8;
					
					break;
				}
				
				else if (vis.data.nodes[j].data.label == value.substring(0, value.length-1))  //the term from javascript with a surfix 'p'
				{	
					vis.update(1, "nodes","main").play();//perform the collapse
					vis.data.nodes[j].lineColor = 0xff0000ff;
					vis.data.nodes[j].lineWidth = 8;

					break;
				}
					//vis.data.nodes.setProperties({lineColor: 0xffff0000, lineWidth: 4}, null, vis.data.nodes[j].label == value); 
			}
			//
		}
		
		
		
		/**
		 * Create a Geological Time Scale tree
		 */
		public function gtsTree() : Tree
		{
			var gTree:Tree = new Tree();
			
			//------Root------//
			var gtsRoot:NodeSprite = gTree.addRoot();
			gtsRoot.fillColor = 0xffffffff;
			gtsRoot.name = "rootOfAll";
			gtsRoot.visible = false;
		
			//			var Unknown:NodeSprite = gTree.addChild(gtsRoot);
			//				Unknown.fillColor = 0xffffffff;
			//				Unknown.name = "unknown";
			//				Unknown.visible = false;
			
			//------Super-Eonothem------//
			var Precambrian:NodeSprite = gTree.addChild(gtsRoot);
			Precambrian.fillColor = 0xffF74370;
			Precambrian.name = "Precambrian";// 前寒武系Precambrian
			
			var EmptySuperEon:NodeSprite = gTree.addChild(gtsRoot);
			EmptySuperEon.fillColor = 0xffFFFFFF;
			EmptySuperEon.name = "";
			
			//------Eonothem------//	
			var Hadean:NodeSprite = gTree.addChild(Precambrian);
			Hadean.fillColor = 0xffAE027E;
			Hadean.name = "Hadean (Informal)";
			//Hadean.size = 9;
			var Archean:NodeSprite = gTree.addChild(Precambrian);
			Archean.fillColor = 0xffF0047F;	
			Archean.name = "Archean";
			//Archean.size = 0.5;
			var Proterozoic:NodeSprite = gTree.addChild(Precambrian);
			Proterozoic.fillColor = 0xffF73563;
			Proterozoic.name = "Proterozoic";
			//Proterozoic.size = 0.5;
			var Phanerozoic:NodeSprite = gTree.addChild(EmptySuperEon);
			Phanerozoic.fillColor = 0xff9AD9DD;
			Phanerozoic.name = "Phanerozoic";
			//Phanerozoic.size = 0.5;
			
			//------Erathem------//	
			/*--sons of Hadean have no meaning, just in order to make Hadean visible on user interface--*/
			var Hadean_son1:NodeSprite = gTree.addChild(Hadean);
			Hadean_son1.fillColor = 0xffffffff;
			Hadean_son1.name = "";
			Hadean_son1.visible = false;
			
			var Hadean_son2:NodeSprite = gTree.addChild(Hadean);
			Hadean_son2.fillColor = 0xffffffff;
			Hadean_son2.name = "";
			Hadean_son2.visible = false;
			/*------------------------------------------------------------------------------------------*/
			
			var Eoarchean:NodeSprite = gTree.addChild(Archean);
			Eoarchean.fillColor = 0xffDA037F;
			Eoarchean.name = "Eoarchean";
			var Paleoarchean:NodeSprite = gTree.addChild(Archean);
			Paleoarchean.fillColor = 0xffF4449F;
			Paleoarchean.name = "Paleoarchean";
			var Mesoarchean:NodeSprite = gTree.addChild(Archean);
			Mesoarchean.fillColor = 0xffF768A9;
			Mesoarchean.name = "Mesoarchean";			
			var Neoarchean:NodeSprite = gTree.addChild(Archean);
			Neoarchean.fillColor = 0xffF99BC1;
			Neoarchean.name = "Neoarchean";	
			var Paleoproterozoic:NodeSprite = gTree.addChild(Proterozoic);
			Paleoproterozoic.fillColor = 0xffF74370;
			Paleoproterozoic.name = "Paleoproterozoic";
			var Mesoproterozoic:NodeSprite = gTree.addChild(Proterozoic);
			Mesoproterozoic.fillColor = 0xffFDB462;
			Mesoproterozoic.name = "Mesoproterozoic";				
			var Neoproterozoic:NodeSprite = gTree.addChild(Proterozoic);
			Neoproterozoic.fillColor = 0xffFEB342;
			Neoproterozoic.name = "Neoproterozoic";				
			var Paleozoic:NodeSprite = gTree.addChild(Phanerozoic);
			Paleozoic.fillColor = 0xff99C08D;
			Paleozoic.name = "Paleozoic";				
			var Mesozoic:NodeSprite = gTree.addChild(Phanerozoic);
			Mesozoic.fillColor = 0xff67C5CA;
			Mesozoic.name = "Mesozoic";
			var Cenozoic:NodeSprite = gTree.addChild(Phanerozoic);
			Cenozoic.fillColor = 0xffF2F91D;
			Cenozoic.name = "Cenozoic";
			
			//------System------//		
			var Siderian:NodeSprite = gTree.addChild(Paleoproterozoic);
			Siderian.fillColor = 0xffF74F7C ;
			Siderian.name = "Siderian";	
			var Rhyacian:NodeSprite = gTree.addChild(Paleoproterozoic);
			Rhyacian.fillColor = 0xffF75B89;
			Rhyacian.name = "Rhyacian";	
			var Orosirian:NodeSprite = gTree.addChild(Paleoproterozoic);
			Orosirian.fillColor = 0xffF76898;
			Orosirian.name = "Orosirian";					
			var Statherian:NodeSprite = gTree.addChild(Paleoproterozoic);
			Statherian.fillColor = 0xffF875A7;
			Statherian.name = "Statherian";					
			var Calymmian:NodeSprite = gTree.addChild(Mesoproterozoic);
			Calymmian.fillColor = 0xffFDC07A;
			Calymmian.name = "Calymmian";					
			var Ectasian:NodeSprite = gTree.addChild(Mesoproterozoic);
			Ectasian.fillColor = 0xffFDCC8A;
			Ectasian.name = "Ectasian";					
			var Stenian:NodeSprite = gTree.addChild(Mesoproterozoic);
			Stenian.fillColor = 0xffFED99A;
			Stenian.name = "Stenian";					
			var Tonian:NodeSprite = gTree.addChild(Neoproterozoic);
			Tonian.fillColor = 0xffFEBF4E;
			Tonian.name = "Tonian";					
			var Cryogenian:NodeSprite = gTree.addChild(Neoproterozoic);
			Cryogenian.fillColor = 0xffFECC5C;
			Cryogenian.name = "Cryogenian";						
			var Ediacaran:NodeSprite = gTree.addChild(Neoproterozoic);
			Ediacaran.fillColor = 0xffFED96A;
			Ediacaran.name = "Ediacaran";						
			
			var Cambrian:NodeSprite = gTree.addChild(Paleozoic);
			Cambrian.fillColor = 0xff7FA056;
			Cambrian.name = "Cambrian";
			var Ordovician:NodeSprite = gTree.addChild(Paleozoic);
			Ordovician.fillColor = 0xff009270;
			Ordovician.name = "Ordovician";
			var Silurian:NodeSprite = gTree.addChild(Paleozoic);
			Silurian.fillColor = 0xffB3E1B6;
			Silurian.name = "Silurian";	
			var Devonian:NodeSprite = gTree.addChild(Paleozoic);
			Devonian.fillColor = 0xffCB8C37;
			Devonian.name = "Devonian";				
			var Carboniferous:NodeSprite = gTree.addChild(Paleozoic);
			Carboniferous.fillColor = 0xff67A599;
			Carboniferous.name = "Carboniferous";			
			var Permian:NodeSprite = gTree.addChild(Paleozoic);
			Permian.fillColor = 0xffF04028;
			Permian.name = "Permian";				
			
			var Triassic:NodeSprite = gTree.addChild(Mesozoic);
			Triassic.fillColor = 0xff812B92;
			Triassic.name = "Triassic";				
			var Jurassic:NodeSprite = gTree.addChild(Mesozoic);
			Jurassic.fillColor = 0xff34B2C9;
			Jurassic.name = "Jurassic";				
			var Cretaceous:NodeSprite = gTree.addChild(Mesozoic);
			Cretaceous.fillColor = 0xff7FC64E;
			Cretaceous.name = "Cretaceous";				
			
			var Paleogene:NodeSprite = gTree.addChild(Cenozoic);
			Paleogene.fillColor = 0xffFD9A52;
			Paleogene.name = "Paleogene";				
			var Neogene:NodeSprite = gTree.addChild(Cenozoic);
			Neogene.fillColor = 0xffFFE619;
			Neogene.name = "Neogene";				
			var Quaternary:NodeSprite = gTree.addChild(Cenozoic);
			Quaternary.fillColor = 0xffF9F97F;
			Quaternary.name = "Quaternary";				
			
			//------Subsystem------//	
			//------Only Pennsylvanian and Mississippian are true, others are false------//	
	   /*   var Siderian_Son:NodeSprite = gTree.addChild(Siderian);
			Siderian_Son.fillColor = 0xffF74F7C ;
			Siderian_Son.name = "";	
			var Rhyacian_Son:NodeSprite = gTree.addChild(Rhyacian);
			Rhyacian_Son.fillColor = 0xffF75B89;
			Rhyacian_Son.name = "";	
			var Orosirian_Son:NodeSprite = gTree.addChild(Orosirian);
			Orosirian_Son.fillColor = 0xffF76898;
			Orosirian_Son.name = "";					
			var Statherian_Son:NodeSprite = gTree.addChild(Statherian);
			Statherian_Son.fillColor = 0xffF875A7;
			Statherian_Son.name = "";					
			var Calymmian_Son:NodeSprite = gTree.addChild(Calymmian);
			Calymmian_Son.fillColor = 0xffFDC07A;
			Calymmian_Son.name = "";					
			var Ectasian_Son:NodeSprite = gTree.addChild(Ectasian);
			Ectasian_Son.fillColor = 0xffFDCC8A;
			Ectasian_Son.name = "";					
			var Stenian_Son:NodeSprite = gTree.addChild(Stenian);
			Stenian_Son.fillColor = 0xffFED99A;
			Stenian_Son.name = "";					
			var Tonian_Son:NodeSprite = gTree.addChild(Tonian);
			Tonian_Son.fillColor = 0xffFEBF4E;
			Tonian_Son.name = "";					
			var Cryogenian_Son:NodeSprite = gTree.addChild(Cryogenian);
			Cryogenian_Son.fillColor = 0xffFECC5C;
			Cryogenian_Son.name = "";						
			var Ediacaran_Son:NodeSprite = gTree.addChild(Ediacaran);
			Ediacaran_Son.fillColor = 0xffFED96A;
			Ediacaran_Son.name = "";	*/					
			
			var Cambrian_Son:NodeSprite = gTree.addChild(Cambrian);
			Cambrian_Son.fillColor = 0xff7FA056;
			Cambrian_Son.name = "";
			var Ordovician_Son:NodeSprite = gTree.addChild(Ordovician);
			Ordovician_Son.fillColor = 0xff009270;
			Ordovician_Son.name = "";
			var Silurian_Son:NodeSprite = gTree.addChild(Silurian);
			Silurian_Son.fillColor = 0xffB3E1B6;
			Silurian_Son.name = "";	
			var Devonian_Son:NodeSprite = gTree.addChild(Devonian);
			Devonian_Son.fillColor = 0xffCB8C37;
			Devonian_Son.name = "";		
			
			var Mississippian:NodeSprite = gTree.addChild(Carboniferous);
			Mississippian.fillColor = 0xff678F66;
			Mississippian.name = "Mississippian";		
			var Pennsylvanian:NodeSprite = gTree.addChild(Carboniferous);
			Pennsylvanian.fillColor = 0xff99C2B5;
			Pennsylvanian.name = "Pennsylvanian";	
			
			var Permian_Son:NodeSprite = gTree.addChild(Permian);
			Permian_Son.fillColor = 0xffF04028;
			Permian_Son.name = "";				
			
			var Triassic_Son:NodeSprite = gTree.addChild(Triassic);
			Triassic_Son.fillColor = 0xff812B92;
			Triassic_Son.name = "";				
			var Jurassic_Son:NodeSprite = gTree.addChild(Jurassic);
			Jurassic_Son.fillColor = 0xff34B2C9;
			Jurassic_Son.name = "";				
			var Cretaceous_Son:NodeSprite = gTree.addChild(Cretaceous);
			Cretaceous_Son.fillColor = 0xff7FC64E;
			Cretaceous_Son.name = "";				
			
			var Paleogene_Son:NodeSprite = gTree.addChild(Paleogene);
			Paleogene_Son.fillColor = 0xffFD9A52;
			Paleogene_Son.name = "";				
			var Neogene_Son:NodeSprite = gTree.addChild(Neogene);
			Neogene_Son.fillColor = 0xffFFE619;
			Neogene_Son.name = "";				
			var Quaternary_Son:NodeSprite = gTree.addChild(Quaternary);
			Quaternary_Son.fillColor = 0xffF9F97F;
			Quaternary_Son.name = "";			
			
			
			//------Series------//		
			/*var Lower_Cambrian:NodeSprite = gTree.addChild(Cambrian_Son); //Terreneuvian and Series_2   (Series_2: 0xff99C078)
			Lower_Cambrian.fillColor = 0xff8CB06C;
			Lower_Cambrian.name = "Lower Cambrian";	
			var Middle_Cambrian:NodeSprite = gTree.addChild(Cambrian_Son); // Series_3
			Middle_Cambrian.fillColor = 0xffA6CF86;
			Middle_Cambrian.name = "Middle Cambrian";									
			var Upper_Cambrian:NodeSprite = gTree.addChild(Cambrian_Son); //Furongian
			Upper_Cambrian.fillColor = 0xffB3E095;
			Upper_Cambrian.name = "Upper Cambrian";	*/
			
			var Terreneuvian:NodeSprite = gTree.addChild(Cambrian_Son); 
			Terreneuvian.fillColor = 0xff8CB06C;
			Terreneuvian.name = "Terreneuvian";	
			var Series_2:NodeSprite = gTree.addChild(Cambrian_Son); 
			Series_2.fillColor = 0xff99C078;
			Series_2.name = "Series 2";					
			var Series_3:NodeSprite = gTree.addChild(Cambrian_Son);
			Series_3.fillColor = 0xffA6CF86;
			Series_3.name = "Series 3";					
			var Furongian:NodeSprite = gTree.addChild(Cambrian_Son); 
			Furongian.fillColor = 0xffB3E095;
			Furongian.name = "Furongian";	
			
			var Lower_Ordovician:NodeSprite = gTree.addChild(Ordovician_Son);
			Lower_Ordovician.fillColor = 0xff1A9D6F;
			Lower_Ordovician.name = "Lower Ordovician";				
			var Middle_Ordovician:NodeSprite = gTree.addChild(Ordovician_Son);
			Middle_Ordovician.fillColor = 0xff4DB47E;
			Middle_Ordovician.name = "Middle Ordovician";					
			var Upper_Ordovician:NodeSprite = gTree.addChild(Ordovician_Son);
			Upper_Ordovician.fillColor = 0xff7FCA93;
			Upper_Ordovician.name = "Upper Ordovician";	
			
			var Llandovery:NodeSprite = gTree.addChild(Silurian_Son);
			Llandovery.fillColor = 0xff99D7B3;
			Llandovery.name = "Llandovery";					
			var Wenlock:NodeSprite = gTree.addChild(Silurian_Son);
			Wenlock.fillColor = 0xffB3E1C2;
			Wenlock.name = "Wenlock";						
			var Ludlow:NodeSprite = gTree.addChild(Silurian_Son);
			Ludlow.fillColor = 0xffBFE6CF;
			Ludlow.name = "Ludlow";						
			var Pridoli:NodeSprite = gTree.addChild(Silurian_Son);
			Pridoli.fillColor = 0xffE6F5E1;
			Pridoli.name = "Pridoli";		
			
			var Lower_Devonian:NodeSprite = gTree.addChild(Devonian_Son);
			Lower_Devonian.fillColor = 0xffE5AC4D;
			Lower_Devonian.name = "Lower Devonian";						
			var Middle_Devonian:NodeSprite = gTree.addChild(Devonian_Son);
			Middle_Devonian.fillColor = 0xffF1C868;
			Middle_Devonian.name = "Middle Devonian";						
			var Upper_Devonian:NodeSprite = gTree.addChild(Devonian_Son);
			Upper_Devonian.fillColor = 0xffF1E19D;
			Upper_Devonian.name = "Upper Devonian";						
			

			var Lower_Mississippian:NodeSprite = gTree.addChild(Mississippian);
			Lower_Mississippian.fillColor = 0xff80AB6C;
			Lower_Mississippian.name = "Lower Mississippian";						
			var Middle_Mississippian:NodeSprite = gTree.addChild(Mississippian);
			Middle_Mississippian.fillColor = 0xff99B46C;
			Middle_Mississippian.name = "Middle Mississippian";						
			var Upper_Mississippian:NodeSprite = gTree.addChild(Mississippian);
			Upper_Mississippian.fillColor = 0xffB3BE6C;
			Upper_Mississippian.name = "Upper Mississippian";		
			
			var Lower_Pennsylvanian:NodeSprite = gTree.addChild(Pennsylvanian);
			Lower_Pennsylvanian.fillColor = 0xff8CBEB4;
			Lower_Pennsylvanian.name = "Lower Pennsylvanian";						
			var Middle_Pennsylvanian:NodeSprite = gTree.addChild(Pennsylvanian);
			Middle_Pennsylvanian.fillColor = 0xffA6C7B7;
			Middle_Pennsylvanian.name = "Middle Pennsylvanian";						
			var Upper_Pennsylvanian:NodeSprite = gTree.addChild(Pennsylvanian);
			Upper_Pennsylvanian.fillColor = 0xffBFD0BA;
			Upper_Pennsylvanian.name = "Upper Pennsylvanian";	
			
			
			var Cisuralian:NodeSprite = gTree.addChild(Permian_Son);
			Cisuralian.fillColor = 0xffEF5845;
			Cisuralian.name = "Cisuralian";	
			var Guadalupian:NodeSprite = gTree.addChild(Permian_Son);
			Guadalupian.fillColor = 0xffFB745C;
			Guadalupian.name = "Guadalupian";	
			var Lopingian:NodeSprite = gTree.addChild(Permian_Son);
			Lopingian.fillColor = 0xffFBA794;
			Lopingian.name = "Lopingian";					
			
			var Lower_Triassic:NodeSprite = gTree.addChild(Triassic_Son);
			Lower_Triassic.fillColor = 0xff983999;
			Lower_Triassic.name = "Lower Triassic";					
			var Middle_Triassic:NodeSprite = gTree.addChild(Triassic_Son);
			Middle_Triassic.fillColor = 0xffB168B1;
			Middle_Triassic.name = "Middle Triassic";					
			var Upper_Triassic:NodeSprite = gTree.addChild(Triassic_Son);
			Upper_Triassic.fillColor = 0xffBD8CC3;
			Upper_Triassic.name = "Upper Triassic";	
			
			var Lower_Jurassic:NodeSprite = gTree.addChild(Jurassic_Son);
			Lower_Jurassic.fillColor = 0xff42AED0;
			Lower_Jurassic.name = "Lower Jurassic";					
			var Middle_Jurassic:NodeSprite = gTree.addChild(Jurassic_Son);
			Middle_Jurassic.fillColor = 0xff80CFD8;
			Middle_Jurassic.name = "Middle Jurassic";					
			var Upper_Jurassic:NodeSprite = gTree.addChild(Jurassic_Son);
			Upper_Jurassic.fillColor = 0xffB3E3EE;
			Upper_Jurassic.name = "Upper Jurassic";	
			
			var Lower_Cretaceous:NodeSprite = gTree.addChild(Cretaceous_Son);
			Lower_Cretaceous.fillColor = 0xff8CCD57;
			Lower_Cretaceous.name = "Lower Cretaceous";	
			var Upper_Cretaceous:NodeSprite = gTree.addChild(Cretaceous_Son);
			Upper_Cretaceous.fillColor = 0xffA6D84A;
			Upper_Cretaceous.name = "Upper Cretaceous";					
			
			var Paleocene:NodeSprite = gTree.addChild(Paleogene_Son);
			Paleocene.fillColor = 0xffFDA75F;
			Paleocene.name = "Paleocene";					
			var Eocene:NodeSprite = gTree.addChild(Paleogene_Son);
			Eocene.fillColor = 0xffFDB46C;
			Eocene.name = "Eocene";						
			var Oligocene:NodeSprite = gTree.addChild(Paleogene_Son);
			Oligocene.fillColor = 0xffFDC07A;
			Oligocene.name = "Oligocene";		
			
			var Miocene:NodeSprite = gTree.addChild(Neogene_Son);
			Miocene.fillColor = 0xffFFFF00;
			Miocene.name = "Miocene";						
			var Pliocene:NodeSprite = gTree.addChild(Neogene_Son);
			Pliocene.fillColor = 0xffFFFF99;
			Pliocene.name = "Pliocene";	
			
			var Pleistocene:NodeSprite = gTree.addChild(Quaternary_Son);
			Pleistocene.fillColor = 0xffFFF2AE;
			Pleistocene.name = "Pleistocene";					
			var Holocene:NodeSprite = gTree.addChild(Quaternary_Son);
			Holocene.fillColor = 0xffFEF2E0;
			Holocene.name = "Holocene";								
			
			
			//------Stage------//	
			/*var Fortunian:NodeSprite = gTree.addChild(Lower_Cambrian);
			Fortunian.fillColor = 0xff99B575;
			Fortunian.name = "Fortunian";					
			var Stage_2:NodeSprite = gTree.addChild(Lower_Cambrian);
			Stage_2.fillColor = 0xffA6BA80;
			Stage_2.name = "Stage 2";	
			var Stage_3:NodeSprite = gTree.addChild(Lower_Cambrian);
			Stage_3.fillColor = 0xffA6C583;
			Stage_3.name = "Stage 3";	
			var Stage_4:NodeSprite = gTree.addChild(Lower_Cambrian);
			Stage_4.fillColor = 0xffB3CA8E;
			Stage_4.name = "Stage 4";	
			var Stage_5:NodeSprite = gTree.addChild(Middle_Cambrian);
			Stage_5.fillColor = 0xffB3D492;
			Stage_5.name = "Stage 5";	
			var Drumian:NodeSprite = gTree.addChild(Middle_Cambrian);
			Drumian.fillColor = 0xffBFD99D;
			Drumian.name = "Drumian";	
			var Guzhangian:NodeSprite = gTree.addChild(Middle_Cambrian);
			Guzhangian.fillColor = 0xffCCDFAA;
			Guzhangian.name = "Guzhangian";	
			var Paibian:NodeSprite = gTree.addChild(Upper_Cambrian);
			Paibian.fillColor = 0xffCCEBAE;
			Paibian.name = "Paibian";	
			var Stage_9:NodeSprite = gTree.addChild(Upper_Cambrian);
			Stage_9.fillColor = 0xffD9F0BB;
			Stage_9.name = "Stage 9";	
			var Stage_10:NodeSprite = gTree.addChild(Upper_Cambrian);
			Stage_10.fillColor = 0xffE6F5C9;
			Stage_10.name = "Stage 10";	*/
			
			var Fortunian:NodeSprite = gTree.addChild(Terreneuvian);
			Fortunian.fillColor = 0xff99B575;
			Fortunian.name = "Fortunian";					
			var Stage_2:NodeSprite = gTree.addChild(Terreneuvian);
			Stage_2.fillColor = 0xffA6BA80;
			Stage_2.name = "Stage 2";	
			var Stage_3:NodeSprite = gTree.addChild(Series_2);
			Stage_3.fillColor = 0xffA6C583;
			Stage_3.name = "Stage 3";	
			var Stage_4:NodeSprite = gTree.addChild(Series_2);
			Stage_4.fillColor = 0xffB3CA8E;
			Stage_4.name = "Stage 4";	
			var Stage_5:NodeSprite = gTree.addChild(Series_3);
			Stage_5.fillColor = 0xffB3D492;
			Stage_5.name = "Stage 5";	
			var Drumian:NodeSprite = gTree.addChild(Series_3);
			Drumian.fillColor = 0xffBFD99D;
			Drumian.name = "Drumian";	
			var Guzhangian:NodeSprite = gTree.addChild(Series_3);
			Guzhangian.fillColor = 0xffCCDFAA;
			Guzhangian.name = "Guzhangian";	
			var Paibian:NodeSprite = gTree.addChild(Furongian);
			Paibian.fillColor = 0xffCCEBAE;
			Paibian.name = "Paibian";	
			var Stage_9:NodeSprite = gTree.addChild(Furongian);
			Stage_9.fillColor = 0xffD9F0BB;
			Stage_9.name = "Stage 9";	
			var Stage_10:NodeSprite = gTree.addChild(Furongian);
			Stage_10.fillColor = 0xffE6F5C9;
			Stage_10.name = "Stage 10";	
			
			var Tremadocian:NodeSprite = gTree.addChild(Lower_Ordovician);
			Tremadocian.fillColor = 0xff33A97E;
			Tremadocian.name = "Tremadocian";					
			var Floian:NodeSprite = gTree.addChild(Lower_Ordovician);
			Floian.fillColor = 0xff41B087;
			Floian.name = "Floian";					
			var Dapingian:NodeSprite = gTree.addChild(Middle_Ordovician);
			Dapingian.fillColor = 0xff66C092;
			Dapingian.name = "Dapingian";					
			var Darriwilian:NodeSprite = gTree.addChild(Middle_Ordovician);
			Darriwilian.fillColor = 0xff74C69C;
			Darriwilian.name = "Darriwilian";	
			var Sandbian:NodeSprite = gTree.addChild(Upper_Ordovician);
			Sandbian.fillColor = 0xff8CD094;
			Sandbian.name = "Sandbian";	
			var Katian:NodeSprite = gTree.addChild(Upper_Ordovician);
			Katian.fillColor = 0xff99D69F;
			Katian.name = "Katian";	
			var Hirnantian:NodeSprite = gTree.addChild(Upper_Ordovician);
			Hirnantian.fillColor = 0xffA6DBAB;
			Hirnantian.name = "Hirnantian";	
			
			var Rhuddanian:NodeSprite = gTree.addChild(Llandovery);
			Rhuddanian.fillColor = 0xffA6DCB5;
			Rhuddanian.name = "Rhuddanian";			
			var Aeronian:NodeSprite = gTree.addChild(Llandovery);
			Aeronian.fillColor = 0xffB3E1C2;
			Aeronian.name = "Aeronian";					
			var Telychian:NodeSprite = gTree.addChild(Llandovery);
			Telychian.fillColor = 0xffBFE6CF;
			Telychian.name = "Telychian";					
			var Sheinwoodian:NodeSprite = gTree.addChild(Wenlock);
			Sheinwoodian.fillColor = 0xffBFE6C3;
			Sheinwoodian.name = "Sheinwoodian";					
			var Homerian:NodeSprite = gTree.addChild(Wenlock);
			Homerian.fillColor = 0xffCCEBD1;
			Homerian.name = "Homerian";					
			var Gorstian:NodeSprite = gTree.addChild(Ludlow);
			Gorstian.fillColor = 0xffCCECDD;
			Gorstian.name = "Gorstian";					
			var Ludfordian:NodeSprite = gTree.addChild(Ludlow);
			Ludfordian.fillColor = 0xffD9F0DF;
			Ludfordian.name = "Ludfordian";	
			/*--Son of Pridoli: no name, and same color as Pridoli--*/
			var Pridoli_son:NodeSprite = gTree.addChild(Pridoli);
			Pridoli_son.fillColor = 0xffE6F5E1;
			Pridoli_son.name = "";	
			
			var Lochkovian:NodeSprite = gTree.addChild(Lower_Devonian);
			Lochkovian.fillColor = 0xffE5B75A;
			Lochkovian.name = "Lochkovian";			
			var Pragian:NodeSprite = gTree.addChild(Lower_Devonian);
			Pragian.fillColor = 0xffE5C468;
			Pragian.name = "Pragian";					
			var Emsian:NodeSprite = gTree.addChild(Lower_Devonian);
			Emsian.fillColor = 0xffE5D075;
			Emsian.name = "Emsian";					
			var Eifelian:NodeSprite = gTree.addChild(Middle_Devonian);
			Eifelian.fillColor = 0xffF1D576;
			Eifelian.name = "Eifelian";					
			var Givetian:NodeSprite = gTree.addChild(Middle_Devonian);
			Givetian.fillColor = 0xffF1E185;
			Givetian.name = "Givetian";					
			var Frasnian:NodeSprite = gTree.addChild(Upper_Devonian);
			Frasnian.fillColor = 0xffF2EDAD;
			Frasnian.name = "Frasnian";					
			var Famennian:NodeSprite = gTree.addChild(Upper_Devonian);
			Famennian.fillColor = 0xffF2EDC5;
			Famennian.name = "Famennian";					
			
			var Tournaisian:NodeSprite = gTree.addChild(Lower_Mississippian);
			Tournaisian.fillColor = 0xff8CB06C;
			Tournaisian.name = "Tournaisian";			
			var Visean:NodeSprite = gTree.addChild(Middle_Mississippian);
			Visean.fillColor = 0xffA6B96C;
			Visean.name = "Visean";					
			var Serpukhovian:NodeSprite = gTree.addChild(Upper_Mississippian);
			Serpukhovian.fillColor = 0xffBFC26B;
			Serpukhovian.name = "Serpukhovian";					
			var Bashkirian:NodeSprite = gTree.addChild(Lower_Pennsylvanian);
			Bashkirian.fillColor = 0xff99C2B5;
			Bashkirian.name = "Bashkirian";					
			var Moscovian:NodeSprite = gTree.addChild(Middle_Pennsylvanian);
			Moscovian.fillColor = 0xffC7CBB9;
			Moscovian.name = "Moscovian";					
			var Kasimovian:NodeSprite = gTree.addChild(Upper_Pennsylvanian);
			Kasimovian.fillColor = 0xffBFD0C5;
			Kasimovian.name = "Kasimovian";					
			var Gzhelian:NodeSprite = gTree.addChild(Upper_Pennsylvanian);
			Gzhelian.fillColor = 0xffCCD4C7;
			Gzhelian.name = "Gzhelian";			
			
			var Asselian:NodeSprite = gTree.addChild(Cisuralian);
			Asselian.fillColor = 0xffE36350;
			Asselian.name = "Asselian";			
			var Sakmarian:NodeSprite = gTree.addChild(Cisuralian);
			Sakmarian.fillColor = 0xffE36F5C;
			Sakmarian.name = "Sakmarian";					
			var Artinskian:NodeSprite = gTree.addChild(Cisuralian);
			Artinskian.fillColor = 0xffE37B68;
			Artinskian.name = "Artinskian";					
			var Kungurian:NodeSprite = gTree.addChild(Cisuralian);
			Kungurian.fillColor = 0xffE38776;
			Kungurian.name = "Kungurian";					
			var Roadian:NodeSprite = gTree.addChild(Guadalupian);
			Roadian.fillColor = 0xffFB8069;
			Roadian.name = "Roadian";					
			var Wordian:NodeSprite = gTree.addChild(Guadalupian);
			Wordian.fillColor = 0xffFB8D76;
			Wordian.name = "Wordian";					
			var Capitanian:NodeSprite = gTree.addChild(Guadalupian);
			Capitanian.fillColor = 0xffFB9A85;
			Capitanian.name = "Capitanian";					
			var Wuchiapingian:NodeSprite = gTree.addChild(Lopingian);
			Wuchiapingian.fillColor = 0xffFCB4A2;
			Wuchiapingian.name = "Wuchiapingian";					
			var Changhsingian:NodeSprite = gTree.addChild(Lopingian);
			Changhsingian.fillColor = 0xffFCC0B2;
			Changhsingian.name = "Changhsingian";					
			
			var Induan:NodeSprite = gTree.addChild(Lower_Triassic);
			Induan.fillColor = 0xffA4469F;
			Induan.name = "Induan";					
			var Olenekian:NodeSprite = gTree.addChild(Lower_Triassic);
			Olenekian.fillColor = 0xffB051A5;
			Olenekian.name = "Olenekian";					
			var Anisian:NodeSprite = gTree.addChild(Middle_Triassic);
			Anisian.fillColor = 0xffBC75B7;
			Anisian.name = "Anisian";					
			var Ladinian:NodeSprite = gTree.addChild(Middle_Triassic);
			Ladinian.fillColor = 0xffC983BF;
			Ladinian.name = "Ladinian";					
			var Carnian:NodeSprite = gTree.addChild(Upper_Triassic);
			Carnian.fillColor = 0xffC99BC9;
			Carnian.name = "Carnian";					
			var Norian:NodeSprite = gTree.addChild(Upper_Triassic);
			Norian.fillColor = 0xffD6AAD3;
			Norian.name = "Norian";					
			var Rhaetian:NodeSprite = gTree.addChild(Upper_Triassic);
			Rhaetian.fillColor = 0xffE3B9DB;
			Rhaetian.name = "Rhaetian";					
			
			var Hettangian:NodeSprite = gTree.addChild(Lower_Jurassic);
			Hettangian.fillColor = 0xff4EB3D3;
			Hettangian.name = "Hettangian";					
			var Sinemurian:NodeSprite = gTree.addChild(Lower_Jurassic);
			Sinemurian.fillColor = 0xff67BCD8;
			Sinemurian.name = "Sinemurian";					
			var Pliensbachian:NodeSprite = gTree.addChild(Lower_Jurassic);
			Pliensbachian.fillColor = 0xff80C5DD;
			Pliensbachian.name = "Pliensbachian";					
			var Toarcian:NodeSprite = gTree.addChild(Lower_Jurassic);
			Toarcian.fillColor = 0xff99CEE3;
			Toarcian.name = "Toarcian";					
			var Aalenian:NodeSprite = gTree.addChild(Middle_Jurassic);
			Aalenian.fillColor = 0xffA6D9DD;
			Aalenian.name = "Aalenian";					
			var Bajocian:NodeSprite = gTree.addChild(Middle_Jurassic);
			Bajocian.fillColor = 0xffA6DDE0;
			Bajocian.name = "Bajocian";					
			var Bathonian:NodeSprite = gTree.addChild(Middle_Jurassic);
			Bathonian.fillColor = 0xffB3E2E3;
			Bathonian.name = "Bathonian";					
			var Callovian:NodeSprite = gTree.addChild(Middle_Jurassic);
			Callovian.fillColor = 0xffBFE7E5;
			Callovian.name = "Callovian";					
			var Oxfordian:NodeSprite = gTree.addChild(Upper_Jurassic);
			Oxfordian.fillColor = 0xffBFE7F1;
			Oxfordian.name = "Oxfordian";					
			var Kimmeridgian:NodeSprite = gTree.addChild(Upper_Jurassic);
			Kimmeridgian.fillColor = 0xffCCECF4;
			Kimmeridgian.name = "Kimmeridgian";					
			var Tithonian:NodeSprite = gTree.addChild(Upper_Jurassic);
			Tithonian.fillColor = 0xffD9F1F7;
			Tithonian.name = "Tithonian";		
			
			var Berriasian:NodeSprite = gTree.addChild(Lower_Cretaceous);
			Berriasian.fillColor = 0xff8CCD60;
			Berriasian.name = "Berriasian";					
			var Valanginian:NodeSprite = gTree.addChild(Lower_Cretaceous);
			Valanginian.fillColor = 0xff99D36A;
			Valanginian.name = "Valanginian";					
			var Hauterivian:NodeSprite = gTree.addChild(Lower_Cretaceous);
			Hauterivian.fillColor = 0xffA6D975;
			Hauterivian.name = "Hauterivian";	
			var Barremian:NodeSprite = gTree.addChild(Lower_Cretaceous);
			Barremian.fillColor = 0xffB3DF7F;
			Barremian.name = "Barremian";					
			var Aptian:NodeSprite = gTree.addChild(Lower_Cretaceous);
			Aptian.fillColor = 0xffBFE48A;
			Aptian.name = "Aptian";					
			var Albian:NodeSprite = gTree.addChild(Lower_Cretaceous);
			Albian.fillColor = 0xffCCEA97;
			Albian.name = "Albian";					
			var Cenomanian:NodeSprite = gTree.addChild(Upper_Cretaceous);
			Cenomanian.fillColor = 0xffB3DE53;
			Cenomanian.name = "Cenomanian";					
			var Turonian:NodeSprite = gTree.addChild(Upper_Cretaceous);
			Turonian.fillColor = 0xffBFE35D;
			Turonian.name = "Turonian";					
			var Coniacian:NodeSprite = gTree.addChild(Upper_Cretaceous);
			Coniacian.fillColor = 0xffCCE968;
			Coniacian.name = "Coniacian";					
			var Santonian:NodeSprite = gTree.addChild(Upper_Cretaceous);
			Santonian.fillColor = 0xffD9EF74;
			Santonian.name = "Santonian";					
			var Campanian:NodeSprite = gTree.addChild(Upper_Cretaceous);
			Campanian.fillColor = 0xffE6F47F;
			Campanian.name = "Campanian";					
			var Maastrichtian:NodeSprite = gTree.addChild(Upper_Cretaceous);
			Maastrichtian.fillColor = 0xffF2FA8C;
			Maastrichtian.name = "Maastrichtian";	
			
			var Danian:NodeSprite = gTree.addChild(Paleocene);
			Danian.fillColor = 0xffFDB462;
			Danian.name = "Danian";					
			var Selandian:NodeSprite = gTree.addChild(Paleocene);
			Selandian.fillColor = 0xffFEBF65;
			Selandian.name = "Selandian";					
			var Thanetian:NodeSprite = gTree.addChild(Paleocene);
			Thanetian.fillColor = 0xffFDBF6F;
			Thanetian.name = "Thanetian";					
			var Ypresian:NodeSprite = gTree.addChild(Eocene);
			Ypresian.fillColor = 0xffFCA773;
			Ypresian.name = "Ypresian";					
			var Lutetian:NodeSprite = gTree.addChild(Eocene);
			Lutetian.fillColor = 0xffFCB482;
			Lutetian.name = "Lutetian";					
			var Bartonian:NodeSprite = gTree.addChild(Eocene);
			Bartonian.fillColor = 0xffFDC091;
			Bartonian.name = "Bartonian";					
			var Priabonian:NodeSprite = gTree.addChild(Eocene);
			Priabonian.fillColor = 0xffFDCDA1;
			Priabonian.name = "Priabonian";					
			var Rupelian:NodeSprite = gTree.addChild(Oligocene);
			Rupelian.fillColor = 0xffFED99A;
			Rupelian.name = "Rupelian";					
			var Chattian:NodeSprite = gTree.addChild(Oligocene);
			Chattian.fillColor = 0xffFEE6AA;
			Chattian.name = "Chattian";					
			
			var Aquitanian:NodeSprite = gTree.addChild(Miocene);
			Aquitanian.fillColor = 0xffFFFF33;
			Aquitanian.name = "Aquitanian";					
			var Burdigalian:NodeSprite = gTree.addChild(Miocene);
			Burdigalian.fillColor = 0xffFFFF41;
			Burdigalian.name = "Burdigalian";					
			var Langhian:NodeSprite = gTree.addChild(Miocene);
			Langhian.fillColor = 0xffFFFF4D;
			Langhian.name = "Langhian";					
			var Serravallian:NodeSprite = gTree.addChild(Miocene);
			Serravallian.fillColor = 0xffFFFF59;
			Serravallian.name = "Serravallian";					
			var Tortonian:NodeSprite = gTree.addChild(Miocene);
			Tortonian.fillColor = 0xffFFFF66;
			Tortonian.name = "Tortonian";					
			var Messinian:NodeSprite = gTree.addChild(Miocene);
			Messinian.fillColor = 0xffFFFF73;
			Messinian.name = "Messinian";					
			var Zanclean:NodeSprite = gTree.addChild(Pliocene);
			Zanclean.fillColor = 0xffFFFFB3;
			Zanclean.name = "Zanclean";					
			var Piacenzian:NodeSprite = gTree.addChild(Pliocene);
			Piacenzian.fillColor = 0xffFFFFBF;
			Piacenzian.name = "Piacenzian";					
			
			
			var Gelasian:NodeSprite = gTree.addChild(Pleistocene);
			Gelasian.fillColor = 0xffFFEDB3;
			Gelasian.name = "Gelasian";					
			var Calabrian:NodeSprite = gTree.addChild(Pleistocene);
			Calabrian.fillColor = 0xffFFF2BA;
			Calabrian.name = "Calabrian";					
			var Ionian:NodeSprite = gTree.addChild(Pleistocene);
			Ionian.fillColor = 0xffFFF2C7;
			Ionian.name = "\"Ionian\"";					
			var Upper_Pleistocene:NodeSprite = gTree.addChild(Pleistocene);
			Upper_Pleistocene.fillColor = 0xffFFF2D3;
			Upper_Pleistocene.name = "Upper Pleistocene";	
			
			/*--Son of Holocene: no name, but note that it has a special color--*/
			var Holocene_son:NodeSprite = gTree.addChild(Holocene);
			Holocene_son.fillColor = 0xffFEF2EC;
			Holocene_son.name = "";
			
			return gTree;
		}
	}
}