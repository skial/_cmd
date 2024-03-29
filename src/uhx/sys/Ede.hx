package uhx.sys;

#if macro
import haxe.ds.ArraySort;
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
using haxe.macro.Context;
#end

/**
 * ...
 * @author Skial Bainn
 * ede => Help in Haitian Creole 
 */
class Ede {
	
	#if !macro
	public static function argumentFilter(args:Array<String>, filter:Array<String>):Array<String> {
		var skip:Bool = false;
		return [for (arg in args) {
			if (skip && StringTools.startsWith( arg, '-' )) {
				skip = false;
				arg;
				
			} else if (filter.indexOf( arg ) == -1) {
				arg;
				
			} else {
				skip = true;
				continue;
				
			}
		}];
	}
	
	#else
	
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
				
			case _:
				
		}
		
		function displayName(metas:Metadata, def:String):String {
			var result = def;
			var natives = metas.filter( function(m) return m.name == ':native' && m.params.length > 0 );
			
			if (natives.length > 0) switch (natives[0].params[0].expr) {
				case EConst(CString(v)): result = v;
				case _:
			}
			
			return result;
		}
		
		function extendsCommand(parent:ClassType):Bool {
			var result = false;
			
			if (!parent.meta.has(':cmd') && parent.superClass != null) {
				result = extendsCommand( parent.superClass.t.get() );
				
			} else {
				result = parent.meta.has(':cmd');
				
			}
			
			return result;
		}
		
		function superAliases(parent:ClassType, name:String):Array<Expr> {
			var results = [];
			
			for (field in parent.fields.get()) if (field.name == name) {
				for (m in field.meta.get()) if (m.name == 'alias') {
					results = results.concat( m.params );
					
				}
				
			}
			
			if (parent.superClass != null) results = results.concat( superAliases( parent.superClass.t.get(), name ) );
			
			return results;
		}
		
		function aliasRemoval(aliases:Array<Expr>, ?isFieldOverride:Bool = false):Expr {
			var mapped = [];
			for (i in 0...aliases.length) {
				if (i == 0) { 
					mapped.push( switch (aliases[i].expr) {
						case EConst(CString(v)): macro $v{'--$v'};
						case _: aliases[i];
					} );
					
				} else {
					mapped.push( switch (aliases[i].expr) {
						case EConst(CString(v)): macro $v{'-$v'};
						case _: aliases[i];
					} );
					
				}
				
			}
			
			return if (isFieldOverride) {
				macro _argCopy = uhx.sys.Ede.argumentFilter( _argCopy, [$a{mapped}] );
				
			} else {
				macro @:mergeBlock {};
			}
		}
		
		var inheritsCommand:Bool = cls.superClass != null ? extendsCommand( cls.superClass.t.get() ) : false;
		var helpAccess = [APublic];
		if (inheritsCommand) helpAccess.push( AOverride );
		// Add commandline help methods if they dont exist.
		fields.push( {
			name:'help',
			access: helpAccess,
			kind: FFun( {
				args: [],
				ret: null,
				expr: macro { }
			} ),
			pos: Context.currentPos(),
			doc: 'Show this message.',
			meta: [ { name:'alias', params:[macro 'h', macro '?'], pos:Context.currentPos() } ],
		} );
		
		var edeProcessArgsAccess = [APrivate];
		if (inheritsCommand) edeProcessArgsAccess.push( AOverride );
		
		var edeProcessArgsBody = {
			args: [{ name:'args', type:macro:Array<String> }],
			ret: null,
			expr: macro { }
		};
		var edeProcessArgsField = {
			name:'edeProcessArgs',
			access: edeProcessArgsAccess,
			kind: FFun( edeProcessArgsBody ),
			pos: Context.currentPos(),
			doc: 'Show this message.',
			meta: [ { name:':skip', params:[], pos:Context.currentPos() } ],
		}
		
		// An array of expressions which cast the argument to the fields type.
		var typecasts:Array<Expr> = [];
		
		for (field in fields) if (!field.access.has( APrivate ) && !field.access.has( AStatic )) {
			
			switch (field.kind) {
				case FVar(t, e), FProp(_, _, t, e):
					var name = displayName( field.meta, field.name );
					var env = [];
					var aliases = [macro $v { name } ];
					var isFieldOverride = field.access.indexOf( AOverride ) > -1;
					var isFieldSubcommand = t.toType().match( TInst(_.get().meta.has( ':cmd' ) => true, _) );
					
					if (cls.superClass != null && isFieldOverride) aliases = aliases.concat( superAliases( cls.superClass.t.get(), field.name ) );
					if (isFieldSubcommand) field.meta.push( { name:':subcommand', params:[], pos:field.pos } );
					
					for (m in field.meta) switch m.name {
						case 'alias':
							if (m.params.length > 0) {
								for (p in m.params) aliases.push(p);
								
							} else  {
								aliases.push( macro $v{ field.name.charAt(0) } );
								m.params.push( macro $v{ field.name.charAt(0) } );
								
							}
							
						case ':env' if (Context.defined('sys')):
							if (m.params.length > 0) {
								for (p in m.params) env.push(p);
							} else {
								env.push(macro $v{'${cls.name}_${field.name}'.toUpperCase()});
								m.params.push(macro $v{'${cls.name}_${field.name}'.toUpperCase()});
								
							} 
							
						case _:
							
					}
					
					function coerce(expr:Null<Expr>, ct:ComplexType, isSub:Bool, field:Field, access:Void->Expr, values:Array<Expr>):Expr {
						var result = expr;
						
						// First build expression based on `isSub` or `values` length.
						if (isSub) {
							var tp = switch ct {
								case TPath(p): p;
								case _: null;
							}
							if (expr != null) {
								result = macro $expr(args);
								
							} else {
								result = macro new $tp(args);
								
							}
							
							if (expr != null) switch (field.kind) {
								case FVar(t, e): field.kind = FVar(t, null);
								case FProp(g, s, t, e): field.kind = FProp(g, s, t, null);
								case _:
							}
							
						} else {
							result = access();
							
						}
						
						// Then adapt the expression based on the complex type.
						switch ct {
							case TPath( { name:'Array', pack:_, params:_, sub:_ } ):
								result = macro cast $e{access()};
								
							// Bool values do not require a value, eg `cmd -v` means v is true.
							case TPath( { name:'Bool', pack:_, params:_, sub:_ } ):
								result = macro ($result == null) ? true : $ { Jete.coerce(t, result) };
								
							case _:
								result = macro $ { Jete.coerce(t, result) };
						}
						
						return result;
					}
					
					var coerced = coerce(e, t, isFieldSubcommand, field, function() {
						var ident = aliases.length > 0 ? macro name : macro $v{field.name};
						return macro (_map.get($ident)[0]:String);
					}, aliases);
					
					// Used to record if a the field was set.
					// TODO convert to function, takes a single expr and returns
					// `_isFieldSet = $expr` or `@:empty $expr` based on `env.length`.
					// Might produce better output.
					var isFieldSet = macro $i{'_isFieldSet'};
					var envCheck = if (Context.defined('sys') && env.length > 0) macro {
						for (name in $a{env}) if (_env.exists(name)) {
							$p{['this', field.name]} = ${coerce(e, t, isFieldSubcommand, field, function() {
								var ident = aliases.length > 0 ? macro name : macro $v{field.name};
								return macro ([_env.get($ident)][0]:String);
							}, env)};
							break;
						}
						
					} else macro {};
					
					typecasts.push( 
						if (isFieldSubcommand) {
							aliases.length > 1 
							? macro @:mergeBlock {
									for (name in [$a { aliases } ]) {
										if ($isFieldSet = (_map.exists( 'argv' ) && _map.get( 'argv' ).indexOf( name ) > -1)) { 
											$p{['this', field.name]} = $coerced;
											break;
										}
									}
									$e{(Context.defined('sys') && env.length > 0) ? (macro if (!$isFieldSet) $envCheck) : (macro @:mergeBlock {})};
								} 
							: macro if (_map.exists( 'argv' ) && _map.get( 'argv' ).indexOf( $v { name } ) > -1) {
								$p{['this', field.name]} = $coerced;
							} else $envCheck;
							
						} else {
							aliases.length > 1 
							? macro @:mergeBlock {
									for (name in [$a { aliases } ]) {
										if ($isFieldSet = _map.exists( name )) { 
											$p{['this', field.name]} = $coerced;
											break;
										}
									}
									$e{(Context.defined('sys') && env.length > 0) ? macro if (!$isFieldSet) $envCheck : macro @:mergeBlock {}};
								}
							: macro if (_map.exists( $v { name } )) {
								$p{['this', field.name]} = $coerced;
							} else $envCheck;
							
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
						
						var env = [];
						var aliases = [macro $v { field.name } ];
						var isFieldOverride = field.access.indexOf( AOverride ) > -1;
						
						for (m in field.meta) switch m.name {
							case 'alias':
								if (m.params.length > 0) {
									for (p in m.params) aliases.push(p);
									
								} else  {
									aliases.push( macro $v{ field.name.charAt(0) } );
									m.params.push( macro $v{ field.name.charAt(0) } );
									
								}
								
							case ':env':
								m.params.length > 0 ? for (p in m.params) env.push(p) : env.push(macro $v{'${cls.name}_${field.name}'.toUpperCase()});
								
							case _:
								
						}
						
						if (cls.superClass != null && isFieldOverride) {
							var inheritedAliases = superAliases( cls.superClass.t.get(), field.name );
							// Add `inheritedAliases` names to new field
							if (field.meta.filter( function(m) return m.name == 'alias' ).length == 0) {
								field.meta.push( { name:'alias', params:inheritedAliases, pos:field.pos } );
								
							} else {
								var alias = field.meta.filter( function(m) return m.name == 'alias' )[0];
								var printed = alias.params.map( KlasImp.printer.printExpr );
								
								for (inheritedAlias in inheritedAliases) if (printed.indexOf( KlasImp.printer.printExpr( inheritedAlias ) ) == -1) {
										alias.params.push( inheritedAlias );
									
								}
								
							}
							
							aliases = aliases.concat( inheritedAliases );
							
						}
						
						var argcasts:Array<Expr> = [];
						
						for (i in 0...required.length) {
							argcasts.push( macro $e { Jete.coerce( required[i].type, macro _args[$v { i } ] ) } );
						}
						
						function block(name:Expr) return if (required.length > 0 || optional.length > 0) {
							macro {
								var _args = _map.get( $name );
								
								$e{
									required.length > 0 ? macro @:mergeBlock {
										if (_args.length < $v { required.length }) {
											throw '' + ($name == $v { field.name } ?$v { '--' + field.name } :'-' + $name) + $v { ' expects ' + required.length + ' arg' + (required.length > 1 ? 's' : '') + '.' };
											
										}
									}: macro @:mergeBlock {}
								}
								$p { ['this', field.name] } ($a { argcasts } );
								
							}
							
						} else {
							macro $p { ['this', field.name] } ();
							
						}
						
						typecasts.push(
							if (aliases.length == 1) {
								macro if (_map.exists( $e { aliases[0] } )) {
									$e { block(aliases[0]) };
									$e { aliasRemoval(aliases, isFieldOverride) };
								}
								
							} else {
								macro for (name in [$a { aliases } ]) {
									if (_map.exists( name )) {
										$e { block(macro name) };
										$e { aliasRemoval(aliases, isFieldOverride) };
										break;
									}
								}
								
							}
						);
						
					}
			}
			
		}
		
		function hasSkipCmd(m:Null<Metadata>):Bool {
			var filtered = [for (n in m) if (n.name == ':skip' && n.params.filter( function(p) return p.expr.match(EConst(CIdent('cmd'))) ).length > -1) n];
			return filtered.length > 0;
		}
		// Get all doc info.
		var checks:Array<{doc:Null<String>, meta:Metadata, name:String}> = [];
		
		function processParents(parent:ClassType) {
			if (parent.superClass != null) processParents( parent.superClass.t.get() );
			
			for (field in parent.fields.get()) if (field.isPublic && field.name != 'help' && !hasSkipCmd(field.meta.get())) {
				checks.push( { doc:field.doc, meta:field.meta.get(), name:field.name } );
				
			}
			
		}
				
		if (cls.superClass != null) processParents( cls.superClass.t.get() );
		
		// This removes fields that have been overriden.
		for (field in fields) for (i in 0...checks.length) {
			if (checks[i].name == field.name) checks.remove( checks[i] );
		}
		
		checks = checks.concat( [for (f in fields) 
				if (!f.access.has( APrivate ) && !f.access.has( AStatic ) && f.name != 'new'  && !hasSkipCmd(f.meta)) 
					f 
		] );
		
		ArraySort.sort(checks, function(a, b) {
			var c = [for (m in a.meta) if (m.name == ':subcommand') m].length;
			var d = [for (m in b.meta) if (m.name == ':subcommand') m].length;
			return c > 0 && d > 0 ? 0 : c > 0 ? -1 : 1;
		});
		
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
				
				part += (!isSubcommand?'--':'') + '${displayName(check.meta, check.name)}\t$part';
				
				if (aliases != null) for (alias in aliases) for (param in alias.params) {
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
		
		if(Context.defined('sys')) {
			var envs = [];
			for (check in checks) for (meta in check.meta) if (meta.name == ':env') {
				for (param in meta.params) {
					var name = KlasImp.printer.printExpr(param).replace('"', '').replace("'", '');
					var desc = name;
					envs.push( '\t' + desc + '\t\tSee --${displayName(check.meta, check.name)}' );
					
				}
				
			}
			
			if (envs.length > 0) docs.push( '\n\nEnvironment Variables:\n' + envs.join('\n') );
			
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
		
		if ('debug'.defined() && 'cmd-verbose'.defined()) {
			nexprs.push( macro trace( 'Input arguments for ' + $v{cls.pack.toDotPath(cls.name)} + ' => ' + args ) );
			
		}
		
		nexprs.push( macro @:mergeBlock {
			var _argCopy:Array<String> = args.copy();
			#if haxelib
			$haxelib;
			#end
			var _isFieldSet = false;
			var _cmd:uhx.sys.Lod = new uhx.sys.Lod( _argCopy );
			var _env:haxe.ds.StringMap<String> = Sys.environment();
			var _map:haxe.ds.StringMap<Array<Dynamic>> = _cmd.parse();
			$block;
			$e{ (inheritsCommand) ? macro super.edeProcessArgs( _argCopy ) : macro @:mergeBlock {} };
		} );
		
		edeProcessArgsBody.expr = macro $b { nexprs };
		fields.push( edeProcessArgsField );
		
		switch (_new.kind) {
			case FFun(m):
				var include = true;
				var index = -1;
				var exprs = [];
				switch (m.expr.expr) {
					case EBlock(es):
						exprs = es;
						for (i in 0...es.length) switch (es[i]) {
							case { expr:EMeta( { name:':cmd' }, macro !_) } :
								index = i;
								include = false;
								break;
								
							case { expr:EMeta( { name:':cmd' }, _) } :
								index = i;
								break;
								
							case _:
								
						}
						
					case _:
						
				}
				
				if (!include) {
					m.expr = macro $b { exprs.slice(0, index).concat( exprs.slice(index + 1) ) };
					
				} else {
					if (index == -1) {
						m.expr = macro edeProcessArgs( args );
					} else {
						m.expr = macro $b { exprs.slice(0, index).concat( [macro edeProcessArgs( args )] ).concat( exprs.slice(index + 1) ) };
					}
					
				}
			case _:
				
				
		}
		
		if ('debug'.defined() && 'cmd-verbose'.defined()) {
			trace( cls.name );
			trace( [for (f in fields) KlasImp.printer.printField( f )].join('\n') );
			
		}
		
		return fields;
	}
	
	#end
	
}
