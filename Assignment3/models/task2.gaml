/***
* Author: sumitpatidar, utkarshkunwar
* Description: Assignment 3 for DAIIA
* Tags: Coordination & Utility
***/
model task2

global {
	float worldDimension <- 100 #m;
	geometry worldShape <- square(worldDimension);
	float step <- 1 #s;
	int max_cycles <- 200000;

	//globals for guest
	int nb_guests <- 20;

	//globals for Stage
	int nb_stage <- 4;
	list<point> stages_locs <- [];

	//globals for utility
	init {
		seed <- #pi / 5; // good seed: pi/5
		create Guest number: nb_guests returns: ps;

		// Randomised locations for stages.
		int i <- 1;
		bool decent_loc <- false;
		loop i from: 1 to: nb_stage {
			point stage_point <- {rnd(worldDimension), rnd(worldDimension)};
			stages_locs <+ stage_point;
			create Stage number: 1 with: (location: stage_point);
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
	float move_speed <- 0.005;

	// stage variables
	float stage_interaction_distance <- rnd(1.0, 10.0); // to avoid clutter at one place
	list<float> my_preferences <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)]; //1.Lightshow 2.Speakers 3.Band 4.Seats 5.Food 6.Popularity 
	point best_stage_loc <- nil;
	string best_stage <- nil;

	// Display character of the guest.
	image_file my_icon <- image_file("../includes/icons/guest.png");
	float icon_size <- 1 #m;
	int icon_status <- 0;

	// Utility function
	float get_utility (list<float> act_attributes) {
	// Add a more complex function for utility with atleast 6 variables
		float
		utility <- act_attributes[0] * my_preferences[0] + act_attributes[1] * my_preferences[1] + act_attributes[2] * my_preferences[2] + act_attributes[3] * my_preferences[3] + act_attributes[4] * my_preferences[4] + act_attributes[5] * my_preferences[5];
		return utility;
	}
	// Move to target point.
	reflex moveToTargetPoint when: target_point != nil {
		do goto target: target_point speed: move_speed;
		moving <- true;
	}

	// Check if reached stage.
	reflex reachedStagePoint when: target_point != nil and location distance_to (target_point) < stage_interaction_distance {
		moving <- false;
		target_point <- nil;
	}

	// Read inform msgs from stage initiator.
	reflex receive_inform_messages when: !empty(informs) {
		write '\n(Time ' + time + '): ' + name + ' receives inform messages.';
		//write '\t(Time ' + time + '): ' + informs;
		float max_utility <- 0.0;
		loop information over: informs {
			if (string(information.contents[0]) = 'Invitation') {
			// Evaluate utility of the act
				float current_utility <- get_utility(information.contents[1]);
				write '\t(Time ' + time + '): ' + agent(information.sender).name + ' utility: ' + current_utility;
				// select best stage
				if (current_utility > max_utility) {
					max_utility <- current_utility;
					best_stage_loc <- agent(information.sender).location;
					best_stage <- agent(information.sender).name;
				}

			}

		}

		target_point <- best_stage_loc;
		write '\t(Time ' + time + '): ' + 'My choice: ' + best_stage + " with utility " + max_utility;
	}

	aspect icon {
		draw my_icon size: 7 * icon_size;
	}

}
// --------------------------------------------------Stage----------------------------------------------
species Stage skills: [fipa] {

// Stage variables
	int act_duration <- 20000;
	list<float> act_attributes <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)]; //1.Lightshow 2.Speakers 3.Band 4.Seats 5.Food 6.Popularity

	// Send invitation to all guests in the festival to join auction.
	reflex informGuestsAboutActs when: mod(int(time), act_duration) = 0 {
		write '\n(Time ' + time + '): ' + name + ' sends a invitation to all the guests.';
		do start_conversation with: [to::list(Guest), protocol::'fipa-contract-net', performative::'inform', contents::['Invitation', act_attributes]];
	}

	// Change act attributes once it ends
	reflex newActAttributes when: mod(int(time), act_duration) = 0 {
		act_attributes <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)]; //1.Lightshow 2.Speakers 3.Band 4.Seats 5.Food 6.Popularity
	}

	//	image_file m1 <- image_file("../includes/icons/guitarist.png");
	//	image_file m2 <- image_file("../includes/icons/singer.png");
	//	image_file my_icon <- any(m1, m2);
	//	list<rgb> mycolors <- [rgb(192, 252, 15, 100), rgb(15, 192, 252, 100), rgb(252, 15, 192, 100)];
	// aspect icon {
	//		draw my_icon size: 7 * 2;
	//	}

	// Display character of the guest.
	aspect range {
		draw circle(12) color: rgb(93, 138, 233, 100) border: #black;
	}

}

// Experiment.
experiment task2 type: gui {
	output {

	// Display map.
		display task2 type: opengl {
			species Stage aspect: range;
			// for creativity
			//species Stage aspect: icon;
			species Guest aspect: icon;
		}

		// Inspect the attributes of stages
		inspect "Stages act" value: Stage attributes: ["act_attributes"];
	}

}


