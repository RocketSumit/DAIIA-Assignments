/***
* Name: task1
* Author: Sumit Patidar <patidar@kth.se>, Utkarsh Kunwar <utkarshk@kth.se>
* Description: N-Queens
***/

model task1

global
{
    float worldDimension <- 100#m;
    geometry worldShape <- square(worldDimension);
    float step <- 1#s;
    
    int N <- 4;
    float square_size <- worldDimension / N;
    float move_speed <- worldDimension;
    float distance_tolerance <- 0.01#m;
    
    bool random_config <- false;

    // Globals for queens.
	list board <- list_with(N, list_with(N, 0));
	
	// Converts index notation to point notation in the map.
    point idToPoint(point pt) {
    	return {pt.x * square_size + 0.5 * square_size, pt.y * square_size + 0.5 * square_size};
    }
    
    // Converts point notation to index notation in the matrix.
    point pointToId(point pt) {
    	return {(pt.x - 0.5 * square_size) / square_size , (pt.y - 0.5 * square_size) / square_size};
    }

    init {
    	int i <- 1;
    	seed <- #pi / 5;
    	loop i from: 1 to: N {
    		create queen with: (location: {((i - 1) + 0.5) * square_size,(((random_config) ? rnd(0, N - 1) : 0) + 0.5) * square_size});
    		board[i - 1][0] <- 1;
    	}
    }
}

species queen skills: [moving, fipa]
{
	// Display icon of the queen.
    image_file my_icon <- image_file("../includes/icons/queen.png");
    float icon_size <- worldDimension / N * 0.8;
    aspect icon {
        draw my_icon size: icon_size;
    }
    
    int idx <- int(location.x / square_size);
    int idy <- int(location.y / square_size);
    
    point target_point <- nil;

    bool moving <- false;
    bool at_target <- false;
    
    bool send_allowed <- false; // When know surely about your position.
    bool receive_allowed <- false; // When you're safe.
    bool tried_all <- false;
    bool next_fails <- false;
    bool can_move <- (name = "queen0");
    
    // Converts index notation to point notation in the map.
    point idToPoint(point pt) {
    	return {pt.x * square_size + 0.5 * square_size, pt.y * square_size + 0.5 * square_size};
    }
    
    // Converts point notation to index notation in the matrix.
    point pointToId(point pt) {
    	return {(pt.x - 0.5 * square_size) / square_size , (pt.y - 0.5 * square_size) / square_size};
    }
    
    // Moves to a point given a target.
    reflex moveToTarget when: target_point != nil {
    	do goto target: idToPoint(target_point) speed: move_speed;
    	moving <- true;
    }
    
    // Checks if reached target or not;
    reflex atTargetPoint when: moving and location distance_to(idToPoint(target_point)) < distance_tolerance {
    	moving <- false;
    	target_point <- nil;
    	
    	board[idx][idy] <- 0;
    	idx <- int(location.x / square_size);
   		idy <- int(location.y / square_size);
   		board[idx][idy] <- 1;
   		//can_move <- false;
//   		write name + " at target [" + idx + ", " + idy;
    }
    
    // Gets the neighbours of the queen.
    list<queen> getNeighbours {
    	list<queen> neighbours <- list(queen);
    	if idx = 0 {
    		neighbours <- neighbours where (each.name = "queen1");
    	} else if idx = N {
    		neighbours <- neighbours where (each.name = "queen" + string(N - 1));
    	} else {
    		neighbours <- neighbours where (each.name = "queen" + string(idx - 1) or each.name = "queen" + string(idx + 1));
    	}
    	
    	return neighbours;
    }
    
    // Gets next queen
    queen getNext {
    	list<queen> neighbours <- getNeighbours();
    	if length(neighbours) > 1 {
    		return neighbours[1];
    	} else if name = "queen0" {
    		return neighbours[0];
		} else {
			return nil;
		}
    }
    
    // Gets previous queen
    queen getPrev {
    	list<queen> neighbours <- getNeighbours();
    	if length(neighbours) > 1 {
    		return neighbours[0];
    	} else if name = "queen0" {
    		return nil;
		} else {
			return neighbours[0];
		}
    }
    
    // Checks if position is valid or not (under attack or not).
    bool isValidPosition {
    	list<queen> queens <- list(queen);
    	queens <- queens where (each.idx < idx);

    	if length(queens) != 0 {
	    	loop q over: queens {
	    		if q.idy = idy {
	    			return false;
	    		} if abs(q.idx - idx) = abs(q.idy - idy) {
	    			return false;
	    		}
	    	}
    	}
    	return true;
    }
    
    // Informs NEXT that I am safe.
    reflex sendSafeToNext when: can_move and isValidPosition() {
    	can_move <- false;
    	tried_all <- false;
    	queen next <- getNext();
    	if next != nil {
    		do start_conversation with: (to::[next], protocol::"fipa-contract-net", performative::"inform", contents::["PREV PLACED"]);
    	}
    }
    
    // Receives from PREV that he is safe.
    reflex receiveSafeFromPrev when: !can_move and !empty(informs) {
    	message i <- informs[0];
    	if i.contents[0] = "PREV PLACED" {
    		can_move <- true;
    	}
    }
    
    // Sends to PREV that he has tried all places.
    reflex sendFailToPrev when: can_move and tried_all {
    	can_move <- false;
    	tried_all <- false;
    	queen prev <- getPrev();
    	if prev != nil {
    		do start_conversation with: (to::[prev], protocol::"fipa-contract-net", performative::"failure", contents::["NO SOLUTION"]);
    	}
    }
    
    reflex receiveFailFromNext when: !can_move and !empty(failures) {
    	message f <- failures[0];
    	if f.contents[0] = "NO SOLUTION" {
    		can_move <- true;
    		tried_all <- false;
    	}
    }
    
    // Moves the queen columnwise.
    reflex move when: can_move and !tried_all {
    	if idy = N - 1 {
    		tried_all <- true;
    		target_point <- {idx, 0};
    	} else {
    		target_point <- {idx, idy + 1};
    	}
    }
}

experiment chessboard type: gui
{
    output {
	    display ChessBoard type: opengl {
	    	// Draw chessboard.
	    	graphics "background" {
	    		draw square(worldDimension) color: #white;
	    	}
	    	graphics "squares" {
	    		int i <- 1;
	    		int j <- 1;
	    		loop i from: 1 to: N {
	    			loop j from: 1 to: N step: 2 {
	    				if mod(i, 2) = 0 {
	    					draw square(square_size) at: {square_size * (i - 1) + 0.5 * square_size, square_size * (j - 1) + 0.5 * square_size} color: #grey;
    					} else if square_size * j < worldDimension {
    						draw square(square_size) at: {square_size * (i - 1) + 0.5 * square_size, square_size * (j) + 0.5 * square_size} color: #grey;
    					}
	    			}
	    		}
	    	}
	    	
	    	species queen aspect: icon;
	    }
	    inspect "inspector" value: queen attributes:["can_move", "next_fails", "tried_all"];
    }
}
