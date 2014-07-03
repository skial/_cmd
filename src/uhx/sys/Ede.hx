package uhx.sys;

import haxe.macro.Printer;
import haxe.macro.Type;
import haxe.macro.Expr;
import uhx.macro.KlasImp;
import haxe.macro.Context;
import haxe.macro.Compiler;

using Lambda;
using StringTools;
using uhu.macro.Jumla;

/**
 * ...
 * @author Skial Bainn
 * ede => Help in Haitian Creole 
 */
class Ede {
	
	public static macro function initialize():Void {
		try {
			KlasImp.initalize();
			KlasImp.CLASS_META.set(':cmd', Ede.handler);
		} catch (e:Dynamic) {
			// This assumes that `implements Klas` is not being used
			// but `@:autoBuild` or `@:build` metadata is being used 
			// with the provided `uhx.sys.Ede.build()` method.
		}
	}
	
	public static function build():Array<Field> {
		return handler( Context.getLocalClass().get(), Context.getBuildFields() );
	}

	public static function handler(cls:ClassType, fields:Array<Field>):Array<Field> {
		if (Context.defined( 'display' )) return fields;
		
		if (!fields.exists( 'new' )) {
			throw 'Only class instances are supported';
		}
		
		var _new = fields.get( 'new' );
		
		if (!_new.args().exists( 'args' ))  {
			Context.error( 'Field `new` must have a param named `args` of type `Array<String>`', _new.pos );
		}
		
		// Add commandline methods if they dont exist.
		fields.push( 'help'.mkField().mkPublic()
			.toFFun().body( macro { } )
			.addDoc( 'Show this message.' )
			.addMeta( { name: 'alias', params: [ macro 'h' ], pos: Context.currentPos() } )
		);
		
		// Build a lists of instance field names.
		var instances:Array<Expr> = [];
		// An array of expressions which cast the argument to the fields type.
		var typecasts:Array<Expr> = [];
		
		for (field in fields) if (!field.access.has( APrivate )) {
			
			if (!field.access.has( AStatic ) && field.name != 'new') {
				instances.push( macro $v { field.name } );
			}
			
			switch (field.kind) {
				case FVar(t, _), FProp(_, _, t, _):
					var tname = t.toType().getName();
					
					var aliases = [macro $v { field.name } ]
						.concat( field.meta.exists('alias') ? field.meta.get('alias').params : [] );
					
					var isArray = t.match( TPath( { name:'Array', pack:_, params:_, sub:_ } ) );
					
					var access = if (isArray) {
						macro var v:Array<String> = cast _map.get( name );
					} else {
						macro var v:String = cast _map.get( $v { field.name } )[0];
					}
					
					var e = Jete.coerce(t, macro v);
					
					typecasts.push( 
						aliases.length > 1 ?
							macro for (name in [$a { aliases } ]) {
								if (_map.exists( name )) { 
									$access;
									$p{['this', field.name]} = $e;
									break;
								}
							} 
						: macro if (_map.exists( $v { field.name } )) {
							$access;
							$p{['this', field.name]} = $e;
						}
					);
					
				case FFun(m):
					
					if (field.name != 'new' && field.access.indexOf( AStatic ) == -1) {
						
						field.meta.push( { name:'arity', pos:field.pos, params:[macro $v { m.args.length } ] } );
						
						var aliases = [macro $v { field.name } ]
							.concat( 
								field.meta
									.filter( function(m) return m.name == 'alias' )
									.map( function(m) return m.params[0] ) 
							);
						
						var argcasts:Array<Expr> = [];
						
						for (i in 0...m.args.length) {
							
							argcasts.push( macro @:mergeBlock {
								var v = _args[$v { i } ];
								v = $e { Jete.coerce( m.args[i].type, macro v ) };
							} );
							
						}
						
						var block = if (m.args.length > 0) {
							macro @:mergeBlock {
								var _args = _map.get( name );
								
								if (_args.length < $v { m.args.length } ) {
									throw '' + (name == $v { field.name } ?$v { '--' + field.name } :'-'+name) + $v { ' expects ' + m.args.length + ' args.' };
								} else {
									@:mergeBlock $b{argcasts};
								}
							}
						} else {
							macro $p { ['this', field.name] } ();
						}
						typecasts.push(
							macro for (name in [$a { aliases } ]) {
								if (_map.exists( name )) {
									
									$block;
									
								}
							}
						);
						
					}
			}
			
		}
		
		instances.push( macro 'help' );
		
		// Get all doc info.
		var checks:Array<{doc:Null<String>, meta:Metadata, name:String}> = [ 
			for (f in fields) 
				if (!f.access.has( APrivate ) && !f.access.has( AStatic ) && f.name != 'new') 
					f 
		];
		checks.unshift( cast cls );
		
		var docs:Array<String> = [];
		
		for (check in checks) {
			var part = '';
			if (check.doc == null) check.doc = '';
			
			/*var part = check.doc.replace( '\n', '' ).replace('\t', '').replace('*', '').trim();
			
			if (part == '') {
				if (checks[0] == check) {
					part = check.name;
				}
			}*/
			
			//if (part.startsWith( '*' ) ) part = part.substr( 1 ).trim();
			
			if (checks[0] == check) {
				
				if (cls.meta.has(':usage')) {
					
					docs.push( 'Usage:\n' );
					
					for (param in cls.meta.get().get(':usage').params) {
						
						docs.push( '\t' + param.printExpr().replace('"', '').replace('\\n', '\n').replace('\\t', '\t') + '\n' );
						
					}
					
				}
				
				docs.push( '\nOptions :\n' );
				
			} else {
				
				var aliases = check.meta.get( 'alias' );
				
				part = '--${check.name}\t$part';
				
				if (aliases != null) for (alias in aliases.params) {
					
					part = '-' + alias.printExpr().replace('"', '') + ', $part';
					
				}
				
				var desc = check.doc.replace('\n', '').replace('\r', '').replace('\t', '').replace('*', '').replace('  ', ' ').trim();
				var counter = 0, length = 0;
				
				while (length < desc.length) {
					if (counter == 66) {
						counter = 0;
						var index = 66;
						if (desc.charCodeAt( index ) != ' '.code) {
							// rewind until we find a space.
							while (true) {
								index--;
								if (desc.charCodeAt( index ) == ' '.code) break;
							}
						}
						desc = desc.substring(0, index) + '\n\t' + desc.substring(index+1, desc.length);
					}
					counter++;
					length++;
					
				}
				
				docs.push( '\t$part' + '\n' + (desc != null && desc != '' ? '\t$desc\n\n' : '') );
				
			}
			
		}
		
		var expr = Context.defined('sys') ? macro Sys.print( $v { docs.join( '' ) } ) : macro trace( $v { docs.join( '' ) } );
		fields.get( 'help' ).body( macro { $expr; } );
		
		var nexprs:Array<Expr> = [];
		
		
		// If the `:usage` metadata exists on the class and it has haxelib
		// in the string value, assume its a haxelib run module and remove
		// the last arg which is the directory the command was called from.
		var haxelib = if (cls.meta.has(':usage') && cls.meta.get().get(':usage').params.printExprs('').indexOf('haxelib') > -1) {
			macro _argCopy.pop();
		} else {
			macro null;
		}
		
		// Turn all the expressions in `typecasts` into a block of code.
		var block = macro @:mergeBlock $b { typecasts };
		
		// Expressions to be put before everything else already in the constructor.
		nexprs.push( macro @:mergeBlock {
			var _argCopy = args.copy();
			$haxelib;
			var _cmd:uhx.sys.Lod = new uhx.sys.Lod( _argCopy );
			var _map = _cmd.parse();
			$block;
			/*var _line:uhx.sys.Liy = new uhx.sys.Liy(
				this, [$a { instances } ], _map,
				haxe.rtti.Meta.getFields( $i { cls.name } )
			);
			_line.parse();*/
		} );
		
		var method = _new.getMethod();
		
		switch (method.expr.expr) {
			case EBlock( es ):
				_new.body( { expr: EBlock( nexprs.concat( es ) ), pos: _new.pos } );
				
			case _:
		}
		trace( [for (f in fields) f.printField()].join('\n') );
		return fields;
	}
	
}