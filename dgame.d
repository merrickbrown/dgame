import std.typecons;
import std.stdio : writeln;
import std.conv : to;

import gfm.sdl2;
import derelict.sdl2.sdl;

import utils;
import grid;



enum {DEFAULT_HEIGHT  = 640, DEFAULT_WIDTH = 640}
enum {DEFAULT_WINDOW_FLAGS = SDL_WINDOW_HIDDEN}
enum TILE_SIZE = 64;
enum Filenames {FRAMES = "covers64.png", MARKERS = "markers64.png", BACKGROUND = "background128.png"}
enum VIEW_MOVEMENT_RATIO = 2;
enum MSECS_PER_ANIMFRAME = 1000/10;

alias StateGrid = Grid!(CellState, ((3*DEFAULT_WIDTH) / (TILE_SIZE)) + 2, ((3*DEFAULT_HEIGHT) / (TILE_SIZE)) + 2);


struct CellState {
	// internal data
	ubyte symbol = 0;
	bool destroy = false;
	ubyte framestate = 2;
	// external data
	size_t locationx, locationy;
	StateGrid* holder;
	// animation data
	ubyte animstate= 0;
	bool forward = true;

	bool flagged() @property {return framestate/4 == 1;}

	void neighborMap(void function(ref CellState) f) {
		auto ix = locationx;
		auto jy = locationy;
		for (int dx = -1; dx <= 1; dx++) {
			if (ix+dx >= 0 && ix+dx < holder.width) 
			for(int dy = -1; dy <= 1; dy++) {
				if (jy+dy >= 0 && jy+dy < holder.height)
				f((*holder)[ix+dx, jy+dy]); 
			}
		}
	}
}


void updateAnimState(ref CellState state) {
	if (state.destroy) {
		state.framestate = 3;
		state.destroy = false;
		if (state.symbol == 0)
		state.neighborMap(function void(ref CellState x) {x.destroy = true;});
	}
	switch (state.framestate % 4) {
		import std.random : uniform01;
		case 0 :
		state.framestate = 1 + 4*(state.framestate/4);
		break;
		case 1 :
		if (uniform01() > 0.3) {
			state.framestate = 0 + 4*(state.framestate/4);
		} else {
			state.framestate = 2+ 4*(state.framestate/4);
		}
		break;
		case 2 :
		if (uniform01() < 0.01/MSECS_PER_ANIMFRAME) {
			state.framestate = 0 + 4*(state.framestate/4);
		}
		break;
		default :
		if (state.forward) {
			if (state.animstate >= 8-(state.symbol)) {
				state.forward = false;
				state.animstate = 1;
			} else {
				state.animstate++;
			}
		} else {
			state.animstate = 0;
			state.forward = true;	
		}
		break;
	}
}


int xTile(int relxpixelposition) {
	return (  relxpixelposition + DEFAULT_WIDTH 
			+ relxpixelposition /VIEW_MOVEMENT_RATIO 
			- DEFAULT_WIDTH     /(2*VIEW_MOVEMENT_RATIO)
			) / TILE_SIZE;	
}

int yTile(int relypixelposition) {
	return (  relypixelposition + DEFAULT_HEIGHT 
			+ relypixelposition /VIEW_MOVEMENT_RATIO 
			- DEFAULT_HEIGHT     /(2*VIEW_MOVEMENT_RATIO)
			) / TILE_SIZE;
}


class Game {

	bool isrunning = false;
	SDL2 sdl2instance = null;
	SDLImage imageloader = null;
	Blitter glyphs;
	Blitter frames;
	Blitter background;
	SDL2Window mainwindow = null;
	SDL2Renderer renderer = null;
	Pulser!("msecs") renderpulser;
	Pulser!("msecs") animpulser;
	Pulser!("seconds") updatepulser;	
	Blocker!("usecs") speedlimiter;
	int centeradjustx, centeradjusty;

	StateGrid numstuff; 

	auto newGrid() {
		import std.random : uniform;
		numstuff = StateGrid(); //clear the grid
		for(size_t ix = 0; ix < numstuff.width; ix++) {
			for(size_t jy = 0; jy < numstuff.height; jy++) {
				numstuff[ix,jy].holder = &numstuff;
				numstuff[ix,jy].locationx = ix;
				numstuff[ix,jy].locationy = jy;
				if (ix > 0 && ix < numstuff.width-1 && jy > 0 && jy < numstuff.height-1)
				{
					numstuff[ix,jy].animstate = to!ubyte(uniform(0,4));
					if (uniform(0,10) == 0) {
						numstuff[ix,jy].symbol = 9;
						numstuff[ix,jy].destroy = false;
						numstuff[ix,jy].framestate = 2;
						numstuff[ix,jy].neighborMap(function void(ref CellState x) {x.symbol++;});
					}
				}
			}
		}
		return numstuff;
	}

	int onExecute() {
		if (!initialize()) {
			return -1; 
		} else {

			SDL_Event event;

			while(isrunning) 
			{
				while(sdl2instance.pollEvent(&event)) {
					onEvent(&event);
				}
				onLoop();
				onRender();
			}

			cleanup();

			return 0;
		}
	}

	bool initialize() {
		if (isrunning) {return false;}
		else {
			writeln("Initializing:");
			// initialize SDL2
			sdl2instance = new SDL2(null); //null means no logger
			sdl2instance.subSystemInit(SDL_INIT_VIDEO);
			imageloader = new SDLImage(sdl2instance);

			writeln("SDL2 loaded");

			mainwindow = fibwindow(sdl2instance, DEFAULT_WIDTH, DEFAULT_HEIGHT, DEFAULT_WINDOW_FLAGS);
			renderer = new SDL2Renderer(mainwindow);
			if (renderer is null) {
				throw new SDL2Exception("Renderer not loaded");
			}
			writeln("Renderer loaded");
			glyphs = Blitter(sdl2instance, renderer, imageloader, Filenames.MARKERS);
			glyphs.addTiles(12,9);
			frames = Blitter(sdl2instance, renderer, imageloader, Filenames.FRAMES);
			frames.addTiles(4,2);
			background = Blitter(sdl2instance, renderer, imageloader, Filenames.BACKGROUND);
			background.addTiles(2,2);
			writeln("Bitmaps loaded");
			glyphs._texture.setBlendMode(SDL_BLENDMODE_BLEND);
			renderer.setColor(0,0,0);


			newGrid();

			isrunning = true;
			renderpulser = new Pulser!("msecs")(1000/60);
			updatepulser = new Pulser!("seconds")(0);
			animpulser = new Pulser!("msecs")(1000/10);
			speedlimiter = new Blocker!("usecs")(1000000/60);
			return true;
		}
	}
	void onEvent(SDL_Event* event) {
		switch (event.type)
		{
//Quit event:
	//user-requested quit
			case SDL_QUIT :
			isrunning = false;
			break;
//Window events:
	//window state change
			case SDL_WINDOWEVENT :
			switch (event.window.event) 
			{
				case SDL_WINDOWEVENT_CLOSE :
				isrunning = false;
				break;
				default :
				break;
			}
			break;
	//system specific event
			case SDL_SYSWMEVENT :

			break;
//Keyboard events:
	//key pressed
			case SDL_KEYDOWN :
	//key released
			case SDL_KEYUP :
			if (event.key.state == SDL_RELEASED) {
				newGrid();
			}
			break;
	//keyboard text editing (composition)
			case SDL_TEXTEDITING :

			break;
	//keyboard text input
			case SDL_TEXTINPUT :

			break;
//Mouse events:
	//mouse moved
			case SDL_MOUSEMOTION :
			centeradjustx = (DEFAULT_WIDTH/2 - event.motion.x)/VIEW_MOVEMENT_RATIO;
			centeradjusty = (DEFAULT_HEIGHT/2 - event.motion.y)/VIEW_MOVEMENT_RATIO;

			break;
	//mouse button pressed
			case SDL_MOUSEBUTTONDOWN :

			break;
	//mouse button released
			case SDL_MOUSEBUTTONUP :
			switch (event.button.button) {
				case SDL_BUTTON_LEFT :
				if (numstuff[xTile(event.button.x) , yTile(event.button.y)].symbol == 0) 
				numstuff[xTile(event.button.x) , yTile(event.button.y)].destroy = true;
				numstuff[xTile(event.button.x) , yTile(event.button.y)].framestate = 3;
				break;
				case SDL_BUTTON_RIGHT :
				numstuff[xTile(event.button.x) , yTile(event.button.y)].framestate += 4;
				numstuff[xTile(event.button.x) , yTile(event.button.y)].framestate %= 8;
				break;
				default :
				break;
			}
			break;
	//mouse wheel motion
			case SDL_MOUSEWHEEL :

			break;
//Joystick events:
	//joystick axis motion
			case SDL_JOYAXISMOTION :

			break;
	//joystick trackball motion
			case SDL_JOYBALLMOTION :

			break;
	//joystick hat position change
			case SDL_JOYHATMOTION :

			break;
	//joystick button pressed
			case SDL_JOYBUTTONDOWN :

			break;
	//joystick button released
			case SDL_JOYBUTTONUP :

			break;
	//joystick connected
			case SDL_JOYDEVICEADDED :

			break;
	//joystick disconnected
			case SDL_JOYDEVICEREMOVED :

			break;
//Controller events:
	//controller axis motion
			case SDL_CONTROLLERAXISMOTION :

			break;
	//controller button pressed
			case SDL_CONTROLLERBUTTONDOWN :

			break;
	//controller button released
			case SDL_CONTROLLERBUTTONUP :

			break;
	//controller connected
			case SDL_CONTROLLERDEVICEADDED :

			break;
	//controller disconnected
			case SDL_CONTROLLERDEVICEREMOVED :

			break;
	//controller mapping updated
			case SDL_CONTROLLERDEVICEREMAPPED :

			break;
//Touch events:
	//user has touched input device
			case SDL_FINGERDOWN :

			break;
	//user stopped touching input device
			case SDL_FINGERUP :

			break;
	//user is dragging finger on input device
			case SDL_FINGERMOTION :

			break;
//Gesture events:
			case SDL_DOLLARGESTURE :

			break;
			case SDL_DOLLARRECORD :

			break;
			case SDL_MULTIGESTURE :

			break;
//Clipboard events:
	//the clipboard changed
			case SDL_CLIPBOARDUPDATE :

			break;
//Drag and drop events:
	//the system requests a file open
			case SDL_DROPFILE :

			break;
//End of event.type switch
		default :
		import std.stdio : stderr, writefln;
		stderr.writefln("Unknown SDL_Event type: %0#4x",event.type);
		break;
		}
	}

	void onLoop() {
		speedlimiter.block();
		if (animpulser.doPulse()) {
			numstuff.eagerMutatingMap(&updateAnimState);
		}
	}

	void onRender() {
		mainwindow.show();
		if (renderpulser.doPulse()) {
			renderer.clear();
			for (int ix = 1; ix < numstuff.width - 1; ix++) {
				for (int jy = 1; jy < numstuff.height - 1; jy ++) 
				{
					if (ix + centeradjustx/TILE_SIZE+1 >= DEFAULT_WIDTH/TILE_SIZE && 
						jy + centeradjusty/TILE_SIZE+1 >= DEFAULT_HEIGHT/TILE_SIZE &&
						ix + centeradjustx/TILE_SIZE <= 2*DEFAULT_WIDTH/TILE_SIZE &&
						jy + centeradjusty/TILE_SIZE <= 2*DEFAULT_HEIGHT/TILE_SIZE) 
					{
						SDL_Rect dest;
						dest.x = TILE_SIZE * ix - DEFAULT_WIDTH + centeradjustx;
						dest.y = TILE_SIZE * jy - DEFAULT_HEIGHT+ centeradjusty;
						dest.w = TILE_SIZE;
						dest.h = TILE_SIZE;
						background.render(ix % 2 + 2*(jy % 2), dest);
						auto numingrid = numstuff[ix,jy];
						if (numingrid.framestate == 3) { 
												auto tile = (numingrid.symbol > 8) ? ("(0,0)") : ("("~to!string(numingrid.animstate)~"," ~ to!string(numingrid.symbol) ~")");
												glyphs.render( tile, dest);	
						}
						frames.render(numingrid.framestate,dest);
					}
				}
			}
			renderer.present();
		}
	}
	
	void cleanup() {
		writeln("Cleaning up:");
		imageloader.close();
		writeln("SDLImage closed");
		glyphs.close();
		writeln("glyphs closed");
		//displaysurface.close();
		//writeln("displaysurface closed");
		//imagelib.close();
		//writeln("imagelib closed");
		renderer.close();
		writeln("renderer closed");
		mainwindow.close();
		writeln("mainwindow closed");
		sdl2instance.close();
		writeln("sdl2instance closed");
	}

}


// MMMM GOLDEN RATIO HEADSPACE
auto fibwindow(SDL2 sdl2inst, int width, int height, int flags) {
	return new SDL2Window(sdl2inst, 
						  sdl2inst.firstDisplaySize().x/2 - width/2, 
						  13*(sdl2inst.firstDisplaySize().y-height)/34, 
						  width, 
						  height, 
						  flags
						 );
}


int main() {

	import std.stdio : writeln;
	Game mainGame = new Game();
	writeln("GO GAME GO");	
	int endcode = mainGame.onExecute();
	writeln("QUIT");
	return endcode;
}