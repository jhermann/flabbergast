namespace Flabbergast {
	public class File : GTeonoma.SourceInfo, Object {
		public GTeonoma.source_location source {
			get;
			set;
		}
		public Gee.List<Expressions.Attribute> attributes {
			get;
			set;
		}
		public Data.Frame evaluate (ExecutionEngine engine) throws EvaluationError {
			var context = engine.environment.create ();
			var frame = new Data.Frame (context);
			frame.source = source;

			var state = engine.state;
			state.context = context;
			state.this_frame = frame;
			state.containers = new Utils.ContainerReference (context, null);
			engine.state = state;

			foreach (var attribute in attributes) {
				if (frame.attributes.has_key (attribute.name.name)) {
					throw new EvaluationError.NAME (@"Duplicate attribute name $(attribute.name.name). $(attribute.source.source):$(attribute.source.line):$(attribute.source.offset)");
				}
				var attr_value = engine.create_closure (attribute.expression);
				frame.attributes[attribute.name.name] = attr_value;
				engine.environment[context, attribute.name.name] = attr_value;
			}
			return frame;
		}
		public void transform () {
			foreach (var attribute in attributes) {
				attribute.expression = attribute.expression.transform ();
			}
		}
		public class Import : Expression {
			public Name name {
				get;
				set;
			}
			public UriReference uri {
				get;
				set;
			}
			public override void evaluate (ExecutionEngine engine) throws EvaluationError {
				engine.operands.push (engine.get_import (uri.path));
			}
			public override Expression transform () {
				return this;
			}
		}
		public class UriReference : Object {
			public string path {
				get;
				private set;
			}
			public UriReference (string path) {
				this.path = path;
			}
		}
	}
}
