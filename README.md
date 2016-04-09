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

### `edeProcessArgs`

Ede will add an instance method to your class, named `edeProcessArgs`, that takes
a single argument of type `Array<String>`. By default, `edeProcessArgs` is inserted
at the top of your constructor, before all other code. See details for 
[`@:cmd _`](#cmd-_-and-cmd-_) to control where `edeProcessArgs` is inserted.

### Auto Help

Ede will use your code comments to populate the auto-generated `help`
message. The auto-generated `help` method, has the following two
aliases, `-?` and `-h`. Ede builds the message passed on:

 - Your public fields documentation.
 - Your public fields names and their aliases.

### Subcommands

A subcommand is just a normal class marked with `@:cmd`.

 - Subcommands are dashless in both their long and short forms, _i.e_, they don't start with either `--` or `-`.
 - Ede will only process a subcommand if it's the first argument passed in.
  + This will work: `mytool sub -a 1 -b 2 -c 3`.
  + This **won't** work: `mytool -a 1 sub -b 2 -c 3`, _because `Lod`, which parses the arguments_, reads `-a 1 sub` as `-a` having two values, `['1', 'sub']`.
 - Ede will pass all arguments to your subcommand to process.

If your subcommand class takes more than one argument, your
field declaration, e.g, `public var sub:Class;` needs to 
provide Ede with a _template_ expression to work with.

A simple example is `public var sub:Class = Class.new.bind(_, 'value', 256, var1, var2);`.

- The underscore, `_`, is the position of the `args:Array<String>` argument.
- `'value'` and `256` are constant values.
- `var1` and `var2` are variables and **must** be accessible from `edeProcessArgs`, if not, you will get compiler errors.

Ede will remove the _template_ expression, `Class.new.bind(_, 'value', 256, var1, var);`, as it would cause a compiler error
if not removed. Ede uses this _template_ expression
instead of the default `new Class(args)` expression it would 
normally use.

### Available Metadata

#### Class level metadata

##### `@:cmd`

Add `@:cmd` to your class to tell Ede to turn the class into a
command line application.

##### `@:usage`

Add `@:usage('tool --output ./bin --process *.jpg')` to provide detailed
information, which gets included in the auto-generated `help` method, built
by Ede.

If the `@:usage` string includes the word `haxelib`, Ede will act as if
[`-D haxelib`](#hxml-defines) was defined in your `hxml` file.

#### Field level metadata

##### `@alias`

Add `@alias('v')` to your field to provide an alternative _short form_ name.

- Notice it is a runtime metadata, it doesn't contain `:`. Defining `@:alias` will not work.
- You can define multiple values, e.g, `@alias('a','b', 'c')`.
- The alias can be any length, e.g, `@alias('supercalifragilisticexpialidocious')`

##### `@:skip(cmd)`

Add `@:skip(cmd)` to your public fields for which you don't want Ede to include
in the auto-generated `help` message.

##### `@:native('value')`

Add `@:native('value')` to your field to match against `value` instead of the
variables/methods original name.

#### Expression level metadata

##### `@:cmd _` and `@:cmd !_`

- Without `@:cmd`, by default, `edeProcessArgs` is inserted at the top of your constructor.
- Use `@:cmd _` to specify the exact point `edeProcessArgs` should be inserted.

	```Haxe
	public function new(args:Array<String>) {
		var a = 'foo';
		var b = 100;
		@:cmd _;	//	`edeProcessArgs( args )` will be inserted at this point.
		var c = '$a$b';
	}
	``` 
- Use `@:cmd !_` to tell Ede **not** to insert `edeProcessArgs` at all.
	
	```Haxe
	public function new(args:Array<String>) {
		var a = 'foo';
		var b = 100;
		@:cmd !_;	//	`edeProcessArgs` will not be inserted into the constructor at all.
		var c = '$a$b';
	}
	``` 

### Hxml Defines

If you're using the build macro `Ede` and are building a haxelib `run` command,
add `-D haxelib` to your `hxml` file so Ede removes the directory that haxelib
adds as a last argument.

## Tests

You can find Cmd tests in the [uhu-spec](https://github.com/skial/uhu-spec/blob/master/src/uhx/sys/) library.
