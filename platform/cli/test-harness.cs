using Flabbergast;
using System;
using System.Collections.Generic;
using System.IO;

public class DirtyCollector : ErrorCollector {
	public bool Dirty { get; set;}
	public void ReportTypeError(AstNode where, Flabbergast.Type new_type, Flabbergast.Type existing_type) {
		Dirty = true;
	}
	public void ReportTypeError(Flabbergast.Environment environment, string name, Flabbergast.Type new_type, Flabbergast.Type existing_type) {
		Dirty = true;
	}
	public void ReportForbiddenNameAccess(Flabbergast.Environment environment, string name) {
		Dirty = true;
	}
	public void RawError(AstNode where, string message) {
		Dirty = true;
	}
}
public class Compiler {
	public static void Main(string[] args) {
		var uri = new Uri(System.Reflection.Assembly.GetExecutingAssembly().GetName().CodeBase);
		var directory = Path.GetDirectoryName(uri.LocalPath);
		DoTests(Path.Combine(directory, "..", "..", "..", "..", "tests"));
		DoTests(Path.Combine(directory, "..", "..", "tests"));
	}
	public static List<string> GetFiles(string root, string child) {
		var files = new List<string>();
		var path = Path.Combine(root, child);
		if (Directory.Exists(path)) {
			foreach (var file in Directory.GetFiles(path)) {
				if (file.EndsWith(".flbgst")) {
					files.Add(file);
				}
			}
		}
		return files;
	}
	public static void DoTests(string root) {
		if (!Directory.Exists(root)) {
			System.Console.WriteLine("Skipping non-existent directory: " + root);
			return;
		}
		foreach (var file in GetFiles(root, "malformed")) {
			System.Console.Write("malformed: " + Path.GetFileNameWithoutExtension(file) + "... ");
			var parser = Parser.Open(file);
			System.Console.WriteLine(AstNode.ParseFile(parser) == null ? "ok" : "FAIL");
		}
		var collector = new DirtyCollector();
		foreach (var file in GetFiles(root, "errors")) {
			System.Console.Write("errors: " + Path.GetFileNameWithoutExtension(file) + "... ");
			var parser = Parser.Open(file);
			var ast = AstNode.ParseFile(parser);
			var success = true;
			if (ast == null) {
				success = false;
			} else {
				collector.Dirty = false;
				((AstTypeableNode) ast).Analyse(collector);
				success = collector.Dirty;
			}
			System.Console.WriteLine(success ? "ok" : "FAIL");
		}
		foreach (var file in GetFiles(root, "working")) {
			System.Console.Write("working: " + Path.GetFileNameWithoutExtension(file) + "... ");
			var parser = Parser.Open(file);
			var ast = AstNode.ParseFile(parser);
			var success = true;
			if (ast == null) {
				success = false;
			} else {
				collector.Dirty = false;
				((AstTypeableNode) ast).Analyse(collector);
				success = !collector.Dirty;
			}
			System.Console.WriteLine(success ? "ok" : "FAIL");
		}
	}
}
