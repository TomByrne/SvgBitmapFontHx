package font.svg;

import font.svg.SvgFont.SvgCharacterVO;
import openfl.display.Shape;
import format.svg.SVGData;
import format.svg.SVGRenderer;

/**
 * Renders SVG characters as OpenFL shapes.
 * 
 * @author Thomas Byrne
 */
class SvgFontRenderer
{
	var fontRenderer:SVGRenderer;
	var rendered:Map<String, Shape> = new Map();

    public function new(data:Xml){

		var inXml:Xml = Xml.createDocument();
		inXml.addChild(data);
		var fontData:SVGData = new SVGData(inXml);

		fontRenderer = new SVGRenderer (fontData);
	}
    
	public function render(charName:String) : Shape
	{
		if(rendered.exists(charName)){
			return rendered.get(charName);
		}
		var shape = new Shape();
		shape.graphics.clear();
		fontRenderer.render (shape.graphics, filterById.bind(charName, _, _));
		rendered.set(charName, shape);
		return shape;
	}

	static function filterById(id:String, elemId:String, elemPath:Array<String>) : Bool 
	{
		return elemId == id || elemPath.indexOf(id) != -1;
	}
}