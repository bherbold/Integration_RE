using Pkg
using Ipopt, JuMP
using Dates
using CSV
using DataFrames

println("--- Start Program ---")

#General 

tfinal = 1000;
dt = 1; 
#Read Data
#demand start at (2,3:27) (every day with its hours is a row)

df = DateFormat("dd/mm/yyyy");
demand = CSV.read("data/Demanda_d_energia_el_ctrica_hor_ria_a_Catalunya_per_MWh.csv", DataFrame)
demand.DATA = map(row -> Date(row, df), demand.DATA)
filter!(x -> Dates.year(x.DATA) == 2019, demand) # only 2019 data
sort!(demand, (:DATA)) # sort the entries by date

demandrow = DataFrame(Hour=[], Demand=[])

for day in eachrow(demand)
    push!(demandrow, (size(demandrow,1) + 1,day.H01))
    push!(demandrow, (size(demandrow,1) + 1,day.H02))
    push!(demandrow, (size(demandrow,1) + 1,day.H03))
    push!(demandrow, (size(demandrow,1) + 1,day.H04))
    push!(demandrow, (size(demandrow,1) + 1,day.H05))
    push!(demandrow, (size(demandrow,1) + 1,day.H06))
    push!(demandrow, (size(demandrow,1) + 1,day.H07))
    push!(demandrow, (size(demandrow,1) + 1,day.H08))
    push!(demandrow, (size(demandrow,1) + 1,day.H09))
    push!(demandrow, (size(demandrow,1) + 1,day.H10))
    push!(demandrow, (size(demandrow,1) + 1,day.H11))
    push!(demandrow, (size(demandrow,1) + 1,day.H12))
    push!(demandrow, (size(demandrow,1) + 1,day.H13))
    push!(demandrow, (size(demandrow,1) + 1,day.H14))
    push!(demandrow, (size(demandrow,1) + 1,day.H15))
    push!(demandrow, (size(demandrow,1) + 1,day.H16))
    push!(demandrow, (size(demandrow,1) + 1,day.H17))
    push!(demandrow, (size(demandrow,1) + 1,day.H18))
    push!(demandrow, (size(demandrow,1) + 1,day.H19))
    push!(demandrow, (size(demandrow,1) + 1,day.H20))
    push!(demandrow, (size(demandrow,1) + 1,day.H21))
    push!(demandrow, (size(demandrow,1) + 1,day.H22))
    push!(demandrow, (size(demandrow,1) + 1,day.H23))
    push!(demandrow, (size(demandrow,1) + 1,day.H24))

    if day.H25 != 0
        push!(demandrow, (size(demandrow,1) + 1,day.H25))
    end
    

end # The demand is now stored for every hour in a (tfinal,2) Matrix

for i = 1:tfinal
    if demandrow.Demand[i] == 0
        #demandrow.Demand[i] = demandrow.Demand[i-1]
        delete!(demandrow,[i])
    end
end



#delete!(demandrow,[1])
#lastElement = demandrow[size(demandrow,1),2]
#push!(demandrow, (size(demandrow,1) + 1, lastElement))

# Solar generation 1 MW

gen_solar_av = CSV.read("data/solar1.csv", DataFrame)


# Solar generation 1 MW

gen_wind_av = CSV.read("data/wind1.csv", DataFrame)

#known variables
years = 50;

cost_nuc = 3600000 + 20*tfinal*years;
#cost_nuc = 1
capex_gas = 823000;
opex_gas = 150*years;

# Cost solar
solar_life = 25;             #Battery life in years
new_solar = years/solar_life;    # amount of Batteries required 
capex_solar = 900000*new_solar; # Euro per MW
opex_solar = 17000*years; # Euro per MW -> but will it last 50 years??? 
#Electrifying (source)

# Cost wind
wind_life = 25;             #Battery life in years
new_wind = years/wind_life;    # amount of Batteries required 
capex_wind = 1000000*new_wind; # Euro per MW
opex_wind = 40000*years; # Euro per MW per year

# Battery
batt_life = 15;             #Battery life in years
new_batt = years/batt_life;    # amount of Batteries required 
bat_capex = 600*1000*new_batt; # Capex Battery
bat_opex = 20000*years;        # Opex Battery

efficiency_bat = 0.97;      # check with professor
eta_charge = 0.95;          # check with professor
eta_discharge = 0.95;       # check with professor
SOC_bat_MAX = 1;            # (-) - Maximum SOC for batteries
SOC_bat_MIN = 0.1;         # (-) - Minimum SOC for batteries
SOC_ini = 0.1;              # Initial State of charge
bat_power_ratio = 0.5;      # KW/KWh

#model
m = Model(Ipopt.Optimizer)

#parameter constraints
@variable(m,  P_nuc >= 0)
@variable(m, P_gas >= 0)
@variable(m, gen_gas[1:tfinal] >= 0)
@variable(m, solarSize >= 0)
@variable(m, gen_solar[1:tfinal] >= 0)
@variable(m, windSize >= 0)
@variable(m, gen_wind[1:tfinal] >= 0)
@variable(m, battery_energy_capacity >= 0)  # (MWh) battery capacity
@variable(m, battery_power_capacity >= 0)  # (MW) battery capacity
@variable(m, charge_battery_t[1:tfinal] >= 0)  # (MW) - Charge power for the battery
@variable(m, discharge_battery_t[1:tfinal] >= 0)  # (MW) - Discharge power for the battery
@variable(m, SOC_battery[1:tfinal] >= 0)  # (p.u) - State of charge of the battery 

#@variable(m, x[1:tfinal] , Bin)

#objective funktion
@objective(m, Min, cost_nuc * P_nuc + capex_gas * P_gas + opex_gas * sum(gen_gas[1:tfinal]) + capex_solar * solarSize + opex_solar * solarSize + capex_wind * windSize + opex_wind * windSize+ bat_opex*battery_energy_capacity + bat_capex ) 

for i = 1:tfinal
    @NLconstraint(m, gen_gas[i] <= P_gas)
    @NLconstraint(m,gen_solar[i] <= gen_solar_av[i,3])
    @NLconstraint(m, gen_wind[i] <= gen_wind_av[i,3])
end

#variable constraints

for i = 1:tfinal

    @NLconstraint(m,P_nuc + gen_gas[i] + solarSize * gen_solar[i] + windSize * gen_wind[i] - charge_battery_t[i] + discharge_battery_t[i] == demandrow[i, 2])
end
#charge and discharge not at the same time
for ti = 1:tfinal
    @NLconstraint(m, charge_battery_t[ti] * discharge_battery_t[ti] == 0);
end

# BATTERY CHARGE FOR ANY HOUR MUST BE LESS THAN MAX
for ti = 1:tfinal
    @NLconstraint(m, charge_battery_t[ti] <= battery_power_capacity);
end

# COSTRAINT 4: BATTERY DISCHARGE FOR ANY HOUR MUST BE LESS THAN MAX
for ti = 1:tfinal
    @NLconstraint(m, discharge_battery_t[ti] <= battery_power_capacity);
end

# CONSTRAINT 5: DISCHARGE CAPACITY IS HALF THE BATTERY POWER CAPACITY
@NLconstraint(m, battery_power_capacity == bat_power_ratio*battery_energy_capacity);

# CONSTRAINTS 6: STATE OF CHARGE TRACKING
@NLconstraint(m, SOC_battery[1] == SOC_ini + (((eta_charge*charge_battery_t[1])-(discharge_battery_t[1]/eta_discharge))*dt)/battery_energy_capacity);

for ti = 2:tfinal
    @NLconstraint(m, SOC_battery[ti] == SOC_battery[ti-1] + (((eta_charge*charge_battery_t[ti])-(discharge_battery_t[ti]/eta_discharge))*dt)/battery_energy_capacity);
end

# CONSTRAINT 8a: SOC LIMITS (MAXIMUM)
for ti = 1:tfinal
    @NLconstraint(m, SOC_bat_MAX >= SOC_battery[ti]);
end

# CONSTRAINT 8b: SOC LIMITS (MINIMUM)
for ti = 1:tfinal
    @NLconstraint(m, SOC_battery[ti] >= SOC_bat_MIN);
end

# initial and final SOC should be similar
#@NLconstraint(m,SOC_battery[tfinal] >= SOC_battery[1]*0.95);
#@NLconstraint(m,SOC_battery[tfinal] <= SOC_battery[1]*1.05)


optimize!(m)

#### EXPORT DATA TO CSV #######

#Store values hourly

#Nuclear
nuc_cap_opt = JuMP.value.(P_nuc)
nuc_cap_opt_list = zeros(tfinal)
nuc_cap_opt_list[1] = nuc_cap_opt
#nuc_opt = DataFrame(Nuc_Capacity_MW = nuc_cap_opt_list, Nuc_generation_in_hour=JuMP.value.(P_nuc))

#Gas
gas_cap_opt = JuMP.value.(P_gas)
gas_cap_opt_list = zeros(tfinal)
gas_cap_opt_list[1] = gas_cap_opt
#gas_opt = DataFrame(Gas_Capacity_MW = gas_cap_opt_list, Gas_generation_in_hour=JuMP.value.(gen_gas))

#solar
solar_cap_opt = JuMP.value.(solarSize)
solar_cap_opt_list = zeros(tfinal)
solar_cap_opt_list[1] = solar_cap_opt
solar_avalable_opt = zeros(tfinal)
solar_curt_opt = zeros(tfinal)
solar_gen_inject_opt = zeros(tfinal)

for i = 1:tfinal
    solar_gen_inject_opt[i] = JuMP.value.((JuMP.value.(solarSize) * gen_solar[i]))
    solar_avalable_opt[i] = JuMP.value.(solarSize) * gen_solar_av[i,3]
    solar_curt_opt[i] = JuMP.value.(gen_solar[i])/gen_solar_av[i,3]
end
#solar_opt = DataFrame(Solar_Capacity_MW = solar_cap_opt_list, Solar_available_in_hour=solar_avalable_opt, Solar_Curtailment_in_hour=solar_curt_opt,Solar_injected_in_hour = solar_gen_inject_opt )

#wind
wind_cap_opt = JuMP.value.(windSize)
wind_cap_opt_list = zeros(tfinal)
wind_cap_opt_list[1] = wind_cap_opt
wind_avalable_opt = zeros(tfinal)
wind_curt_opt = zeros(tfinal)
wind_gen_inject_opt = zeros(tfinal)

for i = 1:tfinal
    wind_gen_inject_opt[i] = JuMP.value.((JuMP.value.(windSize) * gen_wind[i]))
    wind_avalable_opt[i] = JuMP.value.(windSize) * gen_wind_av[i,3]
    wind_curt_opt[i] = JuMP.value.(gen_wind[i])/gen_wind_av[i,3]
end
#wind_opt = DataFrame(wind_Capacity_MW = wind_cap_opt_list, wind_available_in_hour=wind_avalable_opt, wind_Curtailment_in_hour=wind_curt_opt,wind_injected_in_hour = wind_gen_inject_opt )

#battery

batt_Ecap_opt = JuMP.value.(battery_energy_capacity)
batt_Ecap_opt_list = zeros(tfinal)
batt_Ecap_opt_list[1] = batt_Ecap_opt
batt_Pcap_opt = JuMP.value.(battery_power_capacity)
batt_Pcap_opt_list = zeros(tfinal)
batt_Pcap_opt_list[1] = batt_Pcap_opt
batt_charge_opt = zeros(tfinal)
batt_discharge_opt = zeros(tfinal)
batt_SOC_opt = zeros(tfinal)

for i = 1:tfinal
    batt_charge_opt[i] = JuMP.value.(charge_battery_t[i])
    batt_discharge_opt[i] = JuMP.value.(discharge_battery_t[i])
    batt_SOC_opt[i] = JuMP.value.(SOC_battery[i])
end
#batt_opt = DataFrame(Battery_Energy_Cap_MWh = batt_Ecap_opt_list,  Battery_Power_Cap_MWh = batt_Pcap_opt_list, Battery_Charge_Cap_MW =batt_charge_opt, Battery_Disharge_Cap_MW =batt_discharge_opt, Battery_SOC =  batt_SOC_opt)

overall_opt = DataFrame(hour= 1:tfinal,Nuc_Capacity_MW = nuc_cap_opt_list, Nuc_generation_in_hour=JuMP.value.(P_nuc),Gas_Capacity_MW = gas_cap_opt_list, Gas_generation_in_hour=JuMP.value.(gen_gas),Solar_Capacity_MW = solar_cap_opt_list, Solar_available_in_hour=solar_avalable_opt, Solar_Curtailment_in_hour=solar_curt_opt,Solar_injected_in_hour = solar_gen_inject_opt,wind_Capacity_MW = wind_cap_opt_list, wind_available_in_hour=wind_avalable_opt, wind_Curtailment_in_hour=wind_curt_opt,wind_injected_in_hour = wind_gen_inject_opt,Battery_Energy_Cap_MWh = batt_Ecap_opt_list,  Battery_Power_Cap_MWh = batt_Pcap_opt_list, Battery_Charge_Cap_MW =batt_charge_opt, Battery_Disharge_Cap_MW =batt_discharge_opt, Battery_SOC =  batt_SOC_opt)

CSV.write("data/optimal/Optimal_Values_A_BATTERY_roundtrip.csv", overall_opt)


##### CHECK DATA RESULTS ON CONSOL #####

hourInvest = 12

println("P_nuc:")
println(JuMP.value.(P_nuc))
println("P_gas:")
println(JuMP.value.(P_gas))
println("Gas gen 1:")
println(JuMP.value.(gen_gas[hourInvest]))
println("Solar Capacity:")
println(JuMP.value.(solarSize), " MW")
println("Solar Generation available:")
println((JuMP.value.(solarSize) * gen_solar_av[hourInvest,3]), " MW")
println("Solar Generation injected:")
println(JuMP.value.((JuMP.value.(solarSize) * gen_solar[hourInvest])), " MW")
println("Solar Operation Ratio:")
println(JuMP.value.(gen_solar[hourInvest])/gen_solar_av[hourInvest,3])
println("Wind Capacity:")
println(JuMP.value.(windSize), " MW")
println("Wind Generation available:")
println((JuMP.value.(windSize) * gen_wind_av[hourInvest,3]), " MW")
println("Wind Generation injected:")
println(JuMP.value.((JuMP.value.(windSize) * gen_wind[hourInvest])), " MW")
println("wind Operation Ratio:")
println(JuMP.value.(gen_wind[hourInvest])/gen_wind_av[hourInvest,3])
println("Demand 1:")
println(JuMP.value.(demandrow[hourInvest,2]))
println("Battery Energy Cap:")
println(JuMP.value.(battery_energy_capacity))
println(typeof(JuMP.value.(P_nuc)))