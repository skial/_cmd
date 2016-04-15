package uhx.sys;

import haxe.ds.StringMap;

using Lambda;
using StringTools;

/**
 * ...
 * @author Skial Bainn
 * lòd => Command in Haitian Creole 
 */
class Lod {
	
	public var args:Array<String>;
	public var seperator:String = '|*|';
	
	private var pre:PrevLod;
	private var result:StringMap<Array<Dynamic>>;
	
	public function new(args:Array<String>) {
		this.args = args;
		this.result = new StringMap<Array<Dynamic>>();
	}
	
	public function parse():StringMap<Array<Dynamic>> {
		if (args == null) throw 'args can not be null';
		
		set( 'original', args );
		
		return process( prepare( args ) );
	}
	
	private function prepare(args:Array<String>):Array<String> {
		var nargs:Array<String> = [];
		
		for (arg in args) {
			
			var sep = arg.indexOf( seperator );
			
			if (sep > -1) {
				
				var key = arg.substr( 0, sep );
				var value = arg.substr( sep + 1 );
				
				if (value.startsWith('"') || value.startsWith("'")) {
					value = value.substr( 1 );
				}
				
				if (value.endsWith('"') || value.endsWith("'")) {
					value = value.substr( 0, value.length-1 );
				}
				
				nargs.push( key );
				nargs.push( value );
				
			} else {
				
				
				if (arg.startsWith( '--no-' )) {
					
					nargs.push( arg.substr( 4 ) );
					nargs.push( 'false' );
					
				} else {
					
					nargs.push( arg );
					
				}
				
			}
			
		}
		
		return nargs;
	}
	
	private function process(args:Array<String>):StringMap<Array<Dynamic>> {
		for (arg in args) {
			
			// Just dump all remaining args into `argv`
			if (arg == '--') {
				
				var remaining = result.get('original').slice( args.indexOf( arg )+1 );
				set( 'argv', remaining );
				
			} else {
				
				if (arg.startsWith( '--' )) {
					
					// Option eg `--foo`
					arg = arg.substring( arg.lastIndexOf('-') + 1 );
					pre = Option( false, arg );
					set( arg, [] );
					
				} else if (arg.startsWith( '-' )) {
					
					// Short hand option eg `-f`
					arg = arg.substring( arg.lastIndexOf('-') + 1 );
					pre = Option( true, arg);
					set( arg, [] );
					
				} else if (pre != null) {
					
					switch (pre) {
						case Option(_, n):
							set( n, [arg] );
							
						case Value:
							set( 'unmatched', [arg] );
							
					}
					
					//pre = Value;
					
				} else {
					
					// Just dump it in `argv`
					var values = (result.exists( 'argv' ) ? result.get( 'argv' ) : []).concat( [arg] );
					set( 'argv', values );
					
				}
				
			}
			
		}
		
		return result;
	}
	
	private function set(name:String, values:Array<Dynamic>) {
		if (result.exists( name )) {
			
			values = result.get( name ).concat( values );
			
		}
		
		result.set( name, values );
	}
	
}

private enum PrevLod {
	
	Value;
	Option(short:Bool, name:String);
	
}
