/***
* Name: auctions
* Author: sumitpatidar, utkarshkunwar
* Description: Assignment 2 for DAIIA
* Tags: Dutch-Auction, FIPA
***/
model challenge

global {
	float worldDimension <- 100 #m;
	geometry worldShape <- square(worldDimension);
	float step <- 1 #s;
	int max_cycles <- 40000;

	//globals for guest
	int nb_guests <- 30;

	//globals for Stage
	int nb_stage <- 4;
	list<point> stages_locs <- [];
	list<Guest> guestlist <- nil;

	init {
		seed <- #pi / 5; // good seed: pi/5
		create Guest number: nb_guests with: (role: "guest") returns: gs;
		guestlist <- gs;
		create Guest number: 1 with: (role: "leader");

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
	list<float> my_preferences <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)]; //1.Lightshow 2.Speakers 3.Band 4.Seats 5.Food 6.Visuals 7.Popularity
	list<point> stage_locs <- nil;
	list<float> stage_utility <- nil;
	list<string> stages <- nil;
	point best_stage_loc <- nil;
	string best_stage <- nil;
	float best_utility <- 0.0;
	string role <- "guest";
	bool crowd_mass <- flip(0.6); // attribute showing if agent prefers crowd or not
	float crowd_attribute <- 1.5;
	bool leader_inform_others <- false;

	// Display character of the guest.
	image_file my_icon <- image_file("../includes/icons/" + role + ".png");
	float icon_size <- 1 #m;
	int icon_status <- 0;

	// Utility function
	float get_utility (list<float> act_attributes) {
	// Add a more complex function for utility with atleast 6 variables
		float utility <- act_attributes[0] * my_preferences[0] + act_attributes[1] * my_preferences[1] + act_attributes[2] * my_preferences[2];
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
		stage_utility <- nil;
		stage_locs <- nil;
		loop information over: informs {
			if (string(information.contents[0]) = 'Invitation') {
			// Evaluate utility of the act
				float current_utility <- get_utility(information.contents[1]);
				stage_utility <+ current_utility;
				stage_locs <+ agent(information.sender).location;
				stages <+ agent(information.sender).name;
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
		best_utility <- max_utility;
		if (role = "leader") {
			leader_inform_others <- true; // leader should informs other about his selection
		}

		write '\t(Time ' + time + '): ' + 'My choice: ' + best_stage + " with utility " + max_utility;
	}

	// The leader informs other guest to follow him or the crowd
	reflex informGuestsToAccumulate when: leader_inform_others {
		write '\n(Time ' + time + '): ' + name + ' LEADER asks all to visit ' + best_stage + "\n";
		do start_conversation with: [to::guestlist, protocol::'fipa-contract-net', performative::'request', contents::['Leader announcement', best_stage, best_stage_loc]];
		leader_inform_others <- false;
	}

	// Read request msgs from stage initiator.
	reflex receive_request_messages when: !empty(requests) {
		message r <- requests[0];
		if (string(r.contents[0]) = 'Leader announcement' and crowd_mass) {
			float prev_utility <- best_utility;
			best_stage_loc <- r.contents[2];
			best_stage <- r.contents[1];
			target_point <- best_stage_loc;
			best_utility <- stage_utility[stages index_of best_stage];
			best_utility <- best_utility * crowd_attribute;
			write '\t(Time ' + time + '): ' + name + ' New choice: ' + best_stage + " with utility " + best_utility + " (" + prev_utility + "). LOVES CROWD.";
		} else if (r.contents[0] = 'Leader announcement' and !crowd_mass and best_stage = r.contents[1]) {
			int ind <- stage_utility index_of (max(stage_utility));
			float prev_utility <- best_utility;
			stage_utility[ind] <- stage_utility[ind] / crowd_attribute;
			best_utility <- stage_utility[ind];
			int ind_new <- stage_utility index_of (max(stage_utility));
			if (ind_new != ind) {
			// Change own stage because I prefer less crowd as it has decresed my utility
				remove best_stage_loc from: stage_locs;
				remove best_stage from: stages;
				remove best_utility from: stage_utility;

				// find new second best stage act
				int ind <- stage_utility index_of (max(stage_utility));
				best_stage_loc <- stage_locs[ind];
				best_stage <- stages[ind];
				best_utility <- stage_utility[ind];
				target_point <- best_stage_loc;
				write
				'\t(Time ' + time + '): ' + name + ' New choice: ' + best_stage + " with utility " + best_utility + " (" + prev_utility + " -> " + prev_utility / crowd_attribute + "). HATES CROWD.";
			} else {
				write '\t(Time ' + time + '): ' + name + ' Same choice: ' + best_stage + " with utility " + best_utility + " (" + prev_utility + "). HATES CROWD but others acts are too bad.";
			}

		}

	}

	aspect icon {
		draw my_icon size: 7 * icon_size;
	}

}
// --------------------------------------------------Stage----------------------------------------------
species Stage skills: [fipa] {

// Stage variables
	int act_duration <- 20000;
	list<float> act_attributes <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)];

	// Send invitation to all guests in the festival to join auction.
	reflex informGuestsAboutActs when: mod(int(time), act_duration) = 0 {
		write '\n(Time ' + time + '): ' + name + ' sends a invitation to all the guests.';
		do start_conversation with: [to::list(Guest), protocol::'fipa-contract-net', performative::'inform', contents::['Invitation', act_attributes]];
	}

	// Change act attributes once it ends
	reflex newActAttributes when: mod(int(time), act_duration) = 0 {
		act_attributes <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)];
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

	aspect text {
		draw name color: #black size: 5;
	}

}

// Experiment.
experiment challenge type: gui {
	output {

	// Display map.
		display challenge type: opengl {
			species Stage aspect: range;
			species Stage aspect: text;
			species Guest aspect: icon;
		}

		// Inspect the attributes of stages
		inspect "Stages act" value: Stage attributes: ["act_attributes"];
	}

}


