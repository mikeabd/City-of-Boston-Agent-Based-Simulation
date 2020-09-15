
model DowntownBoston

global {
	/*************************** Shape Files  ********************************************/
	file roads_shapefile parameter: "Shapefile for the roads:" category: "GIS" <- file("../includes/Roads/DowntownRoads.shp");
	file sidewalks_shapefile parameter: "Shapefile for the side walks:" category: "GIS" <- file("../includes/Sidewalk/DowntownSidewalks.shp");
	file traffic_shapefile parameter: "Shapefile for the traffic lights:" category: "GIS" <- file("../includes/TrafficLight/DowntownTrafficSignalsDetailed.shp");
	file busstops_shapefile parameter: "Shapefile for the bus stops:" category: "GIS" <- file("../includes/BusStops/AllBusRoutes_Stops_PointFeatures.shp");
	file busrouts_shapefile parameter: "Shapefile for the bus routes:" category: "GIS" <- file("../includes/BusLines/AllBusRoutes_Lines_PointFeatures.shp");
	file buslines_csvfile <- csv_file("../includes/BusLines/AllBusRoutes_Lines_PointFeatures.csv", true);
	file busstops_csvfile <- csv_file("../includes/BusStops/AllBusRoutes_Stops_PointFeatures.csv", true);
	file orig_dest_csvfile <- csv_file("../includes/OrgDest/DowntownODPairs.csv", true);
	file ped_dest_shapefile parameter: "Shapefile for the pedestrians destination:" category: "GIS" <- file("../includes/OrgDest/DowntownOriginDestinations.shp");
	
	
	/*************************** Simulation Core Parameters *****************************/
	float step <- 0.01 #mn ;
	int SimDurationInDays parameter: "Simulation Running Duration (Days)" category: "Core Simulation" min:1 max:30 init: 1;
	date starting_date <- date("now");
	reflex pause_simulation when: (current_date - starting_date) >= SimDurationInDays*24*3600 {
		write current_date;
		do pause;
	}
	
	/*************************** General Parameters  *************************************/
	float BusAveSpeed <- 30.0 parameter: "Average Bus Speed (mph)" category: "Agents Speed and Time Parameters" ;
	float BusStdSpeed <- 0.0 parameter: "Std Dev Bus Speed (mph)" category: "Agents Speed and Time Parameters";
	float DeliveryTruckAveSpeed <- 15.0 parameter: "Average Delivery Truck Speed (mph)" category: "Agents Speed and Time Parameters" ;
	float DeliveryTruckStdSpeed <- 0.0 parameter: "Std Dev Delivery Truck Speed (mph)" category: "Agents Speed and Time Parameters";
	float PersonalCarAveSpeed <- 50.0 parameter: "Average Personal Cars Speed (mph)" category: "Agents Speed and Time Parameters";
	float PersonalCarStdSpeed <- 0.0  parameter: "Std Dev Personal Cars Speed (mph)" category: "Agents Speed and Time Parameters";
	float UberTaxiAveSpeed <- 30.0 parameter: "Average Uber/Taxi Speed (mph)" category: "Agents Speed and Time Parameters";
	float UberTaxiStdSpeed <- 0.0 parameter: "Std Dev Uber/Taxi Speed (mph)" category: "Agents Speed and Time Parameters";
	float PedestrianAveMovingSpeed <- 2.0 parameter: "Average Pedestrians Speed (mph)" category: "Agents Speed and Time Parameters";
	float PedestrianStdMovingSpeed <- 0.0 parameter: "Std Dev Pedestrians Speed (mph)" category: "Agents Speed and Time Parameters";
	int TrafficLightTime2Change <-35 parameter: "Traffic Light Phase Length" category: "Speed and Time Parameters" min: 1 max: 200; 
	int BusMinStopTime <-100 parameter: " Buses Minimum Stop Time" category: "Agents Speed and Time Parameters" min: 0 max: 200;
	int BusMaxStopTime <-100 parameter: " Buses Maximum Stop Time" category: "Agents Speed and Time Parameters" min: 0 max: 200;

	/*************************** Reporting Parameters ***********************************/
	// Distance
	float uber_taxi_total_traveled_distance;
	float bus_total_traveled_distance;
	float personal_car_total_traveled_distance;
	
	// Agent Population
	int uber_taxi_total_agents;
	int bus_total_agents;
	int personal_car_total_agents;
	
	// Died Agents
	int personal_car_died_agents;
	int uber_taxi_died_agents;
	int bus_died_agents;
	
	float personal_car_travel_time;
	float uber_taxi_travel_time;
	float bus_travel_time;
	
	// Average Time Till Death
	float personal_car_average_traveling_time;
	float uber_taxi_average_traveling_time;
	float bus_average_traveling_time;
	
	string Agent_Type parameter: "Agent Type: " category: "Reporting KPIs " among:['Personal Cars', 'Ubers/Taxis'] init: 'Personal Cars';
	
	reflex Reporting_KPIs {
		uber_taxi_total_traveled_distance <- uber_taxi_total_traveled_distance + sum(uber_car collect each.distance_traveled) + sum(taxis collect each.distance_traveled);
		bus_total_traveled_distance <- bus_total_traveled_distance + sum(regular_buses collect each.distance_traveled);
		personal_car_total_traveled_distance <- personal_car_total_traveled_distance + sum(personal_car collect each.distance_traveled);
		uber_taxi_total_agents <- length(uber_car) + length(taxis);
		bus_total_agents <- length(regular_buses);
		personal_car_total_agents <- length(personal_car);
		personal_car_average_traveling_time <- (personal_car_travel_time/(personal_car_died_agents+0.000001))/#mn;
		uber_taxi_average_traveling_time <- (uber_taxi_travel_time/(uber_taxi_died_agents+0.000001))/#mn;
        bus_average_traveling_time <- (bus_travel_time/(bus_died_agents+0.000001))/#mn;
        
        if(cycle = 0){
        	save "Simulation Cycle, Time, Personal Car Total Traveled Distance (Miles), Bus Total Traveled Distance (Miles), Uber/Taxi Total Traveled Distance (Miles)"
				+ "Personal Car Average Speed (mph), Taxi/Uber Average Speed (mph), Bus Average Speed (mph), Total Number of Personal Cars, Total Number of Taxi/Ubers"
				+ "Total Number of Buses, Average Personal Car Traveling Time (min), Average Uber/Taxi Traveling Time (min), Average Bus Traveling Time (min)" 
			to:"../doc/kpi_file.csv";
			save " ID, Destination, Org Lon, Org Lat, Dest Lon, Dest Lat" to:"../doc/error.csv";
        }
		save [cycle, time, personal_car_total_traveled_distance, bus_total_traveled_distance, uber_taxi_total_traveled_distance, mean(personal_car collect each.speed)
				, mean(uber_car collect each.speed), mean(regular_buses collect each.speed), personal_car_total_agents, uber_taxi_total_agents, bus_total_agents, personal_car_average_traveling_time
				, uber_taxi_average_traveling_time, bus_average_traveling_time] to:"../doc/kpi_file.csv" type: "csv" rewrite: false;
	}
	
	/*************************** Agent Population Parameters  ***************************/
	int nb_delivery_trucks<-3 parameter: "Delivery Trucks Total Population " category: "Agent Population" min:1 max:10;
	file bus_arrival_time_csvfile <- csv_file("../includes/AgentArrivalSchedule/BusArrivalSchedule.csv", true);
	file all_agents_arrival_percentage_csvfile <- csv_file("../includes/AgentArrivalSchedule/InOutPercentage.csv", true);
	matrix bus_creation_cycle <- matrix(bus_arrival_time_csvfile);
	matrix agent_creation_matrix <- matrix(all_agents_arrival_percentage_csvfile);

	/*************************** Global Parameters ************************************/
	geometry shape <- envelope(roads_shapefile);
	graph<road> the_graph;
	graph<side_walks> the_ped_graph;
	graph the_bus_route;
	
	int total_traffic_light_clusters;
	/*float sedan_lenght <- 179.4 #inch;
	float sedan_hight <- 56.5 #inch;
	float sedan_width <- 69.0 #inch;*/
	float sedan_lenght <- 108 #inch;
	float sedan_hight <- 33.6 #inch;
	float sedan_width <- 41.4  #inch;
	float bus_lenght <- 40 #ft;
	float bus_hight <- 8 #ft;
	float bus_width <- 10.5 #ft;
	float semi_lenght <- 53 #ft;
	float semi_hight <- 13.6 #ft;
	float semi_width <- 5.5 #ft;
	
	list<traffic_light> traffic_signals;
	list<traffic_light> cycle_1_traffic_signals;
	list<traffic_light> cycle_2_traffic_signals;
	list<int> temp;
	list<point> bus_nodes;
	list<int> unique_routes <- list<int>(remove_duplicates(bus_lines column_at 1 accumulate each));
	list<point> BusRoute;
	list<agent> pedestrians_crossing_road;
	list<point> ped_origins;
	list<point> ped_destinations;
	list<point> nodes;
	
	matrix bus_lines <- matrix(buslines_csvfile);
	matrix bus_stops <- matrix(busstops_csvfile);
	matrix bus_paths <- nil as_matrix({4, length(unique_routes)});
	matrix org_dest <- matrix (orig_dest_csvfile);
	
	int killed_int <- 0;
	/*************************** Initiating Agents ***********************************/
	init{
		create traffic_light from: traffic_shapefile with:[is_traffic_light::true, objectid::list<int>(int(read('OBJECTID')))
			, sequence::int(read('sequence')), cluster::int(read('cluster')), cycle::int(read('cycle'))
			, crosswalk::int(read('crosswalk'))]{
				sequence <- self.sequence;
				cluster <- self.cluster;
				cycle <- self.cycle;
				crosswalk <- self.crosswalk;
				temp <- list<int>(self.cluster);
		}
		total_traffic_light_clusters <- max(temp);
		do init_traffic_signal;
		
		loop i from:1 to: bus_stops.rows-1{
			add point(to_GAMA_CRS({float(bus_stops[7, i]), float(bus_stops[6, i])}, "EPSG:4326")) to: bus_nodes;
		}
	
		create busnodes from: busstops_shapefile;
		
		create road from: roads_shapefile with:[speed_limit::float(read('SPEEDLIMIT'))
			, oneway::float(read('OPPOSITENU')), lanes::int(read('NUMBEROFTR'))]{
			lanes <- max([1,lanes]);
			maxspeed <-  max([20,speed_limit]) #miles/#hour;
			point fp <- first(shape.points);
			point lp <- last(shape.points);
			if not (fp in nodes) {create dummy_node with:[location::fp]; nodes << fp;}
			if not (lp in nodes) {create dummy_node with:[location::lp]; nodes << lp;}
			switch oneway {
				match_one [1,2,3]{
					create road {
						lanes <- myself.lanes;
						shape <- polyline(reverse(myself.shape.points));
						maxspeed <- max([20,speed_limit]) #miles/#hour;
						road_geom_shape <- myself.road_geom_shape;
						linked_road <- myself;
						myself.linked_road <- self;
					}
				}
			}
		}
		
		ask road as list {
			road_geom_shape <- shape + (1.5*lanes);
		}
	
		nodes <- dummy_node collect each.location;
		map general_speed_map <- road as_map (each::(each.shape.perimeter / each.maxspeed));
		the_graph <- graph<unknown, road>(as_driving_graph(road, dummy_node) with_weights general_speed_map);
		
		int tmp <- 0;
		loop i over:unique_routes{
			BusRoute <- [];
			loop j from: 0 to: bus_lines.rows-1{
		 		if(i = int(bus_lines[1,j])){
		 			add point(to_GAMA_CRS({float(bus_lines[7, j]), float(bus_lines[6, j])}, "EPSG:4326")) to:BusRoute;
		 			point last_point <- point(to_GAMA_CRS({float(bus_lines[7, j]), float(bus_lines[6, j])}, "EPSG:4326"));
		 			bus_paths[3,tmp] <- last_point;
		 		}
		 		if(i = int(bus_lines[1, j]) and int(bus_lines[5, j]) = 0){
		 			point first_point <- point(to_GAMA_CRS({float(bus_lines[7, j]), float(bus_lines[6, j])}, "EPSG:4326"));
		 			bus_paths[2,tmp] <- first_point;	
		 		}
		 	}
		 	bus_paths[1,tmp] <- path(BusRoute);
		 	bus_paths[0,tmp] <- i;
		 	tmp <- tmp + 1;
		}
		
		create side_walks from: sidewalks_shapefile;
		ask side_walks as list{
			ped_geom_shape <- shape+(shape*2) ;
		}
		the_ped_graph <- as_edge_graph(side_walks);

		create delivery_trucks number:nb_delivery_trucks{
			shape <- box(vehicle_length, semi_width, semi_hight);
			location <- point(one_of(dummy_node));
			vehicle_length <- semi_lenght ;
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
	int InBoundPrecentage <- 0;
	int OutBoundPrecentage <- 0	;

	reflex agent_creation_cycle {
		loop j from: dummy_id to: agent_creation_matrix.rows-1{
			old_cycle_id <- dummy_id;
			if(time/60 >= (int(agent_creation_matrix[1, j]) + dummy_day*24*3600)){
				dummy_id <- int(agent_creation_matrix[0, j]);
				new_cycle_id <- dummy_id;
			}
			if(new_cycle_id > old_cycle_id){
				InBoundPrecentage <- int(agent_creation_matrix[4, j]);
				OutBoundPrecentage <- int(agent_creation_matrix[6, j]);
				do agent_creation;
				do uber_creation;
				do bus_creation;
			}
			if(dummy_id = agent_creation_matrix.rows){
				dummy_day <- dummy_day + 1;
				dummy_id <- 1;
			}
		}
	}
	action uber_creation{
		create uber_car number: 10{
			birth_time <- machine_time;
			shape <- box(vehicle_length, sedan_width, sedan_hight);
			u_occupancy <- 3;
			vehicle_length <- sedan_lenght;
			right_side_driving <- true;
			proba_lane_change_up <- 0.9 + (rnd(500) / 500);
			proba_lane_change_down <- 0.9 + (rnd(500) / 500);
			security_distance_coeff <- 3 #ft;  
			proba_respect_priorities <- 1.0;
			proba_respect_stops <- 1.0;
			proba_block_node <- 0.0;
			proba_use_linked_road <- 0.0;
			max_acceleration <- 5/3.6;
			speed_coeff <- 5 #mile/#hour;
			location <- any_location_in(one_of(the_graph.edges));
		}
	}
	
	action bus_creation{
		loop j from:0 to:bus_paths.rows-1{
			create regular_buses number: 1{
				birth_time <- machine_time;
				shape <- box(vehicle_length, bus_width, bus_hight);
				r_b_occupancy <- 100;
				point int_point <- bus_paths[2, j]; 
				location <- int_point.location;
				final_target <- bus_paths[3,j];
				bus_path <- bus_paths[1, j];
				vehicle_length <- bus_lenght ;
				right_side_driving <- true;
				proba_lane_change_up <- 0.9 + (rnd(500) / 500);
				proba_lane_change_down <- 0.9 + (rnd(500) / 500);
				security_distance_coeff <- 5/9 * 3.6 * (1.5 - rnd(1000) / 1000);  
				proba_respect_priorities <- 1.0;
				proba_respect_stops <- 1.0;
				proba_block_node <- 0.0;
				proba_use_linked_road <- 0.0;
				max_acceleration <- 2.5/3.6;
				speed_coeff <- BusStdSpeed #mile/#hour;
				temp_bus <- true;
				bus_number <- bus_paths[0, j];
			}
		}
	}
	
	action agent_creation{
		loop i from: 1 to:org_dest.rows-1{
			if(org_dest[7, i] = 'Inbound'){
				create personal_car number: round(float(org_dest[8, i])*(InBoundPrecentage + 0.03) + float(org_dest[9, i])*(InBoundPrecentage + 0.115)){
					shape <- box(vehicle_length, sedan_width, sedan_hight);
					birth_time <- machine_time;
					vehicle_length <- sedan_lenght;
					right_side_driving <- true;
					proba_lane_change_up <- 0.9 + (rnd(500) / 500);
					proba_lane_change_down <- 0.9 + (rnd(500) / 500);
					security_distance_coeff <- 3#ft;  
					proba_respect_priorities <- 1.0;
					proba_respect_stops <- 1.0;
					proba_block_node <- 0.0;
					proba_use_linked_road <- 0.5;
					max_acceleration <- 5/3.6;
					max_speed <- gauss(PersonalCarAveSpeed, PersonalCarStdSpeed) #mile/#hour;
					speed_coeff <- 5 #mile/#hour;
					p_occupancy <- rnd(2,1);	
					personal_car_initial_location <- point(to_GAMA_CRS({float(org_dest[3, i]), float(org_dest[2, i])}, "EPSG:4326"));
					personal_car_target_location <- point(to_GAMA_CRS({float(org_dest[5, i]), float(org_dest[4, i])}, "EPSG:4326")) ;
					location <- (dummy_node closest_to personal_car_initial_location).location;
					current_node <- (dummy_node closest_to personal_car_initial_location);
					target <- (dummy_node closest_to personal_car_target_location);
					do path_compute;
					if(current_path = nil){
						killed_int <- killed_int + 1;
						save [org_dest[0, i], org_dest[1, i], org_dest[3, i], org_dest[2, i], org_dest[5, i], org_dest[4, i]] to:"../doc/error.csv" type: "csv" rewrite: false;
					}
				}
				create uber_taxi_pedestrians_population number: round(float(org_dest[13, i])*(InBoundPrecentage + 0.41)){
					shape <- circle (5#px);
					ped_speed <- PedestrianAveMovingSpeed #mile/#hour;
					uber_taxi_initial_location <- point(to_GAMA_CRS({float(org_dest[3, i]), float(org_dest[2, i])}, "EPSG:4326"));
					uber_taxi_target_location <- point(to_GAMA_CRS({float(org_dest[5, i]), float(org_dest[4, i])}, "EPSG:4326")) ;
					location <- (point(dummy_node closest_to uber_taxi_initial_location));
					uber_ped_target <- (point(dummy_node closest_to uber_taxi_target_location));
				}
				create pedestrians number: round(float(org_dest[11, i])*(InBoundPrecentage + 0.097) + float(org_dest[12, i])*(InBoundPrecentage + 0.345)){
					shape <- circle (5#px);
					ped_speed <- PedestrianAveMovingSpeed #mile/#hour;
					ped_initial_location <- point(to_GAMA_CRS({float(org_dest[3, i]), float(org_dest[2, i])}, "EPSG:4326"));
					ped_target_location <- point(to_GAMA_CRS({float(org_dest[5, i]), float(org_dest[4, i])}, "EPSG:4326")) ;
					location <- the_ped_graph.vertices closest_to ped_initial_location;
					the_target <- the_ped_graph.vertices closest_to ped_target_location;		
				}
				if(org_dest[6, i] = 'Outside_to_Downtown'){
					create taxis number: round(float(org_dest[13, i])*(InBoundPrecentage + 0.41)){
						origin <- org_dest[6, i];
						birth_time <- machine_time;
						shape <- box(vehicle_length, sedan_width, sedan_hight);
						u_occupancy <- 1;
						vehicle_length <- sedan_lenght;
						right_side_driving <- true;
						proba_lane_change_up <- 0.9 + (rnd(500) / 500);
						proba_lane_change_down <- 0.9 + (rnd(500) / 500);
						security_distance_coeff <- 3 #ft;  
						proba_respect_priorities <- 1.0;
						proba_respect_stops <- 1.0;
						proba_block_node <- 0.0;
						proba_use_linked_road <- 0.0;
						max_acceleration <- 5/3.6;
						speed_coeff <- 5 #mile/#hour;
						taxi_initial_location <- point(to_GAMA_CRS({float(org_dest[3, i]), float(org_dest[2, i])}, "EPSG:4326"));
						location <- (dummy_node closest_to taxi_initial_location);
					}
				}
			}
			if(org_dest[7, i] = 'Outbound'){
				create personal_car number: round(float(org_dest[8, i])*(OutBoundPrecentage + 0.04) + float(org_dest[9, i])*(InBoundPrecentage + 0.075)){
					shape <- box(vehicle_length, sedan_width, sedan_hight);
					birth_time <- machine_time;
					vehicle_length <- sedan_lenght;
					right_side_driving <- true;
					proba_lane_change_up <- 0.9 + (rnd(500) / 500);
					proba_lane_change_down <- 0.9 + (rnd(500) / 500);
					security_distance_coeff <- 3#ft;  
					proba_respect_priorities <- 1.0;
					proba_respect_stops <- 1.0;
					proba_block_node <- 0.0;
					proba_use_linked_road <- 0.5;
					max_acceleration <- 5/3.6;
					max_speed <- gauss(PersonalCarAveSpeed, PersonalCarStdSpeed) #mile/#hour;
					speed_coeff <- 5 #mile/#hour;
					p_occupancy <- rnd(2,1);	
					personal_car_initial_location <- point(to_GAMA_CRS({float(org_dest[3, i]), float(org_dest[2, i])}, "EPSG:4326"));
					personal_car_target_location <- point(to_GAMA_CRS({float(org_dest[5, i]), float(org_dest[4, i])}, "EPSG:4326")) ;
					location <- (dummy_node closest_to personal_car_initial_location);
					current_node <- (dummy_node closest_to personal_car_initial_location);
					target <- (dummy_node closest_to personal_car_target_location);
					do path_compute;
					if(current_path = nil){
						killed_int <- killed_int + 1;
						save [org_dest[0, i], org_dest[1, i], org_dest[3, i], org_dest[2, i], org_dest[5, i], org_dest[4, i]] to:"../doc/error.csv" type: "csv" rewrite: false;
					}
				}
				create uber_taxi_pedestrians_population number: round(float(org_dest[13, i])*(OutBoundPrecentage + 0.365)){
					shape <- circle (5#px);
					ped_speed <- PedestrianAveMovingSpeed #mile/#hour;
					uber_taxi_initial_location <- point(to_GAMA_CRS({float(org_dest[3, i]), float(org_dest[2, i])}, "EPSG:4326"));
					uber_taxi_target_location <- point(to_GAMA_CRS({float(org_dest[5, i]), float(org_dest[4, i])}, "EPSG:4326")) ;
					location <- (dummy_node closest_to uber_taxi_initial_location);
					uber_ped_target <- (dummy_node closest_to uber_taxi_target_location);
				}
				create pedestrians number: round(float(org_dest[11, i])*(OutBoundPrecentage + 0.065) + float(org_dest[12, i])*(OutBoundPrecentage + 0.3)){
					shape <- circle (5#px);
					ped_speed <- PedestrianAveMovingSpeed #mile/#hour;
					ped_initial_location <- point(to_GAMA_CRS({float(org_dest[3, i]), float(org_dest[2, i])}, "EPSG:4326"));
					ped_target_location <- point(to_GAMA_CRS({float(org_dest[5, i]), float(org_dest[4, i])}, "EPSG:4326")) ;
					location <- the_ped_graph.vertices closest_to ped_initial_location;
					the_target <- the_ped_graph.vertices closest_to ped_target_location;		
				}
				if(org_dest[6, i] = 'Outside_to_Downtown'){
					create taxis number: round(float(org_dest[13, i])*(InBoundPrecentage + 0.365)){
						origin <- org_dest[6, i];
						birth_time <- machine_time;
						shape <- box(vehicle_length, sedan_width, sedan_hight);
						u_occupancy <- 1;
						vehicle_length <- sedan_lenght;
						right_side_driving <- true;
						proba_lane_change_up <- 0.9 + (rnd(500) / 500);
						proba_lane_change_down <- 0.9 + (rnd(500) / 500);
						security_distance_coeff <- 3 #ft;  
						proba_respect_priorities <- 1.0;
						proba_respect_stops <- 1.0;
						proba_block_node <- 0.0;
						proba_use_linked_road <- 0.0;
						max_acceleration <- 5/3.6;
						speed_coeff <- 5 #mile/#hour;
						taxi_initial_location <- point(to_GAMA_CRS({float(org_dest[3, i]), float(org_dest[2, i])}, "EPSG:4326"));
						location <- (dummy_node closest_to taxi_initial_location);
					}
				}
			}	
		}
	}
	
}
species personal_car skills:[advanced_driving]{
	int p_occupancy;
	int counter_stucked <- 0;
	int threshold_stucked <- 2;
	dummy_node target;
	dummy_node current_node;
	point personal_car_initial_location;
	point personal_car_target_location;
	bool temp_personal_car <- true;
	float distance_traveled;
	point past_location;
	point new_location;
	float birth_time;
	
	reflex move when: current_path != nil and final_target != nil {
		do personal_car_old_location;
		ask traffic_light at_distance(10 #ft){
			if(self.traffic_light_color = #green){
				myself.temp_personal_car <- true;
			} else{
				myself.temp_personal_car <- false;
			}
		}
		if(temp_personal_car = true){
			do drive;	
		}else{
			self.speed <- 0;
		}
		
		do personal_car_new_location;
		
		if(real_speed < 5 #mile/#h) {
			counter_stucked <- counter_stucked + 1;
			if(counter_stucked mod threshold_stucked = 0) {
				proba_use_linked_road <- min([1.0,proba_use_linked_road + 0.1]);
			}
		} else{
			counter_stucked <- 0;
			proba_use_linked_road <- 0.0;
		}
		
		if(distance_to (self.location, self.target.location) <= 10 #ft){
			personal_car_travel_time <- personal_car_travel_time + (machine_time - birth_time);
			personal_car_died_agents <- personal_car_died_agents + 1;
			if(current_road != nil){
				ask road(current_road){
					do unregister(myself);
				}
			}
			do die;
		}
	}
	
	action path_compute{
		do compute_path(graph: the_graph, target: target, source: current_node);
	}
	action personal_car_old_location{
		past_location <- self.location;
	}
	action personal_car_new_location{
		new_location <- self.location;
		distance_traveled <- distance_to(past_location,new_location)/#mile;
	}

	aspect base3D {
		point loc <- calcul_loc();
		//draw box(vehicle_length, sedan_width, sedan_hight) at: loc rotate: heading color: #red;
		draw rectangle(vehicle_length, sedan_width) at: loc rotate: heading color: #red;
		//draw box(vehicle_length/2, sedan_width/2, sedan_hight+sedan_hight/4) at: loc rotate: heading color: #red;
	}
	
	point calcul_loc {
		if(current_road = nil) {
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
species uber_car skills:[advanced_driving]{
	int u_occupancy <- 3;
	float u_emission;
	point uber_target;
	bool temp_uber <- true;
	float UberSpeed;
	list temp_targets;
	path updated_path;
	point new_location;
	point past_location;
	float distance_traveled;
	dummy_node target;
	float birth_time;
	
	reflex pick_up_passengers when:length(uber_passengers) <= u_occupancy {
		capture(u_occupancy - length(uber_passengers)) among uber_taxi_pedestrians_population at_distance 50 #ft as:uber_passengers;
	}
	
	reflex release_passengers {
		release uber_passengers where (each.uber_ped_target distance_to self.location <= 100 #ft);
	}
	
	reflex time_to_go when: final_target = nil{
		if(!empty(uber_passengers) = true){
			temp_targets <- (uber_passengers collect each.uber_ped_target);
			uber_target <- temp_targets closest_to (self.location);
			current_path <- compute_path(graph:the_graph, target:closest_to(dummy_node, uber_target), source: self);
			final_target <- closest_to(dummy_node, uber_target);
		}else{
			ask uber_taxi_pedestrians_population with_min_of(self distance_to location){
				myself.uber_target <- self.uber_taxi_initial_location;
			}
			current_path <- compute_path(graph:the_graph, target: closest_to(dummy_node, uber_target), source: self);
			final_target <- closest_to(dummy_node, uber_target);
			
		}
		if(current_path = nil){
			final_target <- nil;
		}
	}
	
	reflex move when: current_path != nil{			
		do uber_old_location;
		ask traffic_light at_distance(10 #ft){
			if(self.traffic_light_color = #green){
				myself.temp_uber <- true;
			} else{
				myself.temp_uber <- false;
			}
		}
		if(temp_uber = true){
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
	
	species uber_passengers parent:uber_taxi_pedestrians_population{
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
		draw box(vehicle_length, sedan_width, sedan_hight) at: loc rotate: heading color: #lightgreen;
		draw box(vehicle_length/2, sedan_width/2, sedan_hight+sedan_hight/4) at: loc rotate: heading color: #lightgreen;
		loop i over: uber_passengers{
			draw circle(0.4) depth: 2.5 at: loc rotate:  heading + 90 color: #black;
		}
	}
}

species uber_taxi_pedestrians_population skills:[moving]{
	float ped_speed <- PedestrianAveMovingSpeed;
	point uber_ped_target;
	point uber_taxi_initial_location;
	point uber_taxi_target_location;
	
	/*reflex moving when: uber_ped_target != nil{
		do goto target: uber_ped_target on: the_ped_graph speed: ped_speed;
		if(uber_ped_target = location) {
			uber_ped_target <- any_location_in(one_of(the_ped_graph));
			write "Uber Pedestrian Agent " + self +" has Arrived and Died";
			//do die;
		}
	}*/
	aspect base3D{
		draw triangle(1.0) depth: 1.0 rotate: heading + 90 color: #green;
	}	
}

species taxis parent: uber_car{
	point taxi_initial_location;
	string origin;

	reflex agents_death{
		if(final_target != nil and distance_to(location, final_target) <= 100 #ft){
			uber_taxi_travel_time <- uber_taxi_travel_time + (machine_time - birth_time);
			uber_taxi_died_agents <- uber_taxi_died_agents + 1;
			if(origin = 'Outside_to_Downtown' or origin = 'Downtown_to_Downtown'){
				if(current_road != nil){
					ask road(current_road){
						do unregister(myself);
					}
				}
				do die;
				create taxis number: 1{
					birth_time <- machine_time;
					shape <- circle (5#px);
					u_occupancy <- 1;
					vehicle_length <- sedan_lenght;
					right_side_driving <- true;
					proba_lane_change_up <- 0.9 + (rnd(500) / 500);
					proba_lane_change_down <- 0.9 + (rnd(500) / 500);
					security_distance_coeff <- 3 #ft;  
					proba_respect_priorities <- 1.0;
					proba_respect_stops <- 1.0;
					proba_block_node <- 0.0;
					proba_use_linked_road <- 0.0;
					max_acceleration <- 5/3.6;
					speed_coeff <- 5 #mile/#hour;
					location <- any_location_in(one_of(the_graph));
					self.uber_target <- point(uber_taxi_pedestrians_population closest_to self.location);	
				}
			}
			if(origin = 'Downtown_to_Outside'){
				if(current_road != nil){
					ask road(current_road){
						do unregister(myself);
					}
				}
				write self.name + " Is Dead";
				do die;
				ask self.members{
					do die;
				}
			}
		}
	}
	
	aspect base3D{
		point loc <- calcul_loc();
		draw box(vehicle_length, sedan_width, sedan_hight) at: loc rotate: heading color: #yellow;
		draw box(vehicle_length/2, sedan_width/2, sedan_hight+sedan_hight/4) at: loc rotate: heading color: #yellow;
		loop i over: uber_passengers{
			draw circle(0.4) depth: 2.5 at: loc rotate:  heading + 90 color: #black;
		}	
	}
}

species pedestrians skills:[moving]{
	float ped_speed;
	point the_target <- nil;
	point ped_initial_location ;
	point ped_target_location ;
	
	reflex moving when: the_target != nil{		
		do goto target: the_target on: the_ped_graph speed: ped_speed;	
		if(the_target = location){
			do die;
		}
	}

	aspect base3D{
		draw triangle(1.0)  rotate: heading + 90 color: #black;
	}
}

species regular_buses skills:[moving, advanced_driving] {
	int r_b_occupancy;
	float r_b_emission;
	path bus_path;
	int counter_stucked <- 0;
	int threshold_stucked <- 2;
	int time_to_stop <- BusMaxStopTime;
	bool temp_bus;
	int temp_counter <- 0;
	float BusSpeed;
	point past_location;
	point new_location;
	float distance_traveled;
	int bus_number;
	float birth_time;
	
	reflex move{
		ask traffic_light at_distance(5 #ft){
			if(self.traffic_light_color = #green){
				myself.temp_bus <- true;
			} else{
				myself.temp_bus <- false;
			}
		}
		
		ask busnodes at_distance(15.0 #ft){
			if(myself.temp_counter <= myself.time_to_stop){ 
				myself.temp_bus <- false;
				myself.temp_counter <- myself.temp_counter + 1;
			} else{
				myself.temp_bus <- true ;
				myself.temp_counter <- 0;
			}
		}
		do bus_old_location;
		if(temp_bus = true){
			BusSpeed <- gauss(BusAveSpeed, BusStdSpeed) #mile/#hour ;
			do follow path: bus_path speed: self.BusSpeed;
		}else{
			BusSpeed <- 0.0;
			do follow path: bus_path speed: 0.0;
		}
		
		do bus_new_location;
		
		if(location = final_target){
			bus_travel_time <- bus_travel_time + (machine_time - birth_time);
			bus_died_agents <- bus_died_agents + 1;
			if(current_road != nil){
				ask road(current_road){
					do unregister(myself);
				}
			}
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
		//draw box(vehicle_length, bus_width, bus_hight) at: loc rotate: heading color: #yellow;
		draw rectangle(vehicle_length, bus_width) at: loc rotate: heading color: #yellow;
		//draw string(bus_number) at: loc rotate:  heading + 90 font: font('Default', 6, #bold) color: #yellow;
	}
}

species busnodes frequency: 0{
	aspect base3D{
		draw box(0.5,1.5,9) color:#black;
		draw box(2,2,2) at: {location.x,location.y,8} color: #yellow;
	}
}

species delivery_trucks skills:[advanced_driving]{
	dummy_node delivery_truck_target;
	float distance_traveled;
	point past_location;
	point new_location;
	bool temp_delivery_truck <- true;
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
				myself.temp_delivery_truck <- true;
			} else{
				myself.temp_delivery_truck <- false;
			}
		}
	
		if(temp_delivery_truck = true){
			do drive;	
		}else{
			self.speed <- 0.0;
		}
		do delivery_truck_car_new_location;
		
		if(self.location = self.final_target) {
			final_target <- nil;
			write 'Delivery Truck Agent '+ self.name + ' Has Arrived to Its Destination';
		}
		if(real_speed < 5 #mile/#h) {
			counter_stucked <- counter_stucked + 1;
			if (counter_stucked mod threshold_stucked = 0) {
				proba_use_linked_road <- min([1.0,proba_use_linked_road + 0.1]);
			}
		} else {
			counter_stucked <- 0;
			proba_use_linked_road <- 0.0;
		}
		
		if(distance_to(location, final_target) <= 100 #ft){
			if(current_road != nil){
				ask road(current_road){
					do unregister(myself);
				}
			}
			do die;
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
		//draw box(vehicle_length, semi_width, semi_hight) at: loc rotate:  heading color: #silver;
		draw rectangle(vehicle_length, semi_width) at: loc rotate:  heading color: #silver;
	}
}
// Static Agents 
species road skills:[skill_road] frequency:0 {
	float speed_limit;
	int oneway;
	geometry road_geom_shape;

	aspect base3D {    
		draw road_geom_shape color: #gray ;
	}
}

species side_walks frequency:0 {
	geometry ped_geom_shape;
	aspect base3D{
		draw ped_geom_shape color: #green; 
	}
}

species dummy_node skills:[skill_road_node] frequency:0 {
	aspect base3D {
		draw square(2#px) color: #orange;
	}
}

species traffic_light skills:[skill_road_node]{
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

experiment Downtown_Boston_3D type: gui {
	output {
		display "Total Miles Traveled" type:java2D {
			chart "Total Miles Traveled by Agents" type:series x_serie_labels:("Simulation Time" + current_date) style: spline
				x_range:10 x_tick_unit: 3 x_label: 'Simulation Time' y_label: 'Miles Traveled' legend_font_size: 14 tick_font_size: 12 tick_font_style: bold label_font_size: 16
			 {
				data "Uber Cars (Comb)" value: uber_taxi_total_traveled_distance accumulate_values: true color:#red;
				data "Buses (Comb)" value: bus_total_traveled_distance accumulate_values: true color:#yellow;
				data "Personal Cars (Comb)" value: personal_car_total_traveled_distance accumulate_values: true color:#black;
			}
		}
		
		display "Total Agents on the Map" type:java2D {
			chart "Total Agents on the Map" type:series x_serie_labels:("Simulation Time" + current_date) style: spline
				x_range:10 x_tick_unit: 3  x_label: 'Simulation Time' y_label: 'Total Number of Agents' legend_font_size: 14 tick_font_size: 12 tick_font_style: bold label_font_size: 16
			 {
				data "Uber Cars (Comb)" value: uber_taxi_total_agents accumulate_values: true color:#red;
				data "Buses (Comb)" value: bus_total_agents accumulate_values: true color:#yellow;
				data "Personal Cars (Comb)" value: personal_car_total_agents accumulate_values: true color:#black;
			}
		}
		
		display "Average Traveling Time (min) of Agents " type:java2D {
			chart "Average Traveling Time (min) of Agents" type:series x_serie_labels:(current_date) style: spline
				x_range:10 x_tick_unit: 3  x_label: 'Simulation Time' y_label: 'Traveled Time (min)' legend_font_size: 14 tick_font_size: 12 tick_font_style: bold label_font_size: 16
			 {
				data "Uber Cars (Comb)" value: uber_taxi_average_traveling_time accumulate_values: true color:#red;
				data "Buses (Comb)" value: bus_average_traveling_time accumulate_values: true color:#yellow;
				data "Personal Cars (Comb)" value: personal_car_average_traveling_time accumulate_values: true color:#black;
			}
		}
		display carte_principale type: opengl {
			species road aspect: base3D refresh: true;
			species traffic_light aspect: base3D;
			species personal_car aspect: base3D;
			species side_walks aspect: base3D;
			species pedestrians aspect: base3D;
			species regular_buses aspect: base3D;
			species busnodes aspect: base3D;
			species uber_car aspect: base3D refresh: true;
			species uber_taxi_pedestrians_population aspect: base3D;
			species delivery_trucks aspect:base3D;
			species taxis aspect: base3D;
			species dummy_node aspect: base3D;
		}
	}
}

