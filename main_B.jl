using Pkg
using Ipopt, JuMP
using Dates
using CSV
using DataFrames

println("--- Start Program ---")

#General
tfinal = 8760;

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

# Solar generation 1 MW

gen_solar_av = CSV.read("data/solar1.csv", DataFrame)

# Solar generation 1 MW

gen_wind_av = CSV.read("data/wind1.csv", DataFrame)

#known variables
years = 50;

cost_nuc = 7003 * 1000 + 109*1000 *years + 9.5 *years*tfinal; # 9.5 including fuel

capex_gas = 820 * 1000;
gas_fuel = (0.0292/0.35)*1000; #gas price including eff. in €/MWh 
opex_gas_fix = 20 * 1000 *years;
opex_gas_var = (4.8+gas_fuel) * years;

# Cost solar
solar_life = 30;             #Battery life in years
new_solar = years/solar_life;    # amount of Batteries required 
capex_solar = 1067 * 1000 *new_solar; # Euro per MW
opex_solar = 19 * 1000 *years; # Euro per MW -> but will it last 50 years??? 
#Electrifying (source)

# Cost wind
wind_life = 30;             #Battery life in years
new_wind = years/wind_life;    # amount of Batteries required 
capex_wind = 1296 * 1000 *new_wind; # Euro per MW
opex_wind = 40 * 1000*years; # Euro per MW per year

#Ratio of Renewables over all years
ratioRE = 0.2

#model
m = direct_model(optimizer_with_attributes(Ipopt.Optimizer))
set_optimizer_attributes(m, "tol" => 1e-2, "max_iter" => 10000)
#set_silent(m)

#parameter constraints
@variable(m, P_nuc >= 0)
@variable(m, P_gas >= 0)
@variable(m, gen_gas[1:tfinal] >= 0)
@variable(m, solarSize >= 0)
@variable(m, gen_solar[1:tfinal] >= 0)
@variable(m, windSize >= 0)
@variable(m, gen_wind[1:tfinal] >= 0)
set_start_value(P_nuc, 2000.00)
set_start_value(P_gas, 7000.00)
set_start_value(solarSize, 20000.00)
set_start_value(windSize, 15000.00)
#@variable(m, x[1:tfinal] , Bin)

#objective funktion
@objective(m, Min, cost_nuc * P_nuc + (capex_gas + opex_gas_fix)* P_gas + opex_gas_var * sum(gen_gas[1:tfinal]) + capex_solar * solarSize + opex_solar * solarSize + capex_wind * windSize + opex_wind * windSize ) 



for i = 1:tfinal
    @NLconstraint(m, gen_gas[i] <= P_gas)
    @NLconstraint(m,gen_solar[i] <= gen_solar_av[i,3])
    @NLconstraint(m, gen_wind[i] <= gen_wind_av[i,3])
end
#variable constraints
for i = 1:tfinal
    @NLconstraint(m,P_nuc + gen_gas[i] + solarSize * gen_solar[i] + windSize * gen_wind[i] - demandrow[i, 2] >= -1e-4)
    @NLconstraint(m,P_nuc + gen_gas[i] + solarSize * gen_solar[i] + windSize * gen_wind[i] - demandrow[i, 2] <= 1e-4)
end

@constraint(m, sum(solarSize * gen_solar[i] for i in 1:tfinal) + sum(windSize * gen_wind[i] for i in 1:tfinal)  == ratioRE*sum(demandrow[1:tfinal, 2]))


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
demand_out = demandrow[1:tfinal,2];
overall_opt = DataFrame(hour= 1:tfinal,Demand = demand_out,Nuc_Capacity_MW = nuc_cap_opt_list, Nuc_generation_in_hour=JuMP.value.(P_nuc),Gas_Capacity_MW = gas_cap_opt_list, Gas_generation_in_hour=JuMP.value.(gen_gas),Solar_Capacity_MW = solar_cap_opt_list, Solar_available_in_hour=solar_avalable_opt, Solar_Curtailment_in_hour=solar_curt_opt,Solar_injected_in_hour = solar_gen_inject_opt,wind_Capacity_MW = wind_cap_opt_list, wind_available_in_hour=wind_avalable_opt, wind_Curtailment_in_hour=wind_curt_opt,wind_injected_in_hour = wind_gen_inject_opt)

CSV.write("data/optimal/Optimal_Values_B20.csv", overall_opt)


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