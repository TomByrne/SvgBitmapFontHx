package font.svg;


typedef SvgFontGeneratorConfig = 
{
	?size:Float,
	?forceFamily:String,
	
	?characters:Array<Int>,
	
	?superSampling:Float,
	?superSamplingScaleThreshold:Float, // How small the display object scale has to be to use supersampling by default
	
	?gap:Int,
	?innerPadding:Int,
	?scaleFactor:Float,
	?generateMipMaps:Bool,
	
	?snapAdvanceXTo:Float,
}