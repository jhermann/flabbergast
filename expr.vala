namespace Flabbergast {
	public abstract class Expression : Object, GTeonoma.SourceInfo {
		public GTeonoma.source_location source {
			get;
			set;
		}
		public abstract void evaluate (ExecutionEngine engine) throws EvaluationError;
		public abstract Expression transform ();
	}
}
namespace Flabbergast.Expressions {
	public class ReturnLiteral : Expression {
		private unowned Data.Datum datum;
		public ReturnLiteral (Data.Datum datum) {
			this.datum = datum;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (datum);
		}
		public override Expression transform () {
			return this;
		}
	}
	public class ReturnOwnedLiteral : Expression {
		private Data.Datum datum;
		public ReturnOwnedLiteral (Data.Datum datum) {
			this.datum = datum;
		}
		public ReturnOwnedLiteral.int (int @value) {
			this(new Data.Integer (@value));
		}
		public ReturnOwnedLiteral.str (string @value) {
			this(new Data.String (@value));
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (datum);
		}
		public override Expression transform () {
			return this;
		}
	}
	internal class SubExpression : Expression {
		public Expression expression {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.call (expression);
		}
		public override Expression transform () {
			expression = expression.transform (); return this;
		}
	}
	internal class TrueLiteral : Expression {
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (new Data.Boolean (true));
		}
		public override Expression transform () {
			return this;
		}
	}
	internal class FalseLiteral : Expression {
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (new Data.Boolean (false));
		}
		public override Expression transform () {
			return this;
		}
	}
	internal class IntegerLiteral : Expression {
		public int @value {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (new Data.Integer (@value));
		}
		public override Expression transform () {
			return this;
		}
	}
	internal class IntMaxLiteral : Expression {
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (new Data.Integer (int.MAX));
		}
		public override Expression transform () {
			return this;
		}
	}
	internal class IntMinLiteral : Expression {
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (new Data.Integer (int.MIN));
		}
		public override Expression transform () {
			return this;
		}
	}
	internal class GenerateId : Expression {
		public Expression expr {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.call (expr);
			var frame = engine.operands.pop ();
			if (frame is Data.Frame) {
				engine.operands.push (new Data.String (make_id ((int) ((Data.Frame)frame).context)));
			} else {
				throw new EvaluationError.TYPE_MISMATCH (@"Expected frame in generate id. $(source.source):$(source.line):$(source.offset)");
			}
		}
		public override Expression transform () {
			expr = expr.transform ();
			return this;
		}
	}
	internal class Id : Expression {
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			var frame = engine.state.this_frame;
			if (frame != null) {
				engine.operands.push (new Data.String (make_id ((int) frame.context)));
			} else {
				throw new EvaluationError.INTERNAL (@"This frame is null in generate id. $(source.source):$(source.line):$(source.offset)");
			}
		}
		public override Expression transform () {
			return this;
		}
	}
	internal class FloatLiteral : Expression {
		public double @value {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (new Data.Float (@value));
		}
		public override Expression transform () {
			return this;
		}
	}
	internal abstract class FixedFloatLiteral : Expression {
		public abstract double get_value ();
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (new Data.Float (get_value ()));
		}
		public override Expression transform () {
			return this;
		}
	}
	internal class FloatMaxLiteral : FixedFloatLiteral {
		public override double get_value () {
			return double.MAX;
		}
	}
	internal class FloatMinLiteral : FixedFloatLiteral {
		public override double get_value () {
			return double.MIN;
		}
	}
	internal class FloatInfinityLiteral : FixedFloatLiteral {
		public override double get_value () {
			return double.INFINITY;
		}
	}
	internal class FloatNaNLiteral : FixedFloatLiteral {
		public override double get_value () {
			return double.NAN;
		}
	}
	internal class IdentifierStringLiteral : Expression {
		public Name name {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (new Data.String (name.name));
		}
		public override Expression transform () {
			return this;
		}
	}
	internal class StringPiece : Object {
		public Expression? expression {
			get;
			set;
		}
		public GTeonoma.StringLiteral? literal {
			get;
			set;
		}
		public void render (ExecutionEngine engine, StringBuilder builder) throws EvaluationError {
			if (expression != null) {
				var result = (Data.String)convert (engine, expression, Data.Ty.STR);
				builder.append (result.@value);
			}
			if (literal != null) {
				builder.append (literal.str);
			}
		}
		public void transform () {
			if (expression != null) {
				expression = expression.transform ();
			}
		}
	}
	internal class StringLiteral : Expression {
		public Gee.List<StringPiece>? contents {
			get;
			set;
		}
		public GTeonoma.StringLiteral? literal {
			get;
			set;
		}

		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			var builder = new StringBuilder ();
			if (literal != null) {
				builder.append (literal.str);
			}
			if (contents != null) {
				foreach (var chunk in contents) {
					chunk.render (engine, builder);
				}
			}
			engine.operands.push (new Data.String (builder.str));
		}
		public override Expression transform () {
			if (literal == null) {
				literal = new GTeonoma.StringLiteral ();
				literal.str = "";
			}
			if (contents != null) {
				foreach (var piece in contents) {
					piece.transform ();
				}
			}
			return this;
		}
	}
	internal class NullLiteral : Expression {
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (new Data.Null ());
		}
		public override Expression transform () {
			return this;
		}
	}
	internal class ContinueLiteral : Expression {
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.operands.push (new Data.Continue ());
		}
		public override Expression transform () {
			return this;
		}
	}
	internal class NullCoalesce : Expression {
		public Expression expression {
			get;
			set;
		}
		public Expression alternate {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.call (expression);
			if (engine.operands.peek () is Data.Null) {
				engine.operands.pop ();
				engine.call (alternate);
			}
		}
		public override Expression transform () {
			expression = expression.transform (); alternate = alternate.transform (); return this;
		}
	}
	internal class IsNull : Expression {
		public Expression expression {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.call (expression);
			engine.operands.push (new Data.Boolean (engine.operands.pop () is Data.Null));
		}
		public override Expression transform () {
			expression = expression.transform (); return this;
		}
	}
	internal class RaiseError : Expression {
		public Expression expression {
			get;
			set;
		}
		public override void evaluate (ExecutionEngine engine) throws EvaluationError {
			engine.call (expression);
			var result = engine.operands.pop ();
			var src_ref = @"$(source.source):$(source.line):$(source.offset)";
			var frame = engine.state.this_frame;
			string frame_ref;
			if (frame != null) {
				frame_ref = @"$(frame.source.source):$(frame.source.line):$(frame.source.offset) ";
			} else {
				frame_ref = "";
			}
			if (result is Data.String) {
				throw new EvaluationError.USER_DEFINED (@"$(((Data.String)result).value) $(frame_ref)$(src_ref)");
			} else {
				throw new EvaluationError.TYPE_MISMATCH (@"Expected string in error. $(frame_ref)$(src_ref)");
			}
		}
		public override Expression transform () {
			expression = expression.transform (); return this;
		}
	}
}
