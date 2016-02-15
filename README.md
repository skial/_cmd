Cmd
=====

A set of classes which help create command line applications.

## Install

`haxelib git cmd https://github.com/skial/cmd.git`

And add `-lib cmd` to your `hxml` file.
	
## Usage

You have the following classes available:
	
+ Lod parses the command line parameters.
+ Liy maps Lod's output to a class's fields at runtime using reflection.
+ Ede is a build macro which simplifies the creation of command line applications by using
metadata.
+ Extending Ioe attempts to simplify working with stdin, stdout and stderr.

The recommended way of using this library is through Ede, either with [Klas](https://github.com/skial/klas/) or not.

#### With Klas

```Haxe
package ;

@:cmd
class Main {
	
	// Your name.
	@alias('n')
	@:isVar public var name(get, default):String;
	
	// Your age.
	@alias('a')
	public var age:Int = 25;
	
	private var originalArgs:Array<String>;
	
	public function new(args:Array<String>) {
		trace( name, age );
		originalArgs = args;
	}
	
	private function get_name():String return name.toLowerCase();
	
}
```

#### Without Klas

```Haxe
package ;

@:cmd
@:autoBuild( uhx.sys.Ede.build() )
class Main {
	
	// Your name.
	@alias('n')
	@:isVar public var name(get, default):String;
	
	// Your age.
	@alias('a')
	public var age:Int = 25;
	
	private var originalArgs:Array<String>;
	
	public function new(args:Array<String>) {
		trace( name, age );
		originalArgs = args;
	}
	
	private function get_name():String return name.toLowerCase();
	
}
```

## Details

### Auto Documenting

Ede will use your field code comments to populate the auto-generated `help`
message.

### Subcommands

To create a subcommand, create a class whose constructor accepts a `args:StringMap<Array<Dynamic>>`,
usually as its first argument. The subcommand class must also have the `@:cmd` metadata.

 - Subcommands are dashless in both their long and short forms, _i.e_, they don't start with either `--` or `-`.
 - Ede will only process a subcommand if it's the first argument passed in.
  + This will work: `mytool sub -a 1 -b 2 -c 3`.
  + This **won't** work: `mytool -a 1 sub -b 2 -c 3`, _because `Lod` which parses the arguments_, reads `-a 1 sub` as `-a` having two values, `['1', 'sub']`.
 - Ede will pass all arguments to your subcommand to process.

If your subcommand class takes more than one argument, your
field declaration, e.g, `public var sub:Class;` needs to 
provide Ede with a _template_ expression to work with.

A simple example is `public var sub:Class = Class.new.bind(_, 'value', 256, var1, var2);`.

- The underscore, `_`, is the position of the `args:StringMap<Array<Dynamic>>` argument.
- `'value'` and `256` are constant values.
- `var1` and `var2` are variables and **must** be accessible from the constructor, if not, you will get compiler errors.

Ede will remove the _template_ expression, `Class.new.bind(_, 'value', 256, var1, var);`, as it will cause a compiler error
if its not removed. Ede uses this _template_ expression
instead of the default `new Class(_map)` expression it would 
normally use.

*Sidenote: `_map` is an internal variable created by Ede, used while processing command arguments.*

### Auto Help

Ede auto-generates a `help` method, with the following two
aliases, `-?` and `-h`. Ede builds the message passed on:

 - Your public fields documentation.
 - Your public fields names and their aliases.

### Available Metadata

#### `@:cmd`

Add `@:cmd` to your class to tell Ede to help turn the class into a
command line application.

#### `@:usage`

Add `@:usage('tool --output ./bin --process *.jpg')` to provide detailed
information, which gets included in the auto-generated `help` method, built
by Ede.

#### `@alias`

Add `@alias('v')` to your field to provide an alternative _short form_ name.

- Notice it is a runtime metadata, it doesn't contain `:`. Defining `@:alias` will not work.
- You can define multiple values, e.g, `@alias('a','b', 'c')`.
- The alias can be any length, e.g, `@alias('supercalifragilisticexpialidocious')`

#### `@:cmd _`

Add the `@:cmd _` meta expression into your constructor body to control
the insertion point Ede will place the command line argument processing.
By default, Ede will place it before all other code in your constructor.

#### `@:skip(cmd)`

Add `@:skip(cmd)` to your public fields for which you don't want Ede to include
in the auto-generated `help` message.


### Hxml Defines

If you're using the build macro `Ede` and are building a haxelib `run` command,
add `-D haxelib` to your `hxml` file so Ede removes the directory that haxelib
adds as a last argument.

## Tests

You can find Cmd tests in the [uhu-spec](https://github.com/skial/uhu-spec/blob/master/src/uhx/sys/) library.
