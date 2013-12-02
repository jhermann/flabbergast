namespace Flabbergast {
	public errordomain EvaluationError {
		BAD_MATCH,
		CIRCULAR,
		EXTERNAL_REMAINING,
		INTERNAL,
		NAME,
		OVERRIDE,
		RESOLUTION,
		TYPE_MISMATCH,
		USER_DEFINED
	}
	public abstract class Nameish : Object, GTeonoma.SourceInfo {
		public GTeonoma.source_location source {
			get;
			set;
		}
		public abstract string name {
			get;
		}
	}
	public class ContainerName : Nameish {
		public override string name {
			get {
				return "Container";
			}
		}
	}
	public class Name : Nameish {
		private string _name;
		public override string name {
			get {
				return _name;
			}
		}
		public Name (string name) {
			_name = name;
		}
	}

	internal class Promise : Expression {
		WeakRef owner;
		Expression expression;
		bool is_running = false;
		MachineState state;
		internal Datum? evaluated_form = null;

		internal Promise (ExecutionEngine engine, Expression expression, MachineState state) {
			owner = WeakRef (engine);
			this.expression = expression;
			this.state = state;
		}

		public override void evaluate(ExecutionEngine engine) throws EvaluationError {
			if (owner.get () != engine) {
				throw new EvaluationError.INTERNAL ("Tried to execute a promise on a different evaluation enginge.");
			}
			if (is_running) {
				throw new EvaluationError.CIRCULAR ("Circular evaluation detected.");
			}
			if (evaluated_form != null) {
				engine.operands.push (evaluated_form);
				return;
			}
			engine.state = state;
			is_running = true;
			expression.evaluate (engine);
			is_running = false;
			evaluated_form = engine.operands.peek ();
		}
	}

	public class ContainerReference {
		public ContainerReference? parent;
		public uint context;
		public ContainerReference (uint context, ContainerReference? parent) {
			this.parent = parent;
			this.context = context;
		}
	}

	internal struct MachineState {
		internal uint context;
		internal ContainerReference? containers;
		internal unowned Tuple? this_tuple;
	}

	public class DataStack {
		Gee.Deque<Datum> stack = new Gee.ArrayQueue<Datum> ();
		public DataStack () {}

		public Datum? peek () {
			return (stack.size == 0) ? null : stack.peek_head ();
		}
		public Datum? pop () {
			return (stack.size == 0) ? null : stack.poll_head ();
		}
		public void push(Datum datum) {
			stack.offer_head (datum);
		}
	}
	public class NameEnvironment {
		Utils.DefaultMap<string, Gee.HashMap<uint, Expression> > defined_names = new Utils.DefaultMap<string, Gee.HashMap<uint, Expression> > ((key) => new Gee.HashMap<uint, Expression> ());

		Utils.DefaultMap<string, Utils.DefaultMap<uint, Gee.List<Expression> > > known_names = new Utils.DefaultMap<string, Utils.DefaultMap<uint, Gee.List<Expression> > > ((key) => new Utils.DefaultMap<uint, Gee.List<Expression> > ((key) => new Gee.ArrayList<Expression> ()));

		uint next_context = 0;

		public NameEnvironment () {}

		public uint create() {
			return ++next_context;
		}
		public void append(uint target_context, uint source_context) {
			foreach (var entry in defined_names.entries) {
				var list = known_names[entry.key][target_context];
				list.add (entry.value[source_context]);
			}
		}
		public void append_containers(uint target_context, ContainerReference? inherited_contexts) {
			for (; inherited_contexts != null; inherited_contexts = inherited_contexts.parent) {
				append (target_context, inherited_contexts.context);
			}
		}

		public Expression? get (uint context, string name) {
			if (!defined_names.has_key (name)) {
				return null;
			}
			var map = defined_names[name];
			if (!map.has_key (context)) {
				return null;
			}
			return map[context];
		}

		public Gee.List<Expression> lookup(uint context, string name) {
			if (known_names.has_key (name)) {
				var map = known_names[name];
				if (map.has_key (context)) {
					return map[context];
				}
			}
			return known_names[name][context];
		}

		public void set(uint context, string name, Expression @value) {
			defined_names[name][context] = @value;
		}
	}

	public class ExecutionEngine : Object {
		private StackFrame[] call_stack = {};
		public NameEnvironment environment {
			get;
			private set;
			default = new NameEnvironment ();
		}
		public DataStack operands {
			get;
			private set;
			default = new DataStack ();
		}
		internal MachineState state {
			get {
				return call_stack[call_stack.length - 1].state;
			}
			set {
				call_stack[call_stack.length - 1].state = value;
			}
		}

		struct StackFrame {
			internal Expression? expression;
			internal MachineState state;
			internal StackFrame (MachineState state, Expression? expression) {
				this.expression = expression;
				this.state = state;
			}
		}

		public void call(Expression expression) throws EvaluationError {
			if (call_stack.length == 0) {
				call_stack += StackFrame (MachineState (), expression);
			} else {
				call_stack += StackFrame (call_stack[call_stack.length - 1].state, expression);
			}
			expression.evaluate (this);
			call_stack.length--;
		}

		public Expression create_closure(Expression expression) {
			return new Promise (this, expression, state);
		}

		public bool is_defined(Gee.List<Nameish> names) throws EvaluationError requires(names.size > 0) {
			var result = lookup_contextual_internal (names);
			return result != null;
		}

		private Expression? lookup_contextal_helper (Expression start_context, Gee.List<Nameish> names) throws EvaluationError {
			if (names.size == 1) {
				return start_context;
			}
			call (start_context);
			var index = 1;
			return lookup_direct_internal (names, ref index);
		}

		private Expression? lookup_contextual_internal (Gee.List<Nameish> names) throws EvaluationError {
			var child = environment.get (state.context, names[0].name);
			if (child != null) {
				var result = lookup_contextal_helper (child, names);
				if (result != null) {
					return result;
				}
			}
			foreach (var start_context in environment.lookup (state.context, names[0].name)) {
				if (start_context == null) {
					continue;
				}
				var result = lookup_contextal_helper (start_context, names);
				if (result != null) {
					return result;
				}
			}
			return null;
		}

		public Expression lookup_contextual(Gee.List<Nameish> names) throws EvaluationError requires(names.size > 0) {
			var result = lookup_contextual_internal (names);
			if (result == null) {
				var compound_name = new StringBuilder ();
				var first = true;
				foreach (var name in names) {
					if (first) {
						first = false;
					} else {
						compound_name.append_c ('.');
					}
					compound_name.append (name.name);
				}
				throw new EvaluationError.RESOLUTION (@"Could not resolve $(compound_name.str).");
			}
			return (!)result;
		}
		public Expression? lookup_direct_internal (Gee.List<Nameish> names, ref int it, out bool exists = null) throws EvaluationError {
			var start = operands.pop ();
			for (; it < names.size - 1; it++) {
				if (start is Tuple) {
					var promise = ((Tuple) start)[names[it].name];
					if (promise == null) {
						exists = false;
						return null;
					}
					call (promise);
					start = operands.pop ();
				} else {
					exists = false;
					return null;
				}
			}
			if (start is Tuple) {
				exists = false;
				return ((Tuple) start)[names[names.size - 1].name];
			} else {
				exists = true;
				return null;
			}
		}

		public Expression lookup_direct(Gee.List<Nameish> names) throws EvaluationError requires(names.size > 0) {
			var it = 0;
			bool exists;
			var result = lookup_direct_internal (names, ref it, out exists);
			if (result == null) {
				if (exists) {
					throw new EvaluationError.TYPE_MISMATCH (@"Tried to do a direct lookup inside a non-tuple $(names[it].name).");
				} else {
					throw new EvaluationError.RESOLUTION (@"Could not find matching element $(names[it].name).");
				}
			}
			return (!)result;
		}

		public Tuple start_from(File file) throws EvaluationError {
			if (call_stack.length != 0) {
				call_stack.length = 0;
			}
			var state = MachineState ();
			call_stack += StackFrame (state, null);
			var tuple = file.evaluate (this);
			state.this_tuple = tuple;
			state.context = state.this_tuple.context;
			this.state = state;
			return tuple;
		}

		private Gee.Map<string, Datum> imports = new Gee.HashMap<string, Datum> ();
		internal Expression get_import(string uri) throws EvaluationError {
			Datum import;
			if (imports.has_key (uri)) {
				import = imports[uri];
			} else {
				import = find_import (uri);
				imports[uri] = import;
			}
			return new Expressions.ReturnLiteral (import);
		}
		protected virtual Datum find_import(string uri) throws EvaluationError {
			return new Null ();
		}
	}
}