
module grid;


// This would be fun to make an n-dim range template on top of this and make 
template Grid(Cell, size_t WIDTH, size_t HEIGHT) 
if (WIDTH > 0 && HEIGHT > 0 && size_t.max / WIDTH >= HEIGHT && size_t.max / HEIGHT >= WIDTH)
{
	struct Grid {
		import std.range : stride, chunks, roundRobin;
		import std.algorithm : map;
		Cell[WIDTH*HEIGHT] _cells;

	    /// A range of ranges
		auto rows() {
			return chunks!(Cell[])(_cells, WIDTH);
		}

		//auto cols() {
		//	return chunks!(Cell[])(roundRobin(rows()), HEIGHT);
		//}
	 
		struct Bounds {
			size_t _begin , _end;
			this (size_t begin, size_t end) 
			in 
			{
				assert(begin <= end);
			}
			body 
			{
				_begin = begin;
				_end = end;
			}
		}

		auto opSlice(size_t i) (size_t begin, size_t end) pure const {
			return Bounds(begin, end);
		}

		auto ref opIndex(size_t x, size_t y) pure {
			assert( x < WIDTH && y < HEIGHT , "Out of bounds error");
			return _cells[x + y*WIDTH];
		}

		auto opIndex(Bounds a, size_t y) pure {
			assert(y < HEIGHT && a._end <= WIDTH, "Out of bounds error");
			return _cells[a._begin + y*WIDTH .. a._end + y*WIDTH];
		}

		auto opIndex(size_t x, Bounds b) pure {
			assert( x < WIDTH && b._end <= HEIGHT, "Out of bounds error");
			return stride(_cells[x + b._begin * HEIGHT .. x+ b._end*HEIGHT], WIDTH);
		}

		auto opIndex(Bounds a, Bounds b) pure {
			assert( a._end <= WIDTH && b._end <= HEIGHT);
			return (map!(r => r[a._begin..a._end])(rows))[b._begin..b._end];
		}

		/// what happens when cell is a reference type????
		Cell opIndexAssign(Cell cell, size_t x, size_t y) {
			assert( x < WIDTH && y < HEIGHT , "Out of bounds error");
			_cells[x + y*WIDTH] = cell;
			return cell;
		}

		Cell opIndexOpAssign(string op)(Cell cell, size_t x, size_t y) {
			assert( x < WIDTH && y < HEIGHT , "Out of bounds error");
			mixin("return opIndexAssign( _cells[x+y*WIDTH] " ~ op ~ " cell, x, y);");
		}

		size_t width() @property @safe pure nothrow {return WIDTH;}
		size_t height() @property  @safe pure nothrow {return HEIGHT;}
		//terrrible functional programming
		void eagerMutatingMap(Cell function(Cell) f) {
			foreach(ref c; _cells) {
				c = f(c);
			}
		}

		void eagerMutatingMap(void function(ref Cell) f) {
			foreach(ref c; _cells) {
				f(c);
			}
		}
	}
}

version(unittest) {
	alias GridInt = Grid!(int, 10,10);

	unittest {
		import std.stdio : writeln;
		import std.exception : assertThrown , AssertError;
		int[100] cells;
		for(int i=0; i < 100; i++) {
			cells[i] = i;
		}
		auto intgrid = GridInt(cells);
		assert(intgrid[3,7] == 7*10+3);
		assertThrown!(AssertError)(intgrid[10,7]);
		writeln(intgrid.rows());
		(intgrid[4..6, 3..8])[1][1] = 100;
		assert(intgrid[5,4] == 100);
		writeln(intgrid[3..7, 2..9]);
	}

	void main() {

	}
}