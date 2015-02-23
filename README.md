Cmd
=====

A set of classes which help create command line applications.

## Install

`haxelib git cmd https://github.com/skial/cmd.git`

And add `-lib cmd` to your `hxml` file.
	
## Usage

You have the following classes available:
	
+ Lod parses the command line parameters.
+ Liy maps Lod's output to a classes fields at runtime using reflection.
+ Ede is a build macro which simplifies the creation of command line applications by using
metadata.
+ Extending Ioe attempts to simplify working with stdin, stdout and stderr.

The recommended way of using this library is through Ede, either with [Klas](https://github.com/skial/klas/) or not.

#### With Klas

```
package ;

@:cmd
class Main implements Klas {
	
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

```
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

## Explanation

Using the meta `@:cmd` attached to the class you are telling the build
macro to map all `public` fields to any command line argument.

Using the runtime meta tag `@alias` allows you to specify a short
command line argument to match against.

Short form arguments, _(alias)_, start with a single dash `-`.
Long form arguments start with double dash `--`.

Code comments are automatically used in the auto generated help method,
which has an alias of `-?`.

Ede, the build macro, will insert argument parsing code in the constructor
before any other code. To change the insertion point use `@:cmd _`.

## Notes

If your using the build macro `Ede` and are building a haxelib `run` command,
add `-D haxelib` to your `hxml` file so Ede removes the directory that haxelib
adds as a last argument.

## Tests

You can find Cmd tests in the [uhu-spec](https://github.com/skial/uhu-spec/blob/master/src/uhx/sys/) library.