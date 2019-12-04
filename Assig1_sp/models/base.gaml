/*
 * ID2209 Distributed Artificial Intelligence and Intelligent Agents
 * Assignment 1
 * @author: Sumit Patidar <patidar@kth.se>, Utkarsh Kunwar <utkarshk@kth.se>
 * 
 */
model base

global {
	float worldDimension <- 100 #m;
	geometry worldShape <- square(worldDimension);
	float step <- 1 #s;

	// Globals for people.
	float max_hunger <- 1.0;
	float max_thirst <- 1.0;
	float hunger_consum <- 0.00001;
	float thirst_consum <- 0.00001;
	float move_speed <- 0.005;
	float dance_speed <- 0.01;

	// Globals for buildings.
	point informationCentrePoint <- {worldDimension / 2.0, worldDimension / 2.0};

	init {
		seed <- #pi / 5; // Looked good.
		create FestivalGuest number: 10;
		create InformationCentre number: 1 with: (name: "InformationCentre", location: informationCentrePoint);
	}

	int max_cycles <- 300000;

	reflex stop when: cycle = max_cycles {
		write "Paused.";
		do pause;
	}

}

species FestivalGuest skills: [moving] {
// Display icon of the person.
	image_file my_icon <- image_file("../includes/data/dance.png");
	float icon_size <- 1 #m;

	/*
     * Icon statuses to avoid changing icon at every step and decrease
     * rendering overhead.
     * 0 : Dancing
     * 1 : Hungry
     * 2 : Thirsty
     */
	int icon_status <- 0;

	aspect icon {
		draw my_icon size: 7 * icon_size;
	}

	// Hunger and thirst updates.
	float hunger <- rnd(max_hunger) update: hunger + hunger_consum max: max_hunger;
	float thirst <- rnd(max_thirst) update: thirst + thirst_consum max: max_thirst;
	point targetPoint <- nil;
	bool hungry <- false;
	bool thirsty <- false;
	bool moving <- false;
	bool at_info <- false;
	bool at_store <- false;
	point foodPoint <- nil;
	point drinksPoint <- nil;
	point random_point <- nil;
	float distance_travelled <- 0.0;

	// Caluclates the distance travelled by the person.
	reflex calculateDistance when: moving {
		distance_travelled <- distance_travelled + move_speed * step;
	}

	// Check if hungry or not. Change icon accordingly. Don't change priority if already doing something.
	reflex isHungry when: !(thirsty or moving) {
		if hunger = 1.0 {
			hungry <- true;
			if icon_status != 1 {
				my_icon <- image_file("../includes/data/hungry.png");
				icon_status <- 1;
			}

		} else {
			hungry <- false;
			if icon_status != 0 {
				my_icon <- image_file("../includes/data/dance.png");
				icon_status <- 0;
			}

		}

	}

	// Check if thirsty or not. Change icon accordingly. Don't change priority if already doing something.
	reflex isThirsty when: !(hungry or moving) {
		if thirst = 1.0 {
			thirsty <- true;
			if icon_status != 2 {
				my_icon <- image_file("../includes/data/thirsty.png");
				icon_status <- 2;
			}

		} else {
			thirsty <- false;
			if icon_status != 0 {
				my_icon <- image_file("../includes/data/dance.png");
				icon_status <- 0;
			}

		}

	}

	// Dance.
	reflex dance when: targetPoint = nil and !(hungry or thirsty) {
		do wander speed: dance_speed bounds: square(0.1 #m);
		moving <- false;
	}

	// Move to a given point.
	reflex moveToTarget when: targetPoint != nil {
		do goto target: targetPoint speed: move_speed;
		moving <- true;
	}

	// Go to information centre if hungry or thirsty. And not moving could also be checked
	reflex goToInformationCentre when: (hungry or thirsty) and !at_info {
		targetPoint <- informationCentrePoint;
	}

	// Check if at information centre.
	reflex atInformationCentre when: (hungry or thirsty) and !at_info and location distance_to (informationCentrePoint) < 2 and !at_store {
		at_info <- true;
		moving <- false;
		write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") At Information Centre";
	}

	// Get store location from information centre.
	reflex getStoreLocation when: (hungry or thirsty) and at_info and !at_store {
		ask InformationCentre {
			if myself.hungry and myself.foodPoint = nil {
				myself.foodPoint <- any(self.foodPoints);
				myself.targetPoint <- myself.foodPoint;
				write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + ") Got Food Point";
			}

			if myself.thirsty and myself.drinksPoint = nil {
				myself.drinksPoint <- any(self.drinksPoints);
				myself.targetPoint <- myself.drinksPoint;
				write "Cycle (" + string(cycle) + ") Agent (" + string(myself.name) + ") Got Drinks Point";
			}

		}

	}

	// Check if at store and get food and replenish health at the food store.
	reflex atFoodStoreLocation when: hungry and at_info and foodPoint != nil and location distance_to (foodPoint) < 2 {
		at_store <- true;
		at_info <- false;
		moving <- false;
		hunger <- 0.0;
		hungry <- false;
		thirst <- thirst / 1.5; // When you're full you feel like drinking less.
		thirsty <- false;
		foodPoint <- nil;
		random_point <- {rnd(worldDimension), rnd(worldDimension)};
		targetPoint <- random_point;
		write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") At Food Point";
	}

	// Check if at store and get drinks and replenish health at the drinks store.
	reflex atDrinksStoreLocation when: thirsty and at_info and drinksPoint != nil and location distance_to (drinksPoint) < 2 {
		at_store <- true;
		at_info <- false;
		moving <- false;
		thirst <- 0.0;
		thirsty <- false;
		hunger <- hunger / 2.0; // When you drink a lot you feel like eating less.
		hungry <- false;
		drinksPoint <- nil;
		random_point <- {rnd(worldDimension), rnd(worldDimension)};
		targetPoint <- random_point;
		write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") At Drinks Point";
	}

	// Check if at random point.
	reflex atRandomPoint when: at_store and random_point != nil and location distance_to (random_point) < 2 {
		at_store <- false;
		at_info <- false;
		moving <- false;
		random_point <- nil;
		targetPoint <- nil;
		write "Cycle (" + string(cycle) + ") Agent (" + string(name) + ") At Random Point";
	}

}

species InformationCentre {
// Display icon of the information centre.
	image_file my_icon <- image_file("../includes/data/information_centre.png");
	float icon_size <- 1 #m;

	aspect icon {
		draw my_icon size: 10 * icon_size;
	}

	// Parameters for stores.
	int nFoodPoints <- 2;
	int nDrinksPoints <- 2;
	list<point> foodPoints <- [];
	list<point> drinksPoints <- [];

	init {
	// Randomised locations.
		int i <- 1;
		loop i from: 1 to: nFoodPoints {
			point foodPoint <- {rnd(worldDimension), rnd(worldDimension)};
			foodPoints <+ foodPoint;
			point drinksPoint <- {rnd(worldDimension), rnd(worldDimension)};
			drinksPoints <+ drinksPoint;
			create FoodShop number: 1 with: (location: foodPoint);
			create DrinksShop number: 1 with: (location: drinksPoint);
		} } }

species FoodShop {
// Display icon of the food shop.
	image_file my_icon <- image_file("../includes/data/food.png");
	float icon_size <- 1 #m;

	aspect icon {
		draw my_icon size: 10 * icon_size;
	}

}

species DrinksShop {
// Display icon of the drinks shop.
	image_file my_icon <- image_file("../includes/data/drinks.png");
	float icon_size <- 1 #m;

	aspect icon {
		draw my_icon size: 10 * icon_size;
	}

}

experiment festival type: gui {
	output {
		display chart refresh: every(100 #cycles) {
			chart "Distance travelled for all agents." type: histogram {
				datalist (FestivalGuest collect each.name) value: FestivalGuest collect each.distance_travelled;
			}

		}

		display myDisplay type: opengl {
			species FestivalGuest aspect: icon;
			species InformationCentre aspect: icon;
			species FoodShop aspect: icon;
			species DrinksShop aspect: icon;
		}

		inspect "distance inspector" value: FestivalGuest attributes: ["distance_travelled"];
	}

}