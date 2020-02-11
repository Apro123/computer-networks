/**
 * ANDES Lab - University of California, Merced
 * This class provides a simple list.
 *
 * @author UCM ANDES Lab
 * @author Alex Beltran
 * @date   2013/09/03
 *
 */

generic module ListC(typedef t, int n){
	provides interface List<t>;
}

implementation{
	uint16_t MAX_SIZE = n;

	t container[n];
	uint16_t size = 0;

	command void List.pushback(t input){
		// Check to see if we have room for the input.
		if(size < MAX_SIZE){
			// Put it in.
			container[size] = input;
			size++;
		}
	}

	command void List.pushfront(t input){
		// Check to see if we have room for the input.
		if(size < MAX_SIZE){
			int32_t i;
			// Shift everything to the right.
			for(i = size-1; i>=0; i--){
				container[i+1] = container[i];
			}

			container[0] = input;
			size++;
		}
	}

	command t List.popback(){
		t returnVal;

		returnVal = container[size];
		// We don't need to actually remove the value, we just need to decrement
		// the size.
		if(size > 0)size--;
		return returnVal;
	}

	command t List.popfront(){
		t returnVal;
		uint16_t i;

		returnVal = container[0];
		if(size>0){
			// Move everything to the left.
			for(i = 0; i<size-1; i++){
				container[i] = container[i+1];
			}
			size--;
		}

		return returnVal;
	}

	// This is similar to peek head.
	command t List.front(){
		return container[0];
	}

	// Peek tail
	command t List.back(){
		return container[size-1]; //size
	}

	command bool List.isEmpty(){
		if(size == 0)
			return TRUE;
		else
			return FALSE;
	}

	command uint16_t List.size(){
		return size;
	}

	command t List.get(uint16_t position){
		return container[position];
	}

	command void List.set(uint16_t position, t value){
		container[position] = value;
	}

	command void List.remove(uint16_t pos) {
		if(size > 0 && pos < size) {
			if(pos == 0) {
				call List.popfront();
			} else if (pos == size-1) {
				call List.popback();
			} else {
				uint16_t i;
				for(i=pos; i < size; i++) {
					container[i] = container[i+1];
				}
				/*
				uint16_t i;
				temp = container;
				for(i=0; i<pos; i++) {
					container[i] = temp[i];
				} */

			}
		}
	}
}
