/***
* Name: auctions
* Author: sumitpatidar, utkarshkunwar
* Description: Assignment 2 for DAIIA
* Tags: Dutch-Auction, FIPA
***/
model task2

global {
	float worldDimension <- 100 #m;
	geometry worldShape <- square(worldDimension);
	float step <- 1 #s;
	int max_cycles <- 300000;

	//globals for guest
	int nb_guests <- 5;

	//globals for Stage
	int nb_stage <- 2;
	list<point> stages_locs <- [];

	//globals for utility
	init {
		seed <- #pi; // Looked good. good seed: pi/5, pi
		create Guest number: nb_guests returns: ps;

		// Randomised locations for stages.
		int i <- 1;
		loop i from: 1 to: nb_stage {
			point auction_point <- {rnd(worldDimension), rnd(worldDimension)};
			stages_locs <+ auction_point;
			create Stage number: 1 with: (location: auction_point);
		} }

	reflex stop when: cycle = max_cycles {
		write "Paused.";
		do pause;
	} }

	// --------------------------------------------------Festival Guests----------------------------------------------
species Guest skills: [moving, fipa] {

// moving variables
	point target_point <- nil;
	bool moving <- false;
	float move_speed <- 0.01;
	float stage_interaction_distance <- 10.0;

	// Display character of the guest.
	image_file my_icon <- image_file("../includes/icons/guest.png");
	float icon_size <- 1 #m;
	int icon_status <- 0;

	aspect icon {
		draw my_icon size: 7 * icon_size;
	}

}
// --------------------------------------------------Stage----------------------------------------------
species Stage skills: [fipa] {

// Stage variables
	int act_duration <- 10000;
	list<float> act_attributes <- nil;

	// Send invitation to all guests in the festival to join auction.
	reflex informGuestsAuction when: mod(int(time), act_duration) = 0 {
		write '\n(Time ' + time + '): ' + name + ' sends a invitation to all Guests';
		do start_conversation with: [to::list(Guest), protocol::'fipa-contract-net', performative::'inform', contents::[act_attributes]];
	}

	// Display character of the guest.
	aspect range {
		draw circle(12) color: #blue;
	}

}

// Experiment.
experiment task2 type: gui {
	output {

	// Display map.
		display challenge2 type: opengl {
			species Stage aspect: range;
			species Guest aspect: icon;
		}

	}

}


