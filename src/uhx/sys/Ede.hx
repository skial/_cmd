package uhx.sys;

import haxe.macro.ComplexTypeTools;
import haxe.macro.Printer;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Compiler;

#if klas
import uhx.macro.KlasImp;
#end

using Lambda;
using StringTools;
using haxe.macro.Tools;

/**
 * ...
 * @author Skial Bainn
 * ede => Help in Haitian Creole 
 */
class Ede {
	
	public static macro function initialize():Void {
		try {
			#if klas
			KlasImp.initialize();
			KlasImp.classMetadata.add(':cmd', Ede.handler);
			#end
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
		
		var _new:Field = fields.filter( function(f) return f.name == 'new' )[0];
		
		if (_new == null) {
			throw 'Only class instances are supported';
		}
		
		var isSubcommand:Bool = false;
		
		switch (_new.kind) { 
			case FFun( { args:args } ) if (args.filter( function(arg) return arg.name == 'args').length == 0):
				Context.error( 'Field `new` must have a parameter named `args` of type `Array<String>`', _new.pos );
				
			case FFun( { args:args } ):
				for (arg in args) if (arg.name == 'args') {
					isSubcommand = Context.unify(arg.type.toType(), (macro:haxe.ds.StringMap<Array<Dynamic>>).toType());
					if (isSubcommand) break;
					
				}
				
			case _:
				
		}
		
		// Add commandline help methods if they dont exist.
		fields.push( {
			name:'help',
			access: [APublic],
			kind: FFun( {
				args: [],
				ret: null,
				expr: macro { }
			} ),
			pos: Context.currentPos(),
			doc: 'Show this message.',
				meta: [ { name:'alias', params:[macro 'h', macro '?'], pos:Context.currentPos() } ],
		} );
		
		// An array of expressions which cast the argument to the fields type.
		var typecasts:Array<Expr> = [];
		
		for (field in fields) if (!field.access.has( APrivate ) && !field.access.has( AStatic )) {
			
			switch (field.kind) {
				case FVar(t, e), FProp(_, _, t, e):
					var aliases = [macro $v { field.name } ];
					var isFieldSubcommand = t.toType().match( TInst(_.get().meta.has( ':cmd' ) => true, _) );
					if (isFieldSubcommand) field.meta.push( { name:':subcommand', params:[], pos:field.pos } );
					
					for (m in field.meta) if (m.name == 'alias') aliases = aliases.concat( m.params );
					
					var e = if (isFieldSubcommand) {
						function resolveTPath(t:ComplexType) return switch (t) {
							case TPath(p): p;
							case _: null;
							
						}
						var tp = resolveTPath(t);
						
						var res = if (e != null) {
							macro $e(_map);
							
						} else {
							macro new $tp(_map);
							
						}
						
						if (e != null) switch (field.kind) {
							case FVar(t, e): field.kind = FVar(t, null);
							case FProp(g, s, t, e): field.kind = FProp(g, s, t, null);
							case _:
						}
						
						res;
					} else if (aliases.length > 1) {
						macro (_map.get( name )[0]:String);
					} else {
						macro (_map.get( $v { field.name } )[0]:String);
					}
					
					// Bool values do not require a value eg `cmd -v` means v is true.
					e = switch (t) {
						case TPath( { name:'Array', pack:_, params:_, sub:_ } ):
							macro cast _map.get( name );
							
						case TPath( { name:'Bool', pack:_, params:_, sub:_ } ):
							macro ($e == null) ? true : $ { Jete.coerce(t, e) };
							
						case _:
							macro $ { Jete.coerce(t, e) };
							
					}
					
					typecasts.push( 
						if (isFieldSubcommand) {
							aliases.length > 1 
							? macro for (name in [$a { aliases } ]) {
									if (_map.exists( 'argv' ) && _map.get( 'argv' ).indexOf( name ) > -1) { 
										$p{['this', field.name]} = $e;
										break;
									}
								} 
							: macro if (_map.exists( 'argv' ) && _map.get( 'argv' ).indexOf( $v { field.name } ) > -1) {
								$p{['this', field.name]} = $e;
							}
							
						} else {
							aliases.length > 1 
							? macro for (name in [$a { aliases } ]) {
									if (_map.exists( name )) { 
										$p{['this', field.name]} = $e;
										break;
									}
								} 
							: macro if (_map.exists( $v { field.name } )) {
								$p{['this', field.name]} = $e;
							}
							
						}
					);
					
				case FFun(m):
					
					if (field.name != 'new' && field.access.indexOf( AStatic ) == -1) {
						
						if (field.meta == null) field.meta = [];
						
						// Separate out required and optional args.
						var required = m.args.filter( function(a) return a.opt == null || a.opt == false );
						var optional = m.args.filter( function(a) return a.opt != null && a.opt == true );
						
						field.meta.push( { name:'arity', pos:field.pos, params:[macro $v { required.length } ] } );
						if (optional.length > 0) field.meta.push( { name:'optional_arity', pos:field.pos, params:[macro $v { optional.length } ] } );
						
						var aliases = [macro $v { field.name } ];
						for (m in field.meta) if (m.name == 'alias') aliases = aliases.concat( m.params );
						
						var argcasts:Array<Expr> = [];
						
						for (i in 0...required.length) {
							argcasts.push( macro $e { Jete.coerce( required[i].type, macro _args[$v { i } ] ) } );
						}
						
						var block = function(name:Expr) return if (required.length > 0 || optional.length > 0) {
							macro {
								var _args = _map.get( $name );
								
								$e{required.length > 0 ? macro @:mergeBlock {
									if (_args.length < $v { required.length }) {
										throw '' + ($name == $v { field.name } ?$v { '--' + field.name } :'-' + $name) + $v { ' expects ' + required.length + ' arg' + (required.length > 1 ? 's' : '') + '.' };
										
									}
								}: macro @:mergeBlock {} }
								
								if (_args.length > $v { (required.length + optional.length)-1 } ) {
									$p { ['this', field.name] } ($a { argcasts.concat( [for (i in 0...optional.length) macro $e { Jete.coerce(optional[i].type, macro _args[$v { required.length + i } ]) } ]) } );
									
								} else {
									$p { ['this', field.name] } ($a { argcasts } );
									
								}
							}
							
						} else {
							macro $p { ['this', field.name] } ();
							
						}
						
						typecasts.push(
							if (aliases.length == 1) {
								macro if (_map.exists( $e { aliases[0] } )) $e { block(aliases[0]) };
								
							} else {
								macro for (name in [$a { aliases } ]) {
									if (_map.exists( name )) {
										$e { block(macro name) };
										break;
									}
								}
								
							}
						);
						
					}
			}
			
		}
		
		function hasSkipCmd(m:Null<Metadata>):Bool {
			var filtered = [for (n in m) if (n.name == ':skip' && n.params.filter(function(p) return p.expr.match(EConst(CIdent('cmd')))).length > -1) n];
			return filtered.length > 0;
		}
		// Get all doc info.
		var checks:Array<{doc:Null<String>, meta:Metadata, name:String}> = [ 
			for (f in fields) 
				if (!f.access.has( APrivate ) && !f.access.has( AStatic ) && f.name != 'new'  && !hasSkipCmd(f.meta)) 
					f 
		];
		checks.unshift( cast cls );
		
		var docs:Array<String> = [];
		
		for (check in checks) {
			var part = '';
			if (check.doc == null) check.doc = '';
			
			if (checks[0] == check) {
				
				if (cls.meta.has(':usage')) {
					
					docs.push( 'Usage:\n' );
					
					for (meta in cls.meta.get().filter( function(m) return m.name == ':usage' )) for (param in meta.params) {
						
						docs.push( '\t' + KlasImp.printer.printExpr( param ).replace('"', '').replace("'", '').replace('\\n', '\n').replace('\\t', '\t') + '\n' );
						
					}
					
				}
				
				docs.push( '\nOptions :\n' );
				
			} else {
				
				var aliases = check.meta.filter( function(m) return m.name == 'alias' );
				var isSubcommand = check.meta.filter( function(m) return m.name == ':subcommand' ).length > 0;
				
				part = (!isSubcommand?'--':'') + '${check.name}\t$part';
				
				if (aliases != null) for (alias in aliases) for(param in alias.params) {
					
					part = '-' + KlasImp.printer.printExpr( param ).replace('"', '').replace("'", '') + ', $part';
					
				}
				
				var desc = check.doc.replace('\\n', '').replace('\\r', '').replace('\\t', '').replace('*', '').replace('  ', ' ').trim();
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
				
				docs.push( '\t$part' + (desc != null && desc != '' ? '\t$desc' : '') + '\n' );
				
			}
			
		}
		
		var expr = Context.defined('sys') ? macro @:mergeBlock { Sys.print( $v { docs.join( '' ) } ); Sys.exit(0); } : macro trace( $v { docs.join( '' ) } );
		switch (fields.filter( function(f) return f.name == 'help' )[0].kind) {
			case FFun(m): m.expr = macro { $expr; };
			case _:
		}
		
		var nexprs:Array<Expr> = [];
		
		// If the `:usage` metadata exists on the class and it has haxelib
		// in the string value, assume its a haxelib run module and remove
		// the last arg which is the directory the command was called from.
		var haxelib = if (cls.meta.has(':usage') && KlasImp.printer.printExprs( cls.meta.get().filter( function(m) return m.name == ':usage')[0].params, '' ).indexOf('haxelib') > -1) {
			macro _argCopy.pop();
		} else {
			macro @:mergeBlock {};
		}
		
		// Turn all the expressions in `typecasts` into a block of code.
		var block = macro @:mergeBlock $b { typecasts };
		
		// Expressions to be put before everything else already in the constructor.
		if (!isSubcommand) {
			nexprs.push( macro @:mergeBlock {
				var _argCopy = args.copy();
				#if haxelib
				$haxelib;
				#end
				var _cmd:uhx.sys.Lod = new uhx.sys.Lod( _argCopy );
				var _map = _cmd.parse();
				$block;
			} );
			
		} else {
			nexprs.push( macro @:mergeBlock {
				#if haxelib
				$haxelib;
				#end
				var _map = args;
				$block;
			} );
			
		}
		
		switch (_new.kind) {
			case FFun(m):
				var index = -1;
				var exprs = [];
				switch (m.expr.expr) {
					case EBlock(es):
						exprs = es;
						for (i in 0...es.length) switch (es[i]) {
							case { expr:EMeta( { name:':cmd' }, _) } :
								index = i;
								break;
								
							case _:
								
						}
						
					case _:
						
				}
				if (index == -1) {
					m.expr = macro $b { nexprs.concat(exprs) };
				} else {
					m.expr = macro $b { exprs.slice(0, index).concat( nexprs ).concat( exprs.slice(index + 1) ) };
				}
				
			case _:
				
				
		}
		
		trace( [for (f in fields) KlasImp.printer.printField( f )].join('\n') );
		return fields;
	}
	
}