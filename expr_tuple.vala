namespace Flabbergast.Expressions {
	public abstract class TemplatePart : Object, GTeonoma.SourceInfo {
		public Name name {
			get;
			set;
		}
		public GTeonoma.source_location source { get; set; }
	}
	public abstract class TuplePart : TemplatePart {}
	public class Attribute : TuplePart {
		public Expression expression {
			get;
			set;
		}
	}
	internal class External : TemplatePart {}
	internal class Informative : TemplatePart {}
	internal class Override : TuplePart {
		public Gee.List<TemplatePart> attributes {
			get;
			set;
		}
	}
	internal class Undefine : TuplePart {}

	internal class TupleLiteral : Expression {
		public Gee.List<Attribute> attributes {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			var context = engine.environment.create ();
			var tuple = new Data.Tuple (context);
			tuple.containers = new Utils.ContainerReference (engine.state.context, engine.state.containers);

			var state = engine.state;
			if (state.this_tuple != null) {
				var container_expr = new ReturnLiteral (tuple);
				container_expr.source = source;
				tuple.attributes["Container"] = container_expr;
				engine.environment[context, "Container"] = container_expr;
			}
			state.containers = new Utils.ContainerReference (state.context, state.containers);
			engine.environment.append_containers (context, state.containers);
			state.context = context;
			state.this_tuple = tuple;

			engine.state = state;

			var attr_names = new Gee.HashSet<string> ();
			foreach (var attr in attributes) {
				if (attr.name.name in attr_names) {
					throw new EvaluationError.NAME (@"Duplicate attribute name $(attr.name.name) in literal tuple. $(attr.source.source):$(attr.source.line):$(attr.source.offset)");
				}
				var attr_value = engine.create_closure (attr.expression);
				tuple.attributes[attr.name.name] = attr_value;
				engine.environment[context, attr.name.name] = attr_value;
				attr_names.add (attr.name.name);
			}
			engine.operands.push (tuple);
		}
		public override Expression transform () {
			foreach (var attribute in attributes) {
				attribute.expression = attribute.expression.transform ();
			}
			return this;
		}
	}
	internal class TemplateLiteral : Expression {
		public Gee.List<TemplatePart> attributes {
			get;
			set;
		}
		public Expression? source_expr {
			get;
			internal set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			Data.Template source_data = null;
			if (source_expr != null) {
				engine.call (source_expr);
				var result = engine.operands.pop ();
				if (result is Data.Template) {
					source_data = (Data.Template)result;
				} else {
					throw new EvaluationError.TYPE_MISMATCH ("Template based on expression which is not a template. $(attr.source.source):$(attr.source.line):$(attr.source.offset)");
				}
			}
			var attr_names = new Gee.HashSet<string> ();

			var template = new Data.Template ();
			template.containers = new Utils.ContainerReference (engine.state.context, Utils.ContainerReference.append (engine.state.containers, source_data == null ? null : source_data.containers));
			foreach (var attr in attributes) {
				if (attr is Informative) {
					/* Skip informative attributes. They don't do anything. */
					continue;
				}
				if (attr.name.name in attr_names) {
					throw new EvaluationError.NAME (@"Duplicate attribute name $(attr.name.name) in template definition. $(attr.source.source):$(attr.source.line):$(attr.source.offset)");
				}
				attr_names.add (attr.name.name);
				if (attr is External) {
					template.externals.add (attr.name.name);
				} else if (attr is Override) {
					if (source_data == null) {
						throw new EvaluationError.OVERRIDE (@"Attemping to override without a source template. $(attr.source.source):$(attr.source.line):$(attr.source.offset)");
					}
					if (!source_data.attributes.has_key (attr.name.name)) {
						throw new EvaluationError.OVERRIDE (@"Attempting to override non-existant attribute $(attr.name.name). $(attr.source.source):$(attr.source.line):$(attr.source.offset)");
					}
					var child_override = new TemplateLiteral ();
					child_override.source = attr.source;
					child_override.source_expr = source_data.attributes[attr.name.name];
					child_override.attributes.add_all (((Override) attr).attributes);
					template.attributes[attr.name.name] = child_override;
				} else if (attr is Undefine) {
					/* Do nothing. We've effectively squatted on this attribute name. */
				} else if (attr is Attribute) {
					template.attributes[attr.name.name] = ((Attribute) attr).expression;
				} else {
					assert_not_reached ();
				}
			}
			if (source_data != null) {
				foreach (var entry in source_data.attributes.entries) {
					if (entry.key in attr_names) {
						continue;
					}
					template.attributes[entry.key] = entry.value;
				}
				foreach (var external in source_data.externals) {
					if (external in attr_names) {
						continue;
					}
					template.externals.add (external);
				}
			}
			engine.operands.push (template);
		}
		public override Expression transform () {
			if (source_expr != null) {
				source_expr = source_expr.transform ();
			}
			foreach (var attribute in attributes) {
				if (attribute is Attribute) {
					((Attribute) attribute).expression = ((Attribute) attribute).expression.transform ();
				}
			}
			return this;
		}
	}
	internal class Instantiate : Expression {
		public Gee.List<TuplePart> attributes {
			get;
			set;
		}
		public Expression source_expr {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.call (source_expr);
			var result = engine.operands.pop ();
			if (!(result is Data.Template)) {
				throw new EvaluationError.TYPE_MISMATCH ("Attempting to instantiate something which is not a template. $(attr.source.source):$(attr.source.line):$(attr.source.offset)");
			}

			var template = (Data.Template)result;
			var context = engine.environment.create ();
			var tuple = new Data.Tuple (context);
			tuple.containers = new Utils.ContainerReference (engine.state.context, Utils.ContainerReference.append (engine.state.containers, template.containers));

			var state = engine.state;
			if (state.this_tuple != null) {
				var container_expr = new ReturnLiteral (tuple);
				tuple.attributes["Container"] = container_expr;
				engine.environment[context, "Container"] = container_expr;
			}
			state.containers = new Utils.ContainerReference (state.context, state.containers);
			engine.environment.append_containers (context, state.containers);
			engine.environment.append_containers (context, template.containers);
			state.context = context;
			state.this_tuple = tuple;

			engine.state = state;

			var attr_names = new Gee.HashSet<string> ();
			foreach (var attr in attributes) {
				if (attr.name.name in attr_names) {
					throw new EvaluationError.NAME (@"Duplicate attribute name $(attr.name.name) in instantiation. $(attr.source.source):$(attr.source.line):$(attr.source.offset)");
				}
				attr_names.add (attr.name.name);
				if (attr is Attribute) {
					var attr_value = engine.create_closure (((Attribute) attr).expression);
					tuple.attributes[attr.name.name] = attr_value;
					engine.environment[context, attr.name.name] = attr_value;
				} else if (attr is Override) {
					if (!template.attributes.has_key (attr.name.name)) {
						throw new EvaluationError.OVERRIDE (@"Attempting to override non-existant attribute $(attr.name.name). $(attr.source.source):$(attr.source.line):$(attr.source.offset)");
					}
					var child_override = new TemplateLiteral ();
					child_override.source_expr = template.attributes[attr.name.name];
					child_override.attributes = new Gee.ArrayList<TemplatePart> ();
					child_override.attributes.add_all (((Override) attr).attributes);
					var attr_value = engine.create_closure (child_override);
					tuple.attributes[attr.name.name] = attr_value;
					engine.environment[context, attr.name.name] = attr_value;
				} else if (attr is Undefine) {
					/* Do nothing. We've effectively squatted on this attribute name. */
				} else {
					assert_not_reached ();
				}
			}
			foreach (var entry in template.attributes.entries) {
				if (entry.key in attr_names) {
					continue;
				}
				attr_names.add (entry.key);
				var attr_value = engine.create_closure (entry.value);
				tuple.attributes[entry.key] = attr_value;
				engine.environment[context, entry.key] = attr_value;
			}
			foreach (var external in template.externals) {
				if (!(external in attr_names)) {
					throw new EvaluationError.EXTERNAL_REMAINING (@"External attribute $(external) not overridden.");
				}
			}
			engine.operands.push (tuple);
		}
		public override Expression transform () {
			source_expr = source_expr.transform ();
			foreach (var attribute in attributes) {
				if (attribute is Attribute) {
					((Attribute) attribute).expression = ((Attribute) attribute).expression.transform ();
				}
			}
			return this;
		}
	}
	internal class FunctionCall : Expression {
		internal class FunctionArg : Object {
			public Name? name {
				get;
				set;
			}
			public Expression parameter {
				get;
				set;
			}
		}
		public Expression function {
			get;
			set;
		}
		public Gee.List<FunctionArg> args {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			var context = engine.environment.create ();
			var args_tuple = new Data.Tuple (context);
			var overrides = new Gee.ArrayList<TuplePart> ();
			var it = 0;
			var has_args = false;
			var passed_args = false;
			foreach (var arg in args) {
				if (arg.name == null) {
					has_args = true;
					var id = make_id (it++);
					var @value = engine.create_closure (arg.parameter);
					args_tuple.attributes[id] = @value;
					engine.environment[context, id] = @value;
				} else {
					if (arg.name.name == "value") {
						throw new EvaluationError.OVERRIDE ("Function call has an argument named “value”, which break the function.");
					}
					if (arg.name.name == "args") {
						passed_args = true;
					}
					var attr = new Attribute ();
					attr.name = arg.name;
					attr.expression = engine.create_closure (arg.parameter);
					overrides.add (attr);
				}
			}
			if (passed_args && has_args) {
				throw new EvaluationError.OVERRIDE ("Function call has both unnamed arguments and a named argument “args”.");
			}
			if (!passed_args) {
				var attr = new Attribute ();
				attr.name = new Name ("args");
				attr.expression = new ReturnLiteral (args_tuple);
				overrides.add (attr);
			}

			var instantiation = new Instantiate ();
			instantiation.attributes = overrides;
			instantiation.source_expr = function;
			var lookup = new DirectLookup ();
			lookup.expression = instantiation;
			var names = new Gee.ArrayList<Nameish> ();
			names.add (new Name ("value"));
			lookup.names = names;
			engine.call (lookup);
		}
		public override Expression transform () {
			function = function.transform ();
			foreach (var arg in args) {
				arg.parameter = arg.parameter.transform ();
			}
			return this;
		}
	}
	public string make_id (int id) {
		var len = (int) (sizeof (int) * 8 * Math.log (2) / Math.log (62)) + 1;
		var id_str = new uint8[len + 2];
		if (id < 0) {
			id_str[0] = 'e';
			id = int.MAX + id;
		} else {
			id_str[0] = 'f';
		}
		id_str[len + 1] = '\0';
		for (var it = len; it > 0; it--) {
			var digit = (uint8) (id % 62);
			id = id / 62;
			if (digit < 10) {
				id_str[it] = '0' + digit;
			} else if (digit < 36) {
				id_str[it] = 'A' + (digit - 10);
			} else {
				id_str[it] = 'a' + (digit - 36);
			}
		}
		return ((string) id_str).dup ();
	}
	internal class ListLiteral : Expression {
		public Gee.List<Expression> elements {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			var context = engine.environment.create ();
			var tuple = new Data.Tuple (context);
			tuple.containers = new Utils.ContainerReference (engine.state.context, engine.state.containers);
			for (var it = 0; it < elements.size; it++) {
				tuple.attributes[make_id (it)] = engine.create_closure (elements[it]);
			}

			var state = engine.state;
			if (state.this_tuple != null) {
				var container_expr = new ReturnLiteral (tuple);
				tuple.attributes["Container"] = container_expr;
				engine.environment[context, "Container"] = container_expr;
			}
			state.containers = new Utils.ContainerReference (state.context, state.containers);
			engine.environment.append_containers (context, state.containers);
			state.context = context;
			state.this_tuple = tuple;

			engine.state = state;

			engine.operands.push (tuple);
		}
		public override Expression transform () {
			for (var it = 0; it < elements.size; it++) {
				elements[it] = elements[it].transform ();
			}
			return this;
		}
	}
	public class This : Expression {
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			var this_tuple = engine.state.this_tuple;
			if (this_tuple == null) {
				throw new EvaluationError.INTERNAL ("This references non-existent tuple.");
			}
			engine.operands.push (this_tuple);
		}
		public override Expression transform () {
			return this;
		}
	}
}
