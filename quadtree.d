module quadtree;

enum DIRECTIONS = ["ne", "nw", "sw", "se"];
/// Coords must implement headingstring, newcenter, and opEquals. 
///For performance Thingy should probably be a pointer, or something small.
template Quadtree(Coords , Thingy, int MAX_PER_BUCKET = 1)  if(MAX_PER_BUCKET > 0)
{
	

	struct Quadtree {
		immutable(Coords) center;
		bool _isleaf;
		Quadtree*[4] _subtrees;
		Thingy[const(Coords)] _data;
		
		@property bool isleaf() const {return _isleaf;}
		@property bool isfull() {return !isleaf || data.length >= MAX_PER_BUCKET;}
		@property Quadtree*[4] subtrees()  {
			assert(!isleaf,"This is a leaf, it has no children");
			return _subtrees;
		}
	
		
		@property Quadtree* ne() {return subtrees[0];}
		@property Quadtree* nw() {return subtrees[1];}
		@property Quadtree* sw() {return subtrees[2];}
		@property Quadtree* se() {return subtrees[3];}

		@property Thingy[const(Coords)] data() {
			assert(isleaf, "This is not a leaf, so it holds no data on its own");
			return _data;
		}

		this(Coords origin) {
			center = origin; 
			_isleaf = true;
			_subtrees = [null,null,null,null]; 
			Thingy[const(Coords)] emptydata;
			_data = emptydata;
		}

		this(Coords origin, string heading) {
			center = origin.newcenter(heading); 
			_isleaf = true;
			_subtrees = [null,null,null,null]; 
			Thingy[const(Coords)] emptydata;
			_data = emptydata;
		}
	
		Quadtree* subtreeInDirection(string heading) {
			switch (heading) {
				case "ne" :
				return ne;
				break;
				case "nw" :
				return nw;
				break;
				case "sw" :
				return sw;
				break;
				case "se" :
				return se;
				break;
				default :
				assert(0, "heading must be ne, nw, se, or sw");
				break;
			}
		}

		/// Insert the thing at coords
		void insert(Thingy thing, const Coords at) {
			if (!isfull) {
				// this is not full then it is a leaf so no problemo
					_data[at] = thing;
					return;
			}

			if (isleaf) {
				// this isfull and isleaf, so we push data into children before inserting
				foreach(int i, string heading; DIRECTIONS) 
				{
					//import std.stdio : writeln;
					//writeln("Inserting new tree with center ", center.newcenter(heading));
					_subtrees[i] = new Quadtree(center, heading);
				}
				_isleaf = false;
				foreach(coords, thingval; _data) {
					// if we are here, we have made isleaf false, 
					// so we shouldn't be messing with these during the recursive calls
					subtreeInDirection(center.headingString(coords)).insert(thingval, coords);
				}
				Thingy[const(Coords)] empty;
				_data = empty;
			}
			subtreeInDirection(center.headingString(at)).insert(thing, at);
		}

		Thingy* query(Coords coords) {
			if (!isleaf) {
				return subtreeInDirection(center.headingString(coords)).query(coords);
			} else {
				return (coords in data);
			}
		}

		Thingy[const(Coords)] all() {
			if (isleaf) {
				return data.dup;
			} else {
				Thingy[const(Coords)] result;
				foreach(i, dirstring; DIRECTIONS) {
					if (_subtrees[i] !is null) {
						foreach(coord, thing; subtreeInDirection(dirstring).all())
						{
							result[coord] = thing;
						}
					}
				}
				//if (_subtrees[1] !is null) {result ~= nw.all();}
				//if (_subtrees[2] !is null) {result ~= sw.all();}
				//if (_subtrees[3] !is null) {result ~= se.all();}
				return result;
			}
		} 

		string toString() {
			if (isleaf) {
				import std.conv : to;
				return data.to!string;
			} else {
				string result;
				foreach(dirstring; DIRECTIONS) {
					if (subtreeInDirection(dirstring) !is null) {
						result ~= subtreeInDirection(dirstring).toString();
					}
				}
				return result;
			}
		}

	}
}

version(unittest) {
	struct CoordsF {
		float x,y,scale;

		size_t toHash() {
			return cast(size_t)x ^ cast(size_t)y;
		}

		CoordsF matchscale(CoordsF tomatch) const  {
			return CoordsF(x,y, tomatch.scale);
		}

		bool opEquals(ref const CoordsF rhs) const {return (x == rhs.x && y == rhs.y);} 
		string headingString(CoordsF towards) const {
			if (x <= towards.x) {
				if (y <= towards.y) {
					return "ne";
				} else {
					return "se";
				}
			} else {
				if (y <= towards.y) {
					return "nw";
				} else {
					return "sw";
				}
			}
		}


		/// Gives the center of a new subdivision in the direction heading
		CoordsF newcenter(string heading) const {
			switch(heading) {
				case "ne" :
				return CoordsF(x + scale, y + scale, scale/2);
				break;
				case "nw" :
				return CoordsF(x - scale, y + scale, scale/2);
				break;
				case "sw" :
				return CoordsF(x - scale, y - scale, scale/2);
				break;
				case "se" :
				return CoordsF(x + scale, y - scale, scale/2);
				break;
				default :
				assert(0, "heading must be ne, nw, se, or sw");
			}
		}

		string toString() const {
			import std.string : format;
			import std.math : frexp;
			int exp;
			frexp(scale , exp);
			return format("(%s , %s , %s)" ,x,y, exp);
		}



	}

}

version(unittest) {
	void main() {
		alias QTFI = Quadtree!(CoordsF, int, 5);
		alias QTFIP = Quadtree!(CoordsF, int*, 5);

		import std.stdio : writeln;
		import std.random;
		auto origin = immutable(CoordsF)(0.0, 0.0, 0.5);
		auto cutieFIP = QTFIP(origin);
		float x = -0.5 , y = 0;
		for (int i = 0; i < 9999; i++) {
			x += 0.0001;
			y += uniform(-0.00001,0.00001);
			//writeln("inserting at (" , x , "," , y , ").");
			cutieFIP.insert(new int, CoordsF(x,y, 0));
		}
		y = -0.5;
		x = 0;
		for (int i = 0; i < 9999; i++) {
			y += 0.0001;
			x += uniform(-0.00001,0.00001);
			//writeln("inserting at (" , x , "," , y , ").");
			cutieFIP.insert(new int, CoordsF(x,y, 0));
		}
		int thingy = 123456;
		cutieFIP.insert(&thingy, CoordsF(0.00025,-0.000007));
		assert(**cutieFIP.query(CoordsF(0.00025,-0.000007))== 123456);
	}
}