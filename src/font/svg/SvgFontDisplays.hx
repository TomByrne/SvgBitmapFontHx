package font.svg;

import font.svg.SvgFont.SvgCharacterVO;
import openfl.display.Shape;
import format.svg.SVGData;
import format.svg.SVGRenderer;

/**
 * Wraps an SvgFont instance and decorates it with rendered OpenFl Shapes for each character.
 * 
 * @author Thomas Byrne
 */
class SvgFontDisplays
{
    public var svgFont:SvgFont;
	public var asciiToShape:Map<UInt, Shape>;

    public function new(){}

    static public function create(svgFont:SvgFont, ?fill:SvgFontDisplays) : SvgFontDisplays
    {
        if(fill == null) fill = new SvgFontDisplays();
        fill.svgFont = svgFont;
        populateChars(fill);
        return fill;
    }
    
	static function populateChars(fill:SvgFontDisplays) : Void
	{
		
		var inXml:Xml = Xml.createDocument();
		inXml.addChild(fill.svgFont.svgRendererXml);
		var fontData:SVGData = new SVGData ( inXml );
		var fontRenderer:SVGRenderer = new SVGRenderer (fontData);

        fill.asciiToShape = new Map();
        
		for(id in fill.svgFont.asciiCodes)
        {
            var char:SvgCharacterVO = fill.svgFont.asciiToCharacterMap.get(id);
            fill.asciiToShape.set(id, getShape(fontRenderer, char.name));
        }
	}
    
	static function getShape(fontRenderer:SVGRenderer, name:String) : Shape
	{
		var shape:Shape = new Shape();
		fontRenderer.render (shape.graphics, filterById.bind(name, _, _));
		return shape;
	}

	static function filterById(id:String, elemId:String, elemPath:Array<String>) : Bool 
	{
		return elemId == id || elemPath.indexOf(id) != -1;
	}
}