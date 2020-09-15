model CityofBoston

global {
	/*************************** Shape Files  ********************************************/
	file roads_shapefile parameter: "Shapefile for the roads:" category: "GIS" <- file("../includes/SeaPort/Boston_Segments.shp");
	file sidewalks_shapefile parameter: "Shapefile for the side walks:" category: "GIS" <- file("../includes/SeaPort/Sidewalk_Centerline.shp");
	file traffic_shapefile parameter: "Shapefile for the traffic lights:" category: "GIS" <- file("../includes/SeaPort/Traffic_Lights_Detailed_2.shp");
	file mbtastops_shapefile parameter: "Shapefile for the MBTA and bus stops:" category: "GIS" <- file("../includes/SeaPort/MBTA_Stops.shp");
	file ped_dest_shapefile parameter: "Shapefile for the pedestrians destination:" category: "GIS" <- file("../includes/SeaPort/RandomODPoints.shp");
	file busstops_shapefile parameter: "Shapefile for the bus stops:" category: "GIS" <- file("../includes/SeaPort/Route_04_742_Stops_PointFeatures/Route_04_742_Stops_PointFeatures.shp");
	file busrouts_shapefile parameter: "Shapefile for the bus routes:" category: "GIS" <- file("../includes/SeaPort/Route_04_742_Lines_PointFeatures/Route_04_742_Lines_PointFeatures.shp");
	file buslines_csvfile <- csv_file("../includes/SeaPort/BusLines.csv", true);
	file busstops_csvfile <- csv_file("../includes/SeaPort/AllSeaPortBuseStops.csv", true);
	
	/*************************** Image Files ***********************************************/
	file busstops_imagefile <- image_file("../includes/SeaPort/BusStopImage.png");
	file mbtastations_imagefile <- image_file("../includes/SeaPort/TrainStation.png");
	
	/*************************** Simulation Core Parameters *****************************/
	float step <- 0.05 #mn parameter: "Simulation Time Step (1 Cycle per Secs)" category: "Core Simulation" ;
	int SimDurationInWeeks <-5 parameter: "Simulation Running Duration (Weeks)" category: "Core Simulation" min:1 max:52;
	date starting_date <- date("now");
	reflex pause_simulation when: (current_date - starting_date) >= SimDurationInWeeks*7*24*3600 {
		write current_date;
		do pause;
	}
	
	/*************************** General Parameters  *************************************/
	float BusAveSpeed <- 30.0 parameter: "Average Bus Speed (mph)" category: "Agents Speed and Time Paramemters" ;
	float BusStdSpeed <- 0.0 parameter: "Std Dev Bus Speed (mph)" category: "Agents Speed and Time Paramemters";
	float DeliveryTruckAveSpeed <- 15.0 parameter: "Average Delivery Truck Speed (mph)" category: "Agents Speed and Time Paramemters" ;
	float DeliveryTruckStdSpeed <- 0.0 parameter: "Std Dev Delivery Truck Speed (mph)" category: "Agents Speed and Time Paramemters";
	float PersonalCarAveSpeed <- 30.0 parameter: "Average Personal Cars Speed (mph)" category: "Agents Speed and Time Paramemters";
	float PersonalCarStdSpeed <- 0.0  parameter: "Std Dev Personal Cars Speed (mph)" category: "Agents Speed and Time Paramemters";
	float UberTaxiAveSpeed <- 30.0 parameter: "Average Uber/Taxi Speed (mph)" category: "Agents Speed and Time Paramemters";
	float UberTaxiStdSpeed <- 0.0 parameter: "Std Dev Uber/Taxi Speed (mph)" category: "Agents Speed and Time Paramemters";
	float PedestrianAveMovingSpeed <- 2.0 parameter: "Average Pedestrians Speed (mph)" category: "Agents Speed and Time Paramemters";
	float PedestrianStdMovingSpeed <- 0.0 parameter: "Std Dev Pedestrians Speed (mph)" category: "Agents Speed and Time Paramemters";
	//The value might be 200 as the initial synatx was "int TrafficLightTime2Change <- 200 parameter: "Traffic Light Phase Length" category: "Speed and Time Paramemters" min: 1 max: 200 init:100; " depending who was the first init...
	int TrafficLightTime2Change <- 100 parameter: "Traffic Light Phase Length" category: "Speed and Time Paramemters" min: 1 max: 200; 
	int BusMinStopTime parameter: " Buses Minimum Stop Time" category: "Agents Speed and Time Paramemters" min: 0 max: 200 init:60;
	int BusMaxStopTime parameter: " Buses Maximum Stop Time" category: "Agents Speed and Time Paramemters" min: 0 max: 200 init:60;

	/*************************** Reporting Parameters ***********************************/
	float uber_total_traveled_distance;
	float bus_total_traveled_distance;
	float personal_car_total_traveled_distance;
	float uber_average_speed;
	float personal_car_average_speed;
	float regular_bus_average_speed;
	
	reflex Reporting_KPIs{
		uber_total_traveled_distance <-  sum(uber_car collect each.distance_traveled);
		bus_total_traveled_distance <-  sum(regular_buses collect each.distance_traveled);
		personal_car_total_traveled_distance <- sum(personal_car collect each.distance_traveled);
		uber_average_speed <- mean(uber_car collect each.speed);
		personal_car_average_speed <- mean(personal_car collect each.speed);
		regular_bus_average_speed <- mean(regular_buses collect each.speed);
	}
	
	/*************************** Agent Population Parameters  ***************************/
	file time_dest_csvfile <- csv_file("../includes/MassDOTTrafficCounts.csv", true);
	matrix creation_cycle <- matrix(time_dest_csvfile);
	
	int nb_ped parameter: "Total Population of Pedestrians" category: "Agents Population" min: 1 max: 500 init:10;
	int nb_ped_uber parameter: "Total Population of Uber Pedestrians" category: "Agents Population" min: 1 max: 300 init:100;
	int nb_personal_cars parameter: "Total Population of Personal Cars" category: "Agents Population" min: 1 max: 500 init:10;
	int nb_uber_cars parameter: "Total Population of Uber Cars " category: "Agents Population" min: 1 max: 300 init:100;
	int nb_bus parameter: "Total Population of Buses per Route" category: "Agents Population" min: 1 max: 100 init:1 ;	
	int nb_delivery_trucks parameter: "Total Population of Delivery Trucks " category: "Agents Population" min: 1 max: 100 init:3 ;
		
	/*************************** Global Parameters *****************************/
	geometry shape <- envelope(roads_shapefile);
	graph the_graph;
	graph the_ped_graph;
	graph the_bus_route;
	
	int total_traffic_light_clusters;
	
	list<traffic_light> traffic_signals;
	list<traffic_light> cycle_1_traffic_signals;
	list<traffic_light> cycle_2_traffic_signals;
	list<int> temp;
	list<point> bus_nodes;
	list<int> unique_routes <- remove_duplicates(bus_lines column_at 4 accumulate each) ;
	list<point> BusRoute;
	list<agent> pedestrians_crossing_road;
	list<point> ped_origins;
	list<point> ped_destinations;
	list<point> nodes;
	
	matrix bus_lines <- matrix(buslines_csvfile);
	matrix bus_stops <- matrix(busstops_csvfile);
	matrix bus_paths <- nil as_matrix({4, length(unique_routes)});
	
	/*************************** Initiating Agents *****************************/
	init{	
		create traffic_light from: traffic_shapefile with:[is_traffic_light::true, objectid::int(read('OBJECTID'))
			, sequence::int(read('sequence')), cluster::int(read('cluster')), cycle::int(read('cycle'))
			, crosswalk::int(read('crosswalk'))]{
				sequence <- self.sequence;
				cluster <- self.cluster;
				cycle <- self.cycle;
				crosswalk <- self.crosswalk;
				temp <- self.cluster;
		}
		total_traffic_light_clusters <- max(temp);
		do init_traffic_signal;
		
		create mbta_stations from: mbtastops_shapefile{
			shape <- circle (5#px);
		}
		
		create dummy_node from: traffic_shapefile;
		nodes <- dummy_node collect each.location;
	
		loop i from:0 to: bus_stops.rows-1{
			add point(to_GAMA_CRS({float(bus_stops[8, i]), float(bus_stops[7, i])}, "EPSG:4326")) to: bus_nodes;
		}
	
		create busnodes from: busstops_shapefile;
		create ped_dest from: ped_dest_shapefile with:[type::string(read('Type'))]{
			shape <- circle (5#px);
			type <- self.type;
			switch type {
				match 'Destination'{
					if not (location in nodes){create dummy_node with:[location::location]; nodes << location.points;}
					add location to:ped_destinations;
				}
				match 'Origin'{
					add location to:ped_origins;
				}
			}
		}
		
		create road from: roads_shapefile with:[speed_limit::float(read('SPEEDLIMIT'))
			, oneway::string(read('OPPOSITENU')), lanes::int(read('NUMBEROFTR'))]{
			lanes <- max([1,lanes]);
			maxspeed <-  max([20,speed_limit]) #miles/#hour;
			point fp <- first(shape.points);
			point lp <- last(shape.points);
			if not (fp in nodes) {create dummy_node with:[location::fp]; nodes << fp;}
			if not (lp in nodes) {create dummy_node with:[location::lp]; nodes << lp;}
			switch oneway {
				match_one [1,2] {
					create road {
						lanes <- myself.lanes;
						shape <- polyline(reverse(myself.shape.points));
						maxspeed <- max([20,speed_limit]) #miles/#hour;
						road_geom_shape <- myself.road_geom_shape;
						linked_road <- myself;
						myself.linked_road <- self;
					}
					lanes <- int(lanes /2.0 + 0.5);
				}
			}
		}
		ask road as list {
			road_geom_shape <- shape + (2*lanes);
		}
		
		map general_speed_map <- road as_map (each::(each.shape.perimeter / each.maxspeed));
		the_graph <- directed(as_driving_graph(road, dummy_node)) with_weights general_speed_map;
		
		create personal_car number: nb_personal_cars{
			shape <- circle (5#px);
			vehicle_length <- 4.0 ;
			right_side_driving <- true;
			proba_lane_change_up <- 0.9 + (rnd(500) / 500);
			proba_lane_change_down <- 0.9 + (rnd(500) / 500);
			location <- any_location_in(one_of(the_graph));
			security_distance_coeff <- 5/9 * 3.6 * (1.5 - rnd(1000) / 1000);  
			proba_respect_priorities <- 1.0;
			proba_respect_stops <- 1.0;
			proba_block_node <- 0.0;
			proba_use_linked_road <- 0.0;
			max_acceleration <- 5/3.6;
			speed_coeff <- 1.2 - (rnd(400) / 1000);
			p_occupancy <- rnd(2,1);
			p_emission <- 50;
		}
		
		int temp <- 0;
		loop i over:unique_routes{
			BusRoute <- [];
			loop j from: 0 to: bus_lines.rows-1{
		 		if(i = int(bus_lines[4,j])){
		 			add point(to_GAMA_CRS({float(bus_lines[13, j]), float(bus_lines[12, j])}, "EPSG:4326")) to:BusRoute;
		 			point last_point <- point(to_GAMA_CRS({float(bus_lines[13, j]), float(bus_lines[12, j])}, "EPSG:4326"));
		 			bus_paths[3,temp] <- last_point;
		 		}
		 		if(i = int(bus_lines[4, j]) and int(bus_lines[11, j]) = 1){
		 			point first_point <- point(to_GAMA_CRS({float(bus_lines[13, j]), float(bus_lines[12, j])}, "EPSG:4326"));
		 			bus_paths[2,temp] <- first_point;	
		 		}
		 	}
		 	bus_paths[1,temp] <- path(BusRoute);
		 	bus_paths[0,temp] <- i;
		 	temp <- temp + 1;
		}

		loop i over: unique_routes{
			loop j from:0 to:bus_paths.rows-1{
				if(int(bus_paths[0, j]) = i){
					create regular_buses number: nb_bus{
						shape <- circle (5#px);
						r_b_occupancy <- 100;
						r_b_emission <- 500;
						point int_point <- bus_paths[2, j]; 
						location <- int_point.location;
						final_target <- bus_paths[3,j];
						bus_path <- bus_paths[1, j];
						vehicle_length <- 10.0 ;
						right_side_driving <- true;
						proba_lane_change_up <- 0.9 + (rnd(500) / 500);
						proba_lane_change_down <- 0.9 + (rnd(500) / 500);
						security_distance_coeff <- 5/9 * 3.6 * (1.5 - rnd(1000) / 1000);  
						proba_respect_priorities <- 1.0;
						proba_respect_stops <- 1.0;
						proba_block_node <- 0.0;
						proba_use_linked_road <- 0.0;
						max_acceleration <- 2.5/3.6;
						speed_coeff <- 1.2 - (rnd(400) / 1000);
					}
				}
			} 
		}
		
		create side_walks from: sidewalks_shapefile;
		ask side_walks as list{
			ped_geom_shape <- shape+(shape*2) ;
		}
		
		the_ped_graph <- as_edge_graph(side_walks);
		create pedestrians number: nb_ped{
			shape <- circle (5#px);
			ped_speed <- PedestrianAveMovingSpeed #mile/#hour;
			location <- any_location_in(one_of(the_ped_graph));
			the_target <- any_location_in(one_of(the_ped_graph));
		}
	
		create uber_pedestrians_population number:nb_ped_uber{
			shape <- circle (5#px);
			ped_speed <- PedestrianAveMovingSpeed #mile/#hour;
			location <- any_location_in(one_of(the_ped_graph));
			uber_ped_target <- one_of(ped_destinations);
		}
		create uber_car number:nb_uber_cars{
			shape <- circle (5#px);
			u_occupancy <- 4;
			u_emission <- 50;
			location <- any_location_in(one_of(the_graph));
			vehicle_length <- 4.0 ;
		}
		create delivery_trucks number:nb_delivery_trucks{
			shape <- circle(5#px);
			d_t_emission <- 500;
			location <- one_of(dummy_node);
			vehicle_length <- 14.0 ;
		}
	
	}
	
	action init_traffic_signal { 
		cycle_1_traffic_signals <- traffic_light where (each.is_traffic_light and each.cycle = 1) ;
		cycle_2_traffic_signals <- traffic_light where (each.is_traffic_light and each.cycle = 2) ;
		traffic_signals <- traffic_light where each.is_traffic_light ;
		ask traffic_signals {
			stop << [];
		}
		bool green <- flip(0.5);
		if(green){
			ask cycle_1_traffic_signals{
				do to_green; do compute_crossing;
			}
			ask cycle_2_traffic_signals{
				do to_red; do compute_crossing;
			}
		}else{
			ask cycle_2_traffic_signals{
				do to_green; do compute_crossing;
			}
			ask cycle_1_traffic_signals{
				do to_red; do compute_crossing;
			}
		}
	}
	
	int dummy_id <- 0;
	int dummy_day <- 0;
	int old_cycle_id <- 0;
	int new_cycle_id <- 0;
	float agent_quant;
	
	reflex agent_creation {
		loop i from: dummy_id to: creation_cycle.rows-1{
			old_cycle_id <- dummy_id;
			if(time/60 >= (int(creation_cycle[1, i]) + dummy_day*24*3600)){
				dummy_id <- creation_cycle[0, i];
				new_cycle_id <- dummy_id;
			}
			if(new_cycle_id > old_cycle_id){
				agent_quant <- creation_cycle[5, i];
				do create_agent;
			}
			if(dummy_id = creation_cycle.rows){
				dummy_day <- dummy_day + 1;
				dummy_id <- 1;
			}
		}
	}
	
	action create_agent{
		write" Agents of Type X are created";
		write "time " + time;
		write " Quantity " + agent_quant;
		write "Cycle " + cycle;
		write "Duration " + duration;
		write "Total Duration " + total_duration;
	}
	
}

species uber_car skills:[advanced_driving]{
	int u_occupancy <- 4;
	float u_emission;
	point uber_target;
	bool temp <- true;
	float UberSpeed;
	list temp_targets;
	path updated_path;
	point new_location;
	point past_location; 
	float distance_traveled;
	dummy_node target;
	
	reflex pick_up_passengers when:length(uber_passengers) <= u_occupancy {
		capture(u_occupancy - length(uber_passengers)) among uber_pedestrians_population at_distance 50 #ft as:uber_passengers;
		if(length(uber_passengers) > 0){
			//write self;
			//write "My number of passengers " + length(uber_passengers);
		}
	}
	
	reflex release_passengers {
		release uber_passengers where (each.uber_ped_target distance_to self.location <= 200 #ft);
	}
	
	reflex time_to_go when: final_target = nil{
		if(!empty(uber_passengers) = true){
			temp_targets <- (uber_passengers collect each.uber_ped_target);
			uber_target <- temp_targets closest_to (self.location);
			current_path <- compute_path(graph:the_graph, target:closest_to(dummy_node, uber_target), source: self.location);
			final_target <- closest_to(dummy_node, uber_target);
		}else{
			current_path <- compute_path (graph:the_graph, target: one_of(dummy_node), source: self.location);
			final_target <- one_of(dummy_node);
		}
		
		if(current_path = nil){
			final_target <- nil;
		}
		
		if(self.location = final_target){
			location <- any_location_in(one_of(the_graph));
		}
	}
	
	reflex move when : current_path != nil {			
		do uber_old_location;
		ask traffic_light at_distance(30 #ft){
			if(self.traffic_light_color = #green){
				myself.temp <- true;
			} else{
				myself.temp <- false;
			}
		}
		if(temp = true){
			ask road {
				if(myself.shape overlaps self.shape){
					myself.max_speed <- self.maxspeed;
					myself.speed <- gauss(UberTaxiAveSpeed, UberTaxiStdSpeed) #mile/#hour;
				}
			}
			do drive;
		}else{
			self.speed <- 0;
		}
		do uber_new_location;
	}
	
	action uber_old_location{
		past_location <- self.location;
	}
	action uber_new_location{
		new_location <- self.location;
		distance_traveled <- distance_to(past_location,new_location)/#mile;
	}
	
	species uber_passengers parent:uber_pedestrians_population{
		reflex move{
			location <- host.location;
		}
	}
	
	point calcul_loc{
		if(current_road = nil) {
			return location;
		} else {
			float val <- (road(current_road).lanes - current_lane) + 0.1;
			val <- on_linked_road ? val * - 1 : val;
			if (val = 0) {
				return location; 
			} else {
				return (location + {cos(heading + 90) * val, sin(heading + 90) * val});
			}
		}
	}
	
	aspect base3D{
		point loc <- calcul_loc();
		draw box(vehicle_length, 1.5, 2.0) at: loc rotate: heading color: #yellow;
		draw box(vehicle_length/2, 1.5, 3.0) at: loc rotate: heading color: #yellow;
		loop i over: uber_passengers{
			draw circle(0.4) depth: 2.5 at: loc rotate:  heading + 90 color: #black;
		}
	}
}

species uber_pedestrians_population skills:[moving]{
	float ped_speed <- PedestrianAveMovingSpeed;
	point uber_ped_target;
	
	reflex moving when: uber_ped_target != nil{
		do goto target: uber_ped_target on: the_ped_graph speed: ped_speed;
		if(uber_ped_target = location) {
			//uber_ped_target <- any_location_in(one_of(the_ped_graph));
			write "Uber Pedestrian Agent " + self +" has Arrived and Died";
			do die;
		}
	}
	
	aspect base3D{
		draw triangle(1.5) depth: 1.0 rotate: heading + 90 color: #green;
	}	
}

species pedestrians skills:[moving]{
	float ped_speed;
	point the_target <- nil;
	
	reflex moving when: the_target != nil{		
		do goto target: the_target on: the_ped_graph speed: ped_speed;
					
		if(the_target = location){
			write "Pedestrian Agent " + self +" has Arrived and Died";
			do die;
		}
	}

	aspect base3D{
		draw triangle(1.5) depth: 1.0 rotate: heading + 90 color: #black;
	}
}

species regular_buses skills:[moving, advanced_driving] {
	int r_b_occupancy;
	float r_b_emission;
	path bus_path;
	int counter_stucked <- 0;
	int threshold_stucked <- 2;
	int time_to_stop <- rnd(BusMaxStopTime, BusMinStopTime);
	bool temp <- true;
	int temp_counter <- 0;
	float BusSpeed;
	point past_location;
	point new_location;
	float distance_traveled;
	
	reflex move{
		ask traffic_light at_distance(2 #ft){
			if(self.traffic_light_color = #green){
				myself.temp <- true;
			} else{
				myself.temp <- false;
			}
		}
		
		ask busnodes at_distance(5.0 #ft){
			if(myself.temp_counter <= myself.time_to_stop){ 
				myself.temp <- false;
				myself.temp_counter <- myself.temp_counter + 1;
			} else{
				myself.temp <- true ;
				myself.temp_counter <- 0;
			}
		}
		do bus_old_location;
		if(temp = true){
			BusSpeed <- gauss(BusAveSpeed, BusStdSpeed) #mile/#hour ;
		}else{
			BusSpeed <- 0;
		}
		
		do follow path: bus_path speed: self.BusSpeed;
		do bus_new_location;
		
		if(location = final_target){
			do die;
		}
		
		if(real_speed < 5 #mile/#hour){
			counter_stucked <- counter_stucked + 1;
			if(counter_stucked mod threshold_stucked = 0){
				proba_use_linked_road <- min([1.0,proba_use_linked_road + 0.1]);
			}
		}else{
			counter_stucked <- 0;
			proba_use_linked_road <- 0.0;
		}
	}
		
		action bus_old_location{
			past_location <- self.location;
		}
		action bus_new_location{
			new_location <- self.location;
			distance_traveled <- distance_to(past_location,new_location)/#mile;
		}
		
		point calcul_loc{
			if(current_road = nil) {
				return location;
			} else {
				float val <- (road(current_road).lanes - current_lane) + 0.1;
				val <- on_linked_road ? val * - 1 : val;
				if (val = 0) {
					return location; 
				} else {
					return (location + {cos(heading + 90) * val, sin(heading + 90) * val});
				}
			}
		}
	
	aspect base3D{
		point loc <- calcul_loc();
		draw box(vehicle_length, 3,3) at: loc rotate: heading color: #purple;
		draw triangle(0.4) depth: 2.5 at: loc rotate:  heading + 90 color: #purple;
		}
}

species busnodes{
	aspect base3D{
		draw box(0.5,1.5,9) color:#black;
		draw box(2,2,2) at: {location.x,location.y,8} color: #yellow;
	}
}

species personal_car skills:[advanced_driving, driving]{
	int p_occupancy;
	float p_emission;
	int counter_stucked <- 0;
	int threshold_stucked <- 2;
	dummy_node target;
	bool temp <- true;
	float distance_traveled;
	point past_location;
	point new_location;
	
	reflex time_to_go when: final_target = nil {
		target <- one_of(dummy_node);
		current_path <- compute_path(graph: the_graph, target: target);
		if (current_path = nil) {
			final_target <- nil;
		}
	}
	
	reflex move when: current_path != nil and final_target != nil {
		do personal_car_old_location;
		ask traffic_light at_distance(2 #ft){
			if(self.traffic_light_color = #green){
				myself.temp <- true;
			} else{
				myself.temp <- false;
			}
		}
	
		if(temp = true){
			ask road{
				if(myself.shape overlaps self.shape){
					myself.max_speed <- self.maxspeed;
					myself.speed <- gauss(PersonalCarAveSpeed, PersonalCarStdSpeed) #mile/#hour;
				}
			}
			do drive;	
		}else{
			self.speed <- 0;
		}
		do personal_car_new_location;
		
		if(self.location = self.final_target) {
			//final_target <- nil;
			do die;
			write 'Personal Car Agent '+ self.name + ' Has Arrived to Its Destination and Died';
		}
		if real_speed < 5 #mile/#h {
			counter_stucked <- counter_stucked + 1;
			if (counter_stucked mod threshold_stucked = 0) {
				proba_use_linked_road <- min([1.0,proba_use_linked_road + 0.1]);
			}
		} else {
			counter_stucked <- 0;
			proba_use_linked_road <- 0.0;
		}
		
	}
	
	action personal_car_old_location{
		past_location <- self.location;
	}
	action personal_car_new_location{
		new_location <- self.location;
		distance_traveled <- distance_to(past_location,new_location)/#mile;
	}
	//list r <- agents_overlapping(self) of_species road;
	aspect base3D {
		point loc <- calcul_loc();
		draw box(vehicle_length, 2, 2) at: loc rotate:  heading color: #red;
		draw box(vehicle_length/2, 1.5, 3.0) at: loc rotate: heading color: #red;
	}
	
	point calcul_loc {
		if (current_road = nil) {
			return location;
		} else {
			float val <- (road(current_road).lanes - current_lane) + 0.5;
			val <- on_linked_road ? val * - 1 : val;
			if (val = 0) {
				return location; 
			} else {
				return (location + {cos(heading + 90) * val, sin(heading + 90) * val});
			}
		}
	}
}

species delivery_trucks skills:[advanced_driving]{
	int d_t_emission;
	dummy_node delivery_truck_target;
	float distance_traveled;
	point past_location;
	point new_location;
	bool temp <- true;
	int counter_stucked <- 0;
	int threshold_stucked <- 2;
	list<point> temp_dummy <- dummy_node collect location ;
	
	reflex time_to_go when: final_target = nil {
		delivery_truck_target <- one_of(dummy_node);
		current_path <- compute_path(graph: the_graph, target: delivery_truck_target);
		if(current_path = nil){
			final_target <- nil;
		}
	}
	
	reflex move when: current_path != nil and final_target != nil {
		do delivery_truck_car_old_location;
		ask traffic_light at_distance(10 #ft){
			if(self.traffic_light_color = #green){
				myself.temp <- true;
			} else{
				myself.temp <- false;
			}
		}
	
		if(temp = true){
			ask road{
				if(myself.shape overlaps self.shape){
					myself.max_speed <- self.maxspeed;
					myself.speed <- gauss(DeliveryTruckAveSpeed, DeliveryTruckStdSpeed) #mile/#hour;
				}
			}
			do drive;	
		}else{
			self.speed <- 0;
		}
		do delivery_truck_car_new_location;
		
		if(self.location = self.final_target) {
			final_target <- nil;
			write 'Delivery Truck Agent '+ self.name + ' Has Arrived to Its Destination';
		}
		if real_speed < 5 #mile/#h {
			counter_stucked <- counter_stucked + 1;
			if (counter_stucked mod threshold_stucked = 0) {
				proba_use_linked_road <- min([1.0,proba_use_linked_road + 0.1]);
			}
		} else {
			counter_stucked <- 0;
			proba_use_linked_road <- 0.0;
		}
		
	}
	
	action delivery_truck_car_old_location{
		past_location <- self.location;
	}
	action delivery_truck_car_new_location{
		new_location <- self.location;
		distance_traveled <- distance_to(past_location,new_location)/#mile;
	}
	
	point calcul_loc{
		if(current_road = nil) {
			return location;
		} else {
			float val <- (road(current_road).lanes - current_lane) + 0.1;
			val <- on_linked_road ? val * - 1 : val;
			if (val = 0) {
				return location; 
			} else {
				return (location + {cos(heading + 90) * val, sin(heading + 90) * val});
			}
		}
	}
	
	aspect base3D {
		point loc <- calcul_loc();
		draw box(vehicle_length, 2, 2) at: loc rotate:  heading color: #orange;
	}
}
// Static Agents 
species road skills:[skill_road]{
	float speed_limit;
	string oneway;
	geometry road_geom_shape;

	aspect road_width {  
		draw road_geom_shape color: color ;
	}
	aspect base3D {    
		draw road_geom_shape color: #gray ;
	}
}

species side_walks{
	geometry ped_geom_shape;
	aspect ped_width{
		draw ped_geom_shape color: #green; 
	}
	aspect base3D{
		draw ped_geom_shape color: #green; 
	}
}

species ped_dest{
	string type;
	aspect base3D{
		//draw square(3#px) color: #pink;
		draw mbtastations_imagefile at: {location.x,location.y,10} size: 5 border: #yellow;
	}
}

species mbta_stations{
	aspect base{
		draw square(2#px) color: #yellow;
	}
}

species dummy_node skills: [skill_road_node]{
	aspect base {
		draw square(2#px) color: #orange;
	}
}

species traffic_light skills: [skill_road_node]{
	list<int> objectid;
	int sequence;
	int cluster;
	int cycle;
	int crosswalk;
	bool is_traffic_light <- false;
	int time_to_change <- TrafficLightTime2Change;
	list<road> ways1;
	list<road> ways2;
	bool is_green;
	int counter ;
	rgb traffic_light_color;
	
	action initialize {
		if(is_traffic_light) {
			if (flip(0.5)) {
				do to_green;
			} else {
				do to_red;
			}	
		}
	}

	action compute_crossing{
		if (not(empty(roads_in))) or (length(roads_in) >= 2){
			road rd0 <- road(roads_in[0]);
			list<point> pts <- rd0.shape.points;						
			float ref_angle <- float(last(pts) direction_to rd0.location);
			loop rd over: roads_in {
				list<point> pts2 <- road(rd).shape.points;						
				float angle_dest <- float(last(pts2) direction_to rd.location);
				float ang <- abs(angle_dest - ref_angle);
				if (ang > 45 and ang < 135) or (ang > 225 and ang < 315){
					add road(rd) to: ways2;
					write ways2;
				}
			}
		}
	}
	
	action to_green {
		stop[0] <- ways2 ;
		traffic_light_color <- #green;
		is_green <- true;
	}
	
	action to_red {
		stop[0] <- ways1;
		traffic_light_color <- #red;
		is_green <- false;
	}
	
	reflex dynamic_node when: is_traffic_light {
		counter <- counter + 1;
		if (counter >= time_to_change) { 
			counter <- 0;
			if is_green {do to_red;}
			else {do to_green;}
		}
	}

	aspect base3D {
		draw box(0.5,0.5,8) color:#black;
		draw sphere(2) at: {location.x,location.y,10} color: traffic_light_color;
	}
}

experiment CityofBoston_3D type: gui {
	output {
		display carte_principale type: opengl {
			species road aspect: base3D refresh: true;
			species traffic_light aspect: base3D;
			species personal_car aspect: base3D;
			species side_walks aspect: base3D;
			species pedestrians aspect: base3D;
			species regular_buses aspect: base3D;
			species busnodes aspect: base3D;
			species uber_car aspect: base3D refresh: true;
			species uber_pedestrians_population aspect: base3D;
			species ped_dest aspect:base3D refresh: false;
			species delivery_trucks aspect:base3D;
		}
		
		display "Total Miles Traveled" type:java2D {
			chart "Total Miles Traveled" type:series
				x_serie_labels:("Simulation Cycle" + cycle) style: spline
				x_range:10 x_tick_unit: 3 x_serie_labels: ("Simulation Cycle" + cycle) x_label: 'Simulation Cycles' y_label: 'Miles Traveled'
			 {
				data "Uber Cars (Comb)" value: uber_total_traveled_distance
				accumulate_values: true
				color:#red;
				data "Buses (Comb)" value: bus_total_traveled_distance
				accumulate_values: true
				color:#yellow;
				data "Personal Cars (Comb)" value: personal_car_total_traveled_distance
				accumulate_values: true
				color:#black;
			}
		}

	}
}

//https://groups.google.com/forum/#!searchin/gama-platform/path%7Csort:relevance/gama-platform/Wk62GGTvMsU/daqeWzLHA64J