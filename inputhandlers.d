module inputhandlers;

import derelict.sdl2.sdl;

class InputHandler(T) {

	void onEvent(T* event) {
		static if (is (T == SDL_KeyboardEvent)) {
			
		}
	}

}

alias KeyboardHandler = InputHandler!(SDL_KeyboardEvent);