module utils;

import gfm.sdl2;
import derelict.sdl2.sdl;

SDL2Texture loadFile(SDL2 sdl2inst,
					 SDL2Renderer renderer, 
					 SDLImage imagelib, 
					 string file, 
					 void delegate(SDL2, SDL_Surface*) directive = null
					) {
	SDL2Surface surfacetemp;	
	scope(exit) {
    	surfacetemp.close();
	}

	surfacetemp = imagelib.load(file);
	if (directive !is null ) {
		directive(sdl2inst, surfacetemp.handle());
	}
    return new SDL2Texture(renderer, surfacetemp);
}

struct Blitter {
	import std.conv : to;

	SDL2 _sdl2 = null;
	SDL2Renderer _renderer = null;
	SDLImage _imageloader;
	SDL2Texture _texture;
	SDL_Rect[] _blits;
	size_t[string] _blitnames;

	this( SDL2 sdl2inst, SDL2Renderer renderer, SDLImage imageloader) {
		_sdl2 = sdl2inst;
		_renderer = renderer;
		_imageloader = imageloader;
	}

	this(SDL2 sdl2inst, SDL2Renderer renderer, SDLImage imageloader, string file) {
		_sdl2 = sdl2inst;
		_renderer = renderer;
		_imageloader = imageloader;

		//void setcolorkey(SDL2 sdl2inst, SDL_Surface* surf) {
		//	SDL_SetColorKey(surf,
		//			SDL_TRUE, 
		//			SDL_MapRGB(surf.format,255,0,255)
		//		    );
		//}

		_texture = loadFile(_sdl2, _renderer, _imageloader, file);
		if(_texture is null) {
			throw new SDL2Exception("Could not load texture from file");
		}
	}

	void loadFromFile(string file) {
		if(_renderer is null) {
			throw new SDL2Exception("Cannot create texure for unknown renderer");
		}
		_texture = loadFile(_sdl2, _renderer, _imageloader, file);
	}

	void setName(size_t index, string name) {
		_blitnames[name] = index;
	}

	bool renameTile(string oldname, string newname) {
		if ((oldname in _blitnames) !is null) {
				size_t temp = _blitnames[oldname];
				_blitnames.remove(oldname);
				_blitnames[newname] = temp;
				return true;
		} else {return false;}

	}

	void addBlit(int width, int height, int x = 0, int y = 0) {
		auto rect = SDL_Rect();
		rect.w = width;
		rect.h = height;
		rect.x = x;
		rect.y = y;
		_blits ~= rect;
	}

	void addBlit(string name, int width, int height, int x = 0, int y = 0) {
		_blitnames[name] = _blits.length;
		addBlit(width, height, x, y);
	}

	void addTiles(int numhorizontal, int numvertical) {
		if (_texture is null) {
			throw new SDL2Exception("No texture loaded, cannot blit");
		}
		int horsize  = _texture.width / numhorizontal; 
		int vertsize = _texture.height / numvertical;
		for(int jy = 0; jy < numvertical; jy++ ) {
			for( int ix = 0; ix < numhorizontal; ix++) {
				string name;
				if (numhorizontal == 1) {
					name = to!string(jy);
				} else if (numvertical == 1) {
					name = to!string(ix); 
				} else {
					name = "("~to!string(ix) ~ "," ~ to!string(jy)~")";
				}
				addBlit(name, 
						horsize,
						vertsize,
						ix*horsize,
						jy*vertsize);
			}
		}
	}

	bool render(size_t sourceindex, SDL_Rect dest) {
		if (_renderer is null) {
			throw new SDL2Exception("no renderer");
		}
		if (_sdl2 is null) {
			throw new SDL2Exception("no SDL2 instance");
		}
		if (_texture is null) {
			throw new SDL2Exception("no texture");
		}
		_renderer.copy(_texture, _blits[sourceindex], dest);
		return true;
	}

	bool render(string sourcename, SDL_Rect dest) {
		if ((sourcename in _blitnames) is null) {
			return false;
		} else {
			return render(_blitnames[sourcename], dest);
		}
	}

	void close() {
		if (_texture !is null) {
			_texture.close();
		}
	}

	~this() {
		close();
	}

}

class TimeManager(string units = "msecs") {
	import std.datetime : StopWatch, AutoStart;
	import core.time : TickDuration;

	private {
		StopWatch _sw;
		TickDuration _period;
		TickDuration _lastchecked;
	}

	public {

		this(long period) {
			_sw = StopWatch(AutoStart.no);
			_period = _sw.peek().from!(units)(period);
			_lastchecked = _sw.peek();
			_sw.start();
		}


		@property long period() pure const @safe nothrow {return _period.to!(units, long);}
		@property long lastchecked() pure const @safe nothrow {return _lastchecked.to!(units, long);}
		long peek() const @safe {return _sw.peek().to!(units, long);}

		void pause() @safe {
			_sw.stop();
		}

		void reset() @safe {
			_sw.stop();
			_sw.reset();
			_lastchecked = _sw.peek();
		}
	}
	
}

final class Blocker(string units = "msecs") : TimeManager!(units) {
	import core.time : dur;
	import std.conv : to;
	import core.thread : Thread;

	public {

		this(long period) {
			super(period);
		}

		void block() {
			if (_sw.peek() - _lastchecked < _period) {
				Thread.sleep(dur!(units)((_period - (_sw.peek() - _lastchecked)).to!(units, long)));
			}
			_lastchecked = _sw.peek();
		}
	}

}

final class Pulser(string units = "msecs") : TimeManager!(units) {

	public 
	{
		this(long period) {
			super(period);
		}

		bool doPulse() @safe {
			if (_sw.peek() - _lastchecked < _period) {
				return false;
			} else {
				_lastchecked = _sw.peek();
				return true;
			}
		}
	}
}
