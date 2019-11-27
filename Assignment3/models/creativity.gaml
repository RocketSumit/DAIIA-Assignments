/***
* Name: auctions
* Author: sumitpatidar, utkarshkunwar
* Description: Assignment 2 for DAIIA
* Tags: Dutch-Auction, FIPA
***/
model creativity

global {
	float worldDimension <- 100 #m;
	geometry worldShape <- square(worldDimension);
	float step <- 1 #s;
	int max_cycles <- 100000;

	//globals for guest
	int nb_guests <- 30;

	//globals for Stage
	int nb_stage <- 4;
	list<point>
	stages_locs <- [{worldDimension / 4, worldDimension / 4}, {worldDimension / 4, worldDimension * (3 / 4)}, {worldDimension * (3 / 4), worldDimension * (3 / 4)}, {worldDimension * (3 / 4), worldDimension / 4}];
	list<Guest> guestlist <- nil;
	list<string> roles <- ['band', 'play', 'singer', 'dancer'];

	//globals for utility
	init {
		seed <- #pi / 5; // good seed: pi/5
		create Guest number: nb_guests with: (role: "guest") returns: gs;
		guestlist <- gs;
		create Guest number: 1 with: (role: "leader");

		// Randomised locations for stages.
		int i <- 0;
		bool decent_loc <- false;
		loop i from: 0 to: nb_stage - 1 {
		//			point stage_point <- {rnd(worldDimension), rnd(worldDimension)};
		//			stages_locs <+ stage_point;
			create Stage number: 1 with: (location: stages_locs[i], role: roles[i]);
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
	float stage_interaction_distance <- 1.0; //rnd(5.0, 12.0); // to avoid clutter at one place
	list<float> my_preferences <- [rnd(0.0, 1.0), rnd(0.0, 1.0), rnd(0.0, 1.0)]; //1.Lightshow 2.Speakers 3.Band 4.Seats 5.Food 6.Visuals 7.Popularity
	list<point> stage_locs <- nil;
	list<float> stage_utility <- nil;
	list<string> stages <- nil;
	point best_stage_loc <- nil;
	string best_stage <- nil;
	float best_utility <- 0.0;
	string role <- "guest";
	bool crowd_mass <- flip(0.6); // attribute showing if agent prefers crowd or not
	bool leader_inform_others <- false;
	list<string> acts <- nil;
	string best_act <- nil;

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
	// Dance.
	reflex dance when: !moving and best_act = 'dancer' {
		do wander speed: 0.02 bounds: square(0.2 #m);
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
				acts <+ information.contents[2];
				write '\t(Time ' + time + '): ' + agent(information.sender).name + ' utility: ' + current_utility;
				// select best stage
				if (current_utility > max_utility) {
					max_utility <- current_utility;
					best_stage_loc <- agent(information.sender).location;
					best_stage <- agent(information.sender).name;
					best_act <- information.contents[2];
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
		do start_conversation with: [to::guestlist, protocol::'fipa-contract-net', performative::'request', contents::['Leader announcement', best_stage, best_stage_loc, best_act]];
		leader_inform_others <- false;
	}

	// Read request msgs from stage initiator.
	reflex receive_request_messages when: !empty(requests) {
		message r <- requests[0];
		if (string(r.contents[0]) = 'Leader announcement' and crowd_mass) {
			best_stage_loc <- r.contents[2];
			best_stage <- r.contents[1];
			best_act <- r.contents[3];
			target_point <- best_stage_loc;
			target_point <- {target_point.x + rnd(-10, 10), target_point.y + rnd(5, 10)};
			write '\t(Time ' + time + '): ' + name + ' My choice: ' + best_stage + " LOVES CROWD.";
		} else if (r.contents[0] = 'Leader announcement' and !crowd_mass and best_stage = r.contents[1]) {
		// Change own stage because I prefer less crowd
			remove best_stage_loc from: stage_locs;
			remove best_stage from: stages;
			remove best_utility from: stage_utility;
			remove best_act from: acts;

			// find new second best stage act
			float temp_uti <- max(stage_utility);
			int ind <- stage_utility index_of temp_uti;
			best_stage_loc <- stage_locs[ind];
			best_stage <- stages[ind];
			best_act <- acts[ind];
			target_point <- best_stage_loc;
			target_point <- {target_point.x + rnd(-10, 10), target_point.y + rnd(5, 10)};
			write '\t(Time ' + time + '): ' + name + ' My choice: ' + best_stage + " HATES CROWD.";
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
	string role <- nil;
	list<float> act_attributes <- [rnd(0.0, 1.0) with_precision 1, rnd(0.0, 1.0) with_precision 1, rnd(0.0, 1.0) with_precision 1];
	list<int> dance_timer <- [50, 200];
	list<int> dance_frames <- [285, 27];
	list<int> band_timer <- [150, 100];
	list<int> band_frames <- [25, 73];
	list<int> singer_timer <- [100, 100];
	list<int> singer_frames <- [97, 109];
	list<int> play_timer <- [150, 150];
	list<int> play_frames <- [49, 121];
	int timer <- 0;
	bool aspect_decided <- false;
	string icon_folder <- nil;
	int max_frames <- 0;

	// Send invitation to all guests in the festival to join auction.
	reflex informGuestsAboutActs when: mod(int(time), act_duration) = 0 {
		write '\n(Time ' + time + '): ' + name + ' sends a invitation to all the guests.';
		role <- any(['band', 'play', 'singer', 'dancer']);
		my_icon <- image_file("../includes/icons/" + role + ".png");
		aspect_decided <- false;
		do start_conversation with: [to::list(Guest), protocol::'fipa-contract-net', performative::'inform', contents::['Invitation', act_attributes, role]];
	}

	// Change act attributes once it ends
	reflex newActAttributes when: mod(int(time), act_duration) = 0 {
		act_attributes <- [rnd(0.0, 1.0) with_precision 1, rnd(0.0, 1.0) with_precision 1, rnd(0.0, 1.0) with_precision 1];
	}

	image_file my_icon <- image_file("../includes/icons/" + role + ".png");
	list<rgb> mycolors <- [rgb(192, 252, 15, 100), rgb(15, 192, 252, 100), rgb(252, 15, 192, 100)];

	aspect icon {
		draw my_icon size: 7 * 2;
	}

	reflex decideDancerLook when: role = 'dancer' and !aspect_decided {
		icon_folder <- any("dancer1", "dancer2");
		if (icon_folder = "dancer1") {
			timer <- dance_timer[0];
			max_frames <- dance_frames[0];
		} else {
			timer <- dance_timer[1];
			max_frames <- dance_frames[1];
		}

		aspect_decided <- true;
		cur_ind <- 1;
	}

	reflex decideBandLook when: role = 'band' and !aspect_decided {
		icon_folder <- any("band1", "band2");
		if (icon_folder = "band1") {
			timer <- band_timer[0];
			max_frames <- band_frames[0];
		} else {
			timer <- band_timer[1];
			max_frames <- band_frames[1];
		}

		aspect_decided <- true;
		cur_ind <- 1;
	}

	reflex decideSingerLook when: role = 'singer' and !aspect_decided {
		icon_folder <- any("singer1", "singer2");
		if (icon_folder = "singer1") {
			timer <- singer_timer[0];
			max_frames <- singer_frames[0];
		} else {
			timer <- singer_timer[1];
			max_frames <- singer_frames[1];
		}

		aspect_decided <- true;
		cur_ind <- 1;
	}

	reflex decidePlayLook when: role = 'play' and !aspect_decided {
		icon_folder <- any("play1", "play2");
		if (icon_folder = "play1") {
			timer <- play_timer[0];
			max_frames <- play_frames[0];
		} else {
			timer <- play_timer[1];
			max_frames <- play_frames[1];
		}

		aspect_decided <- true;
		cur_ind <- 1;
	}

	int cur_ind <- 1;

	reflex playAnimation when: aspect_decided and mod(int(time), timer) = 0 {
		list<Guest> audience <- Guest at_distance (13);
		if (length(audience) > 0) {
			my_icon <- image_file("../includes/" + icon_folder + "/" + role + string(cur_ind) + ".png");
			cur_ind <- cur_ind + 1;
			if (cur_ind > max_frames) {
				cur_ind <- 1;
			}

		} else {
			my_icon <- image_file("../includes/icons/" + role + ".png");
		}

	}

	// Display character of the guest.
	aspect range {
		if (role = 'band' or role = 'dancer') {
			draw circle(12) color: any(mycolors) border: #black;
		} else {
			draw circle(12) color: rgb(93, 138, 233, 100) border: #black;
		}

	}

}

// Experiment.
experiment creativity type: gui {
	output {

	// Display map.
		display creativity type: opengl {
			species Stage aspect: range;
			species Stage aspect: icon;
			species Guest aspect: icon;
		}

		// Inspect the attributes of stages
		inspect "Stages act" value: Stage attributes: ["act_attributes", "role"];
	}

}


