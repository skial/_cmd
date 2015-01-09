package uhx.sys;

/**
 * ...
 * @author Skial Bainn
 */
@:enum abstract ExitCode(Int) from Int to Int {
	var SUCCESS = 0;
	var WARNINGS = 1;
	var ERRORS = 2;
}