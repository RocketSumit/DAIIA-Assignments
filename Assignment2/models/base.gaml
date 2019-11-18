/***
* Name: base
* Author: sumitpatidar
* Description: 
* Tags: Tag1, Tag2, TagN
***/
model base

global {
	float worldDimension <- 100 #m;
	geometry worldShape <- square(worldDimension);
	float step <- 1 #s;
	int max_cycles <- 300000;

	//globals for guest
	int nb_guests <- 5;

	//globals for Initiator
	int nb_initiator <- 1;
	list<point> initiators_locs <- [];
	Participant refuser;
	list<Participant> proposers;
	Participant reject_proposal_participants;
	list<Participant> accept_proposal_participantss;
	Participant failure_participants;
	Participant inform_done_participants;
	Participant inform_result_participants;

	init {
		seed <- #pi / 5; // Looked good.
		create Participant number: nb_guests returns: ps;

		// Randomised locations for Initiator.
		int i <- 1;
		loop i from: 1 to: nb_initiator {
			point auction_point <- {rnd(worldDimension), rnd(worldDimension)};
			initiators_locs <+ auction_point;
			create Initiator number: 1 with: (location: auction_point);
		} }

	reflex stop when: cycle = max_cycles {
		write "Paused.";
		do pause;
	} }

	// --------------------------------------------------Festival Guests----------------------------------------------
species Participant skills: [moving, fipa] {
	point random_point <- nil;
	point auction_point <- nil;
	bool moving <- false;
	float move_speed <- 0.001;
	float guest_interaction_distance <- 2.0;
	float auction_interaction_distance <- 10.0;
	int resting_cycles <- 5000;

	// Auction variables
	int wealth <- rnd(2000, 4000);
	bool attend_auction <- flip(0.5);
	bool at_auction <- false;
	bool informed <- false;

	// Explore 
	reflex setrandomPoint when: mod(cycle, resting_cycles) = 0 and !moving and !at_auction {
		write '(Time ' + time + '): ' + name + ' got new random point.';
		random_point <- {rnd(worldDimension), rnd(worldDimension)};
	}

	// At random point
	reflex reachedrandomPoint when: random_point != nil and location distance_to (random_point) < guest_interaction_distance and moving {
		write '(Time ' + time + '): ' + name + ' reached random point.';
		moving <- false;
		random_point <- nil;
	}

	// Move to random point.
	reflex moveToRandomPoint when: random_point != nil {
		do goto target: random_point speed: move_speed;
		moving <- true;
	}

	// change interest in auction
	reflex joinAuction when: (mod(time, 10000) = 0) {
		attend_auction <- flip(0.6);
	}
	// Move to auction point.
	reflex moveToAuctionPoint when: auction_point != nil {
		do goto target: auction_point speed: move_speed;
		moving <- true;
	}

	// At auction point
	reflex reachedAuctionPoint when: auction_point != nil and location distance_to (auction_point) < auction_interaction_distance and !at_auction {
		write '(Time ' + time + '): ' + name + ' reached auction.';
		moving <- false;
		auction_point <- nil;
		at_auction <- true;
	}

	// For dutch auction.
	reflex receive_inform_messages when: !empty(informs) {
		message informationFromInitiator <- informs[0];
		write '\t' + name + ' receives a inform message from ' + agent(informationFromInitiator.sender).name + ' with content ' + informationFromInitiator.contents;
		if (informationFromInitiator.contents[0] = 'Auction terminates.') {
			write '\t' + name + ' leaves auction.';
			auction_point <- nil;
			moving <- false;
			at_auction <- false;
		} else {
			if (attend_auction) {
				write '\t' + name + ' accept the invitation.\n';
				do inform with: [message:: informationFromInitiator, contents::['I will join.']];
				auction_point <- agent(informationFromInitiator.sender).location;
				random_point <- nil;
			} else {
				write '\t' + name + ' refuse the invitation.\n';
				do inform with: [message:: informationFromInitiator, contents::['I am not interested.']];
			}

		}

	}

	reflex inform_auctioneer_to_begin when: at_auction and !informed {
		do start_conversation with: [to::list(Initiator), protocol::'fipa-contract-net', performative::'inform', contents::['I am here.']];
		informed <- true;
	}

	reflex receive_cfp_from_initiator when: !empty(cfps) {
		message proposalFromInitiator <- cfps[0];
		write '(Time ' + time + '): ' + name + ' receives a cfp message from ' + agent(proposalFromInitiator.sender).name + ' with content ' + proposalFromInitiator.contents;
		int proposed_price <- int(proposalFromInitiator.contents[1]);
		if (proposed_price > wealth) {
			write '\t' + name + ' sends a refuse message to ' + agent(proposalFromInitiator.sender).name;
			do refuse with: [message:: proposalFromInitiator, contents::['I am willing to buy for', wealth]];
		} else {
			write '\t' + name + ' sends a propose message to ' + agent(proposalFromInitiator.sender).name;
			do propose with: [message:: proposalFromInitiator, contents::['Cool. I will buy for', proposed_price, 'I have ', wealth]];
		}

	}

	reflex receive_reject_proposals when: !empty(reject_proposals) {
		message r <- reject_proposals[0];
		write '(Time ' + time + '): ' + name + ' receives a reject_proposal message from ' + agent(r.sender).name + ' with content ' + r.contents;
	}

	reflex receive_accept_proposals when: !empty(accept_proposals) {
		message a <- accept_proposals[0];
		write '(Time ' + time + '): ' + name + ' receives a accept_proposal message from ' + agent(a.sender).name + ' with content ' + a.contents;
	}

	// Display character of the guest.
	image_file my_icon <- image_file("../includes/icons/guest.png");
	float icon_size <- 1 #m;
	int icon_status <- 0;

	aspect icon {
		draw my_icon size: 7 * icon_size;
	}

}
// --------------------------------------------------Initiator----------------------------------------------
species Initiator skills: [fipa] {
	int item_price <- 4250; // starting price to sell
	int min_participants <- 3;
	bool start_auction <- false;
	int price_cut <- 500;
	message msg <- nil;
	list<Participant> buyers <- [];
	// icon varibles
	image_file my_icon <- image_file("../includes/icons/auctioneer.png");
	float icon_size <- 2 #m;
	int icon_status <- 0;
	bool no_bid <- false;
	int attenders <- 0;

	reflex informParticipantsAuction when: (time = 0) {
		write '(Time ' + time + '): ' + name + ' sends a invitation to all Participants';
		do start_conversation with: [to::list(Participant), protocol::'fipa-contract-net', performative::'inform', contents::['Auction invitation.', 'T-shirts']];
	}

	reflex receive_inform_messages when: !empty(informs) {
		write '(Time ' + time + '): ' + name + ' receives inform messages';
		loop i over: informs {
			write '\t' + name + ' receives a inform message from ' + agent(i.sender).name + ' with content ' + i.contents;
			if (i.contents[0] = 'I will join.') {
				buyers <+ Participant(agent(i.sender));
			}

			if (i.contents[0] = 'I am here.') {
				attenders <- attenders + 1;
			}

		}

		if (length(buyers) >= min_participants) {
			write '(Time ' + time + '): ' + name + ' will begin auction shortly.\n';
			//start_auction <- true;
			//do start_conversation with: [to::list(buyers), protocol::'fipa-contract-net', performative::'cfp', contents::['T-shirts', item_price]];
		} else {
			write '(Time ' + time + '): ' + name + ' terminates auction becaues of less participants.\n';
			do start_conversation with: [to::list(buyers), protocol::'fipa-contract-net', performative::'inform', contents::['Auction terminates.']];
			start_auction <- false;
			buyers <- [];
		}

	}

	reflex first_cfp when: (attenders = length(buyers)) and attenders != 0 and !start_auction {
		start_auction <- true;
		write 'attenders' + attenders;
		do start_conversation with: [to::list(buyers), protocol::'fipa-contract-net', performative::'cfp', contents::['T-shirts', item_price]];
	}

	reflex receive_refuse_messages when: !empty(refuses) {
		if (length(refuses) = length(buyers)) {
			no_bid <- true;
			write '\n(Time ' + time + '):' + 'No one is willing to buy.';
		}

		write '(Time ' + time + '): ' + name + ' receives refuse messages';
		loop r over: refuses {
			write '\t' + name + ' receives a refuse message from ' + agent(r.sender).name + ' with content ' + r.contents;
		}

	}

	reflex receive_propose_messages when: !empty(proposes) {
		message first_proposal <- proposes[0];
		write '\n(Time ' + time + '): ' + name + ' receives propose messages';
		write '\t' + name + ' receives a propose message from ' + agent(first_proposal.sender).name + ' with content ' + first_proposal.contents;
		write '\t' + name + ' sends a accept_proposal message to ' + first_proposal.sender;
		do accept_proposal with: [message:: first_proposal, contents::['Take the item.']];
		loop p over: proposes {
			write '\t' + name + ' receives a propose message from ' + agent(p.sender).name + ' with content ' + p.contents;
			write '\t' + name + ' sends a reject_proposal message to ' + p.sender;
			do reject_proposal with: [message:: p, contents::['Sorry, you were late in proposing.']];
		}

		write '(Time ' + time + '): ' + name + ' terminates auction.\n';
		do start_conversation with: [to::list(buyers), protocol::'fipa-contract-net', performative::'inform', contents::['Auction terminates.']];
		start_auction <- false;
		buyers <- [];
		attenders <- 0;
	}

	reflex send_cfp_to_participants when: no_bid {
		write '(Time ' + time + '): ' + name + ' sends a cfp message to all participants';
		item_price <- item_price - price_cut;
		do start_conversation with: [to::list(buyers), protocol::'fipa-contract-net', performative::'cfp', contents::['T-shirts', item_price]];
		no_bid <- false;
	}

	// Display character of the guest.
	aspect range {
		draw circle(12) color: #orange border: #black;
	}

	aspect icon {
		draw my_icon size: 7 * icon_size;
	}

}

// Experiment.
experiment festival type: gui {
	output {
	// Display map.
		display myDisplay type: opengl {
			species Initiator aspect: range;
			species Initiator aspect: icon;
			species Participant aspect: icon;
		}

	}

}
