package font.svg;

import openfl.utils.Assets;
import font.CharacterRanges;
import starling.text.BitmapFont;

/**
 * Takes a list of font definitions and generates BitmapFonts for each font/size.
 * 
 * @author Thomas Byrne
 */
class SvgBitmapFontBatcher
{
	// Use these to measure progress of processing
	@:isVar public var progress(default, null):UInt;
	@:isVar public var total(default, null):UInt;

	var fonts:Array<SvgFontDefSize>;
	var generators:Array<SvgBitmapFontGenerator>;
	var generatorIndex:UInt;
	
    var config:SvgFontGeneratorConfig;
	var registers:Array<BitmapFont->String->Void>;

	public function new(fonts:Array<SvgFontDefSize>, config:SvgFontGeneratorConfig, ?registers:Array<BitmapFont->String->Void>):Void
	{
        this.fonts = fonts;
        this.config = config;
		this.registers = registers;
        
		assessGenerators();
	}

	public function addDefaultRegisters()
	{
		for(generator in generators) generator.addDefaultRegisters();
	}
	
	function assessGenerators() 
	{
		progress = 0;
		total = 0;
		generatorIndex = 0;
		generators = [];

		var svgFonts:Map<String, SvgFont> = new Map();
		var renderers:Map<String, SvgFontRenderer> = new Map();
		
		for (font in fonts)
		{
			var fontName = font.def.family;
			var svgFont = svgFonts.get(fontName);
			var renderer:SvgFontRenderer;
			if(svgFont == null){
				svgFont = SvgFont.fromString( Assets.getText(font.def.svgSource) );
				svgFonts.set(fontName, svgFont);

				renderer = new SvgFontRenderer(svgFont.svgRendererXml);
				renderers.set(fontName, renderer);
			}else{
				renderer = renderers.get(fontName);
			}
			
			var config:SvgFontGeneratorConfig = {
				
				size: font.size,
				forceFamily: font.forceFamily == null ? font.def.family : font.forceFamily,
				characters: CharacterRanges.fromStrings(font.def.ranges),
				
				superSampling: config.superSampling,
				superSamplingScaleThreshold: config.superSamplingScaleThreshold,
				
				gap: config.gap,
				innerPadding: config.innerPadding,
				scaleFactor: config.scaleFactor,
				generateMipMaps: config.generateMipMaps,
				
				snapAdvanceXTo: config.snapAdvanceXTo,
			}
			var generator:SvgBitmapFontGenerator = new SvgBitmapFontGenerator( svgFont, config, registers, renderer );
			generators.push(generator);
			total += generator.total;
			
		}
	}
	
	public function processNow() 
	{
		process(total);
	}
	
	public function process(steps:Int=1) 
	{
		while(steps > 0){
			var generator = generators[generatorIndex];
			while(generator != null && generator.progress >= generator.total){
				generatorIndex++;
				generator = generators[generatorIndex];
			}
			if(generator == null){
				// finished
				progress = total;
				return;
			}

			var progWas = generator.progress;
			generator.process(steps);
			steps -= (generator.progress - progWas);
		}
	}

}

typedef SvgFontDefSize =
{	
	?forceFamily:String,
	def:SvgFontDef,
	size:Float,
}

typedef SvgFontDef =
{
	family:String,
	?svgSource:String,
	ranges:Array<String>,
}