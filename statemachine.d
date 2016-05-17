module statemachine;

struct StateMachine(State, InputEvent, size_t NUMSTATES) {
	State[NUMSTATES] _machine;
	size_t _current;

	State* current() @property {return &_machine[_current];}

	State* processEvent(InputEvent event) {

	}
}