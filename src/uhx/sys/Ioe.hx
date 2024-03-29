package uhx.sys;

import haxe.io.Eof;
import haxe.io.Input;
import haxe.io.Output;

using StringTools;

/**
 * ...
 * @author Skial Bainn
 * Ioe => In Out Error
 */
class Ioe {
	
	@:isVar private var eofChar(get, null):Null<Int>;
	private var stdin:Input;
	private var stdout:Output;
	private var stderr:Output;
	private var content:String;
	private var exitCode:ExitCode = ExitCode.SUCCESS;

	public function new() {
		content = '';
		stdin = Sys.stdin();
		stdout = Sys.stdout();
		stderr = Sys.stderr();
	}
	
	private function process(i:Input = null, o:Output = null):Void {
		if (i != null) stdin = i;
		if (o != null) stdout = o;
		
		if (exitCode != ExitCode.SUCCESS) exit();
		
		var code = -1;
		// For manually or piped text into `stdin` read each byte.
		try while (code != eofChar) {
			code = stdin.readByte();
			if (code != eofChar) content += String.fromCharCode( code );
			
		} catch (e:Eof) { 
			
		} catch (e:Dynamic) { 
			stderr.writeString( '$e' );
			
		}
		
		content = content.trim();
	}
	
	private function prompt(value:String, options:Map<Array<String>, Bool>):Bool {
		var result = false;
		var response = '';
		
		stdout.writeString( '$value\n' );
		response = stdin.readLine();
		
		for (keys in options.keys()) if (keys.indexOf( response ) > -1) {
			result = options.get( keys );
			break;
			
		}
		
		return result;
	}
	
	private function exit():Void {
		stdin.close();
		stdout.close();
		Sys.exit( exitCode );
	}
	
	@:noCompletion private function get_eofChar():Null<Int> {
		if (eofChar == null) eofChar = switch (Sys.systemName().toLowerCase()) {
			case 'windows': 26;	//	^Z
			case _: 4; 			//	^D
		}
		
		return eofChar;
	}
	
}
