/***
* Name: auctions
* Author: sumitpatidar, utkarshkunwar
* Description: Assignment 2 for DAIIA
* Tags: Dutch-Auction, FIPA
***/
model challenge2

global {
	float worldDimension <- 100 #m;
	geometry worldShape <- square(worldDimension);
	float step <- 1 #s;
	int max_cycles <- 300000;

	//globals for guest
	int nb_guests <- 20;

	//globals for Initiator
	int nb_initiator <- 2;
	list<point> initiators_locs <- [];

	init {
		seed <- #pi / 5.5; // Looked good.
		create Participant number: nb_guests returns: ps;

		// Randomised locations for Initiator.
		int i <- 1;
		loop i from: 1 to: nb_initiator {
			point auction_point <- {rnd(worldDimension), rnd(worldDimension)};
			initiators_locs <+ auction_point;
			create Initiator number: 1 with: (location: auction_point, auction_type: 'English');
		}

		//		i <- 1;
		//		loop i from: 1 to: nb_initiator {
		//			point auction_point <- {rnd(worldDimension), rnd(worldDimension)};
		//			initiators_locs <+ auction_point;
		//			create Initiator number: 1 with: (location: auction_point, auction_type: 'Dutch');
		//		}
	}

	reflex stop when: cycle = max_cycles {
		write "Paused.";
		do pause;
	} }

	// --------------------------------------------------Festival Guests----------------------------------------------
species Participant skills: [moving, fipa] {

// moving variables
	point random_point <- nil;
	bool moving <- false;
	float move_speed <- 0.003;
	float guest_interaction_distance <- 2.0;
	int resting_cycles <- 5000;

	// Auction variables
	float auction_interaction_distance <- 10.0;
	point auction_point <- nil;
	int wallet_money <- rnd(500, 4000);
	bool attend_auction <- flip(0.5);
	bool at_auction <- false;
	bool informed_attendance <- false;
	Initiator auctioneer <- nil;
	string genre_interested_in <- any('T-shirts', 'CDs'); // 1: T-shirts, 2: CD's
	list<string> items_bought <- nil;
	string auction_type_interest <- any('Dutch', 'English');
	bool accepted_invitation_to_auction <- false;

	// Explore the fest.
	reflex setrandomPoint when: mod(cycle, resting_cycles) = 0 and !moving and !at_auction {
		random_point <- {rnd(worldDimension), rnd(worldDimension)};
	}

	// Check if at random point.
	reflex reachedrandomPoint when: random_point != nil and location distance_to (random_point) < guest_interaction_distance and moving {
		moving <- false;
		random_point <- nil;
	}

	// Move to random point.
	reflex moveToRandomPoint when: random_point != nil {
		do goto target: random_point speed: move_speed;
		moving <- true;
	}

	// Change interest to join auction with time.
	reflex joinAuction when: (mod(int(time), 50000) = 1) and !at_auction and !accepted_invitation_to_auction {
		attend_auction <- flip(0.5);
		auction_type_interest <- any('Dutch', 'English');
	}
	// Move to auction point.
	reflex moveToAuctionPoint when: auction_point != nil {
		do goto target: auction_point speed: move_speed;
		moving <- true;
	}

	// Check if reached auction point.
	reflex reachedAuctionPoint when: auction_point != nil and location distance_to (auction_point) < auction_interaction_distance and !at_auction {
		write '(Time ' + time + '): ' + name + ' reached auction.';
		moving <- false;
		auction_point <- nil;
		at_auction <- true;
	}

	// Read inform msgs from initiator.
	reflex receive_inform_messages when: !empty(informs) {
	//write 'time : ' + time + name + ' informs: ' + informs;
		message informationFromInitiator <- informs[0];

		// Reset parameters when auction terminates
		if (informationFromInitiator.contents[0] = 'Auction terminates.') {
		//write '\t' + name + ' receives a inform message from ' + agent(informationFromInitiator.sender).name + ' with content ' + informationFromInitiator.contents;
		//write '\t' + name + ' leaves auction.';
			auction_point <- nil;
			moving <- false;
			at_auction <- false;
			informed_attendance <- false;
			auctioneer <- nil;
			accepted_invitation_to_auction <- false;
		} else { // Join only one auction at a time
			if (auctioneer = nil) {
			//write '\t' + name + ' receives a inform message from ' + agent(informationFromInitiator.sender).name + ' with content ' + informationFromInitiator.contents;
				if (attend_auction and genre_interested_in = informationFromInitiator.contents[2] and informationFromInitiator.contents[0] = auction_type_interest) { // if interested then attend auction.
				//write '\t' + name + ' accept the invitation from ' + Initiator(informationFromInitiator.sender) + '.\n';
					do inform with: [message:: informationFromInitiator, contents::['I will join.', 'My interest', auction_type_interest, genre_interested_in]];
					accepted_invitation_to_auction <- true;
					auctioneer <- Initiator(informationFromInitiator.sender);
					auction_point <- agent(informationFromInitiator.sender).location;
					random_point <- nil;
				} else { // if not interested then refuse to participate.
				//write '\t' + name + ' receives a inform message from ' + agent(informationFromInitiator.sender).name + ' with content ' + informationFromInitiator.contents;
				//write '\t' + name + ' refuse the invitation.\n';
					do inform with: [message:: informationFromInitiator, contents::['I am not interested.']];
				}

			}

		}

	}

	// Inform the initiator about self presence at auction once.
	reflex inform_auctioneer_to_begin when: at_auction and !informed_attendance {
		do start_conversation with: [to::list(auctioneer), protocol::'fipa-contract-net', performative::'inform', contents::['I am here.']];
		informed_attendance <- true;
	}

	// Read call for proposals from initiator.
	reflex receive_cfp_from_initiator when: !empty(cfps) and auction_type_interest = 'Dutch' {
		message proposalFromInitiator <- cfps[0];
		//write '(Time ' + time + '): ' + name + ' receives a cfp message from ' + agent(proposalFromInitiator.sender).name + ' with content ' + proposalFromInitiator.contents;
		int proposed_price <- int(proposalFromInitiator.contents[1]);
		if (proposed_price > wallet_money) {
		//write '\t' + name + ' sends a refuse message to ' + agent(proposalFromInitiator.sender).name;
			do refuse with: [message:: proposalFromInitiator, contents::['I am willing to buy for', wallet_money]];
		} else {
		//write '\t' + name + ' sends a propose message to ' + agent(proposalFromInitiator.sender).name;
			do propose with: [message:: proposalFromInitiator, contents::['I will buy ', proposalFromInitiator.contents[0], proposed_price, 'I have ', wallet_money]];
		}

	}

	reflex receive_reject_proposals when: !empty(reject_proposals) and auction_type_interest = 'Dutch' {
		message r <- reject_proposals[0];
		write '(Time ' + time + '): ' + name + ' receives a reject_proposal message from ' + agent(r.sender).name + ' with content ' + r.contents;
	}
	//

	// Read accept proposals from initiator.
	reflex receive_accept_proposals when: !empty(accept_proposals) and auction_type_interest = 'Dutch' {
		message a <- accept_proposals[0];
		//write '(Time ' + time + '): ' + name + ' receives a dutch accept_proposal message from ' + agent(a.sender).name + ' with content ' + a.contents;
		wallet_money <- wallet_money - int(a.contents[1]); // Update wallet money after buying
		items_bought <+ string(a.contents[0]) + ' for ' + string(a.contents[1]) + ' from Dutch Auction.';
	}

	//----------------------------------------------Festival Guest: For English Auction------------------------------------------------
	// Read call for proposals from initiator.
	reflex receive_cfp_from_initiator_english when: !empty(cfps) and auction_type_interest = 'English' {
		message proposalFromInitiator <- cfps[0];
		//write '(Time ' + time + '): ' + name + ' receives a cfp message from ' + agent(proposalFromInitiator.sender).name + ' with content ' + proposalFromInitiator.contents;
		int proposed_price <- int(proposalFromInitiator.contents[1]);
		if (proposed_price > wallet_money) {
		//write '\t' + name + ' sends a refuse message to ' + agent(proposalFromInitiator.sender).name;
			do refuse with: [message:: proposalFromInitiator, contents::['I am only willing to spend', wallet_money]];
		} else {
		//write '\t' + name + ' sends a propose message to ' + agent(proposalFromInitiator.sender).name;
			do propose with:
			[message:: proposalFromInitiator, contents::['I propose to raise the bidding price for', proposalFromInitiator.contents[0], proposed_price, 'I have ', wallet_money]];
		}

	}

	// Update wallet money for English Auction
	reflex recive_request_from_english when: !empty(requests) and auction_type_interest = 'English' {
		message requestFormInitiator <- requests[0];
		wallet_money <- wallet_money - int(requestFormInitiator.contents[1]); // Update wallet money after buying
		items_bought <+ string(requestFormInitiator.contents[0]) + ' for ' + string(requestFormInitiator.contents[1]) + ' from English Auction.';
	}

	// Read accept proposals from initiator.
	reflex receive_accept_proposals_english when: !empty(accept_proposals) and auction_type_interest = 'English' {
		message a <- accept_proposals[0];
		write '(Time ' + time + '): ' + name + ' receives a English accept_proposal message from ' + agent(a.sender).name + ' with content ' + a.contents;
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

// auction variables
	string item_for_sale <- nil;
	int item_initial_price <- 0; // starting price to sell
	int current_price <- 0;
	int reserved_price <- 0; // will not go below this price
	int min_participants <- 2;
	bool start_auction <- false; // indicator if auction is started
	int price_cut <- 0;
	bool no_bid <- false;
	int attenders <- 0; // nb of buyers present at auction
	list<Participant> buyers <- []; // list of buyers who accepted invitation to join auction
	string genre_offered <- any('T-shirts', 'CDs'); // 1: T-shirts, 2: CD's
	bool genre_decided <- false;
	// icon varibles
	image_file my_icon <- nil;
	float icon_size <- 2 #m;
	int icon_status <- 0;
	string auction_type <- nil; // 1: Dutch, 2: English, 3: Sealed-bid
	list<rgb> mycolors <- [rgb(93, 138, 233, 100), rgb(240, 160, 55, 100)];
	string auction_title <- "Preparing...";
	rgb auction_color <- mycolors[0];

	reflex decideGenre when: !genre_decided {

	// sell T-shirts
		if (genre_offered = 'T-shirts') {
			auction_color <- mycolors[0];
			item_for_sale <- 'Signed T-shirts';
			if (auction_type = 'Dutch') {
				auction_title <- "Dutch:\nSigned T-shirts";
				item_initial_price <- 4999;
			} else if (auction_type = 'English') {
				auction_title <- "English:\nSigned T-shirts";
				item_initial_price <- 1999;
			}

			reserved_price <- 2999;
			price_cut <- rnd(300, 500);
			genre_decided <- true;
		} else if (genre_offered = 'CDs') { //sell cd's
			auction_color <- mycolors[1];
			item_for_sale <- 'CDs';
			if (auction_type = 'Dutch') {
				auction_title <- "Dutch:\nCDs";
				item_initial_price <- 999;
			} else if (auction_type = 'English') {
				auction_title <- "English:\nCDs";
				item_initial_price <- 199;
			}

			reserved_price <- 299;
			price_cut <- rnd(30, 100);
			genre_decided <- true;
		}

	}

	// Send invitation to all guests in the festival to join auction.
	reflex informParticipantsAuction when: mod(int(time), 50000) = 0 and !start_auction {
		write '\n(Time ' + time + '): ' + name + ' sends a invitation to all Participants';
		do start_conversation with: [to::list(Participant), protocol::'fipa-contract-net', performative::'inform', contents::[auction_type, item_for_sale, genre_offered]];
	}

	// Read inform msgs from participants. 
	reflex receive_inform_messages when: !empty(informs) {
		write '\n(Time ' + time + '): ' + name + ' receives inform messages';
		loop i over: informs {
			write '\t' + name + ' receives a inform message from ' + agent(i.sender).name + ' with content ' + i.contents;

			// Participants willing to join auction.
			if (i.contents[0] = 'I will join.') {
				buyers <+ Participant(agent(i.sender));
			}

			// if participants reached auction, count them in.
			if (i.contents[0] = 'I am here.') {
				attenders <- attenders + 1;
			}

		}

		if (length(buyers) >= min_participants) {
			write '\n(Time ' + time + '): ' + name + ' will begin auction shortly.';
			//write 'buyers: ' + length(buyers) + 'attenders: ' + attenders + start_auction;
			//start_auction <- true;
			//do start_conversation with: [to::list(buyers), protocol::'fipa-contract-net', performative::'cfp', contents::['T-shirts', item_initial_price]];
		} else {

		// End auction if less number of participants.
			if (!empty(buyers)) {
			//write 'informs: ' + informs;
				write '(Time ' + time + '): ' + name + ' terminates auction becaues of less participants.\n';
				do start_conversation with: [to::buyers, protocol::'fipa-contract-net', performative::'inform', contents::['Auction terminates.', 'less number of participants']];
				start_auction <- false;
				buyers <- [];
			}

		}

	}
	//---------------------------------------------------Dutch Auction----------------------------------------------------

	// Start auction by sending first initial price of item to all participants.
	reflex first_cfp when: (attenders = length(buyers)) and attenders != 0 and !start_auction and auction_type = 'Dutch' {
		start_auction <- true;
		current_price <- item_initial_price;
		write '\n(Time ' + time + '): ' + name + ' sends a cfp message to all participants';
		do start_conversation with: [to::buyers, protocol::'fipa-contract-net', performative::'cfp', contents::[item_for_sale, item_initial_price]];
	}

	// Read refuses from participants.
	reflex receive_refuse_messages when: !empty(refuses) and auction_type = 'Dutch' {
		if (length(refuses) = length(buyers)) {
			no_bid <- true;
			write '\n(Time ' + time + '):' + 'No one is willing to buy.';
		}

		write '\n(Time ' + time + '): ' + name + ' receives refuse messages';
		loop r over: refuses {
			write '\t' + name + ' receives a refuse message from ' + agent(r.sender).name + ' with content ' + r.contents;
		}

	}

	// Read the proposals from participants. Proposal here means, they agree to buy for current price.
	reflex receive_propose_messages when: !empty(proposes) and auction_type = 'Dutch' {

	// Sell the item based on first come first serve.
	// First proposal wins while other all get rejected by initiator.
		message first_proposal <- proposes[0];
		write '\n(Time ' + time + '): ' + name + ' receives propose messages';
		write '\t' + name + ' receives a propose message from ' + agent(first_proposal.sender).name + ' with content ' + first_proposal.contents;
		write '\t' + name + ' sends a accept_proposal message to ' + first_proposal.sender;
		do accept_proposal with: [message:: first_proposal, contents::[first_proposal.contents[1], first_proposal.contents[2]]];

		// Rejects all the remaining proposals
		loop p over: proposes {
			write '\t' + name + ' receives a propose message from ' + agent(p.sender).name + ' with content ' + p.contents;
			write '\t' + name + ' sends a reject_proposal message to ' + p.sender;
			do reject_proposal with: [message:: p, contents::['Sorry, you were late in proposing.']];
		}

		// Item is sold, hence terminate auction.
		write '\n(Time ' + time + '): ' + name + ' terminates auction.';
		do start_conversation with:
		[to::buyers, protocol::'fipa-contract-net', performative::'inform', contents::['Auction terminates.', agent(first_proposal.sender).name + ' buys the ' + first_proposal.contents[1]]];
		start_auction <- false;
		buyers <- [];
		attenders <- 0;
	}

	// Send new price to all participants.
	reflex send_cfp_to_participants when: no_bid and auction_type = 'Dutch' {
		write '\n(Time ' + time + '): ' + name + ' sends a cfp message to all participants';
		current_price <- current_price - price_cut;
		if (item_initial_price >= reserved_price) {

		// Reduce price by some fixed amount.
			do start_conversation with: [to::buyers, protocol::'fipa-contract-net', performative::'cfp', contents::[item_for_sale, current_price]];
		} else {

		// If price go below reserved price, then terminate auction.
			do start_conversation with: [to::buyers, protocol::'fipa-contract-net', performative::'inform', contents::['Auction terminates.', 'Reserved price is reached.']];
			start_auction <- false;
			buyers <- [];
			attenders <- 0;
		}

		no_bid <- false;
	}
	// --------------------------------------------------English Auction--------------------------------------------------
	Participant potential_buyer <- nil;
	bool result_time <- false;
	// Start auction by sending first initial price of item to all participants.
	reflex first_cfp_english when: (attenders = length(buyers)) and attenders != 0 and !start_auction and auction_type = 'English' {
		start_auction <- true;
		current_price <- item_initial_price;
		write '\n(Time ' + time + '): ' + name + ' sends a cfp message to all participants';
		do start_conversation with: [to::buyers, protocol::'fipa-contract-net', performative::'cfp', contents::[item_for_sale, item_initial_price]];
	}

	// Read the proposals from participants. Proposal here means, they agree to buy for current price.
	// Raise the price if there is atleast one proposal
	reflex receive_propose_messages_english when: !empty(proposes) and auction_type = 'English' {
		message first_proposal <- proposes[0];
		potential_buyer <- Participant(first_proposal.sender);
		write '\n(Time ' + time + '): ' + name + ' receives propose messages';

		// Accept all the proposals to raise price
		loop p over: proposes {
			write '\t' + name + ' receives a propose message from ' + agent(p.sender).name + ' with content ' + p.contents;
			//write '\t' + name + ' sends a accept_proposal message to ' + p.sender;
			do accept_proposal with: [message:: p, contents::[p.contents[1], p.contents[2]]];
		}
		// send new increased price to all buyers
		current_price <- current_price + price_cut;
		do start_conversation with: [to::buyers, protocol::'fipa-contract-net', performative::'cfp', contents::[item_for_sale, current_price]];

		// Item is sold, hence terminate auction.
		//		write '\n(Time ' + time + '): ' + name + ' terminates auction.';
		//		do start_conversation with:
		//		[to::buyers, protocol::'fipa-contract-net', performative::'inform', contents::['Auction terminates.', agent(first_proposal.sender).name + ' buys the ' + first_proposal.contents[1]]];
		//		start_auction <- false;
		//		buyers <- [];
		//		attenders <- 0;
	}

	// Read refuses from participants.
	reflex receive_refuse_messages_english when: !empty(refuses) and auction_type = 'English' {
		if (length(refuses) = length(buyers)) {
			result_time <- true;
			write '\n(Time ' + time + '):' + 'No proposals for English Auction. All refuse.';
		}

		write '\n(Time ' + time + '): ' + name + ' receives refuse messages';
		loop r over: refuses {
			write '\t' + name + ' receives a refuse message from ' + agent(r.sender).name + ' with content ' + r.contents;
		}

	}

	// Declare winner and terminate auction
	reflex declare_winner_english when: result_time and auction_type = 'English' {
		if (potential_buyer = nil) {
			write 'English auction terminates. No one to bid.\n';
			do start_conversation with: [to::buyers, protocol::'fipa-contract-net', performative::'inform', contents::['Auction terminates.', 'No one bid.']];
		} else if ((current_price - price_cut) < reserved_price) {
			write 'English auction terminates. Price is below reserved price.\n';
			do start_conversation with: [to::buyers, protocol::'fipa-contract-net', performative::'inform', contents::['Auction terminates.', 'Reserved price not reached.']];
		} else {

		// request the winner to take the item
			do start_conversation with:
			[to::list(potential_buyer), protocol::'fipa-contract-net', performative::'request', contents::[item_for_sale, current_price - price_cut, 'Please take it.']];
			// inform all about the results
			do start_conversation with:
			[to::buyers, protocol::'fipa-contract-net', performative::'inform', contents::['Auction terminates.', potential_buyer.name, ' buys the ', item_for_sale, ' for ', current_price - price_cut]];
		}

		start_auction <- false;
		buyers <- [];
		attenders <- 0;
		potential_buyer <- nil;
		result_time <- false;
	}
	// Display character of the guest.
	aspect range {
		draw circle(12) color: auction_color;
	}

	aspect icon {
		draw my_icon size: 7 * icon_size;
	}

	aspect text {
		draw auction_title color: #black size: 5;
	}

}

// Experiment.
experiment challenge2 type: gui {
	output {
	// Display map.
		display challenge2 type: opengl {
			species Initiator aspect: range;
			species Initiator aspect: text;
			species Participant aspect: icon;
		}

		// Inspect the wallet money of agents live
		inspect "Auction spendings" value: Participant attributes: ["wallet_money", "items_bought", "auction_type_interest", "genre_interested_in"];
	}

}