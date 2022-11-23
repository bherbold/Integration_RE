using Pkg
using Ipopt, JuMP
using Dates
using CSV
using DataFrames

#Read Data
#demand start at (2,3:27) (every day with its hours is a row)
df = DateFormat("dd/mm/yyyy");
demand = CSV.read("Demanda_d_energia_el_ctrica_hor_ria_a_Catalunya_per_MWh.csv", DataFrame)
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
    

end # The demand is now stored for every hour in a (8760,2) Matrix

for i = 1:8760
    if demandrow.Demand[i] == 0
        #demandrow.Demand[i] = demandrow.Demand[i-1]
        delete!(demandrow,[i])
    end
end

#delete!(demandrow,[1])
#lastElement = demandrow[size(demandrow,1),2]
#push!(demandrow, (size(demandrow,1) + 1, lastElement))

# Solar generation 1 MW

gen_solar_av = CSV.read("solar1.csv", DataFrame)


# Solar generation 1 MW

gen_wind_av = CSV.read("wind1.csv", DataFrame)

#known variables
years = 50;

capex_nuc = 3600000;
opex_nuc = 20*8760*years;
#cost_nuc = 1
P_nuc_old = 2*1000;

capex_gas = 823000;
opex_gas = 150*years;
P_gas_old = 3*700;

# Cost solar
capex_solar = 900000; # Euro per MW
opex_solar = 17000*years; # Euro per MW -> but will it last 50 years??? 
#Electrifying (source)

# Cost wind

capex_wind = 1000000; # Euro per MW
opex_wind = 40000*years; # Euro per MW per year

#model
m = Model(Ipopt.Optimizer)

#parameter constraints
@variable(m, P_nuc >= 0)
@variable(m, P_gas >= 0)
@variable(m, gen_gas[1:8760] >= 0)
@variable(m, solarSize >= 0)
@variable(m, gen_solar[1:8760] >= 0)

@variable(m, windSize >= 0)
@variable(m, gen_wind[1:8760] >= 0)




#@variable(m, x[1:8760] , Bin)

#objective funktion
@objective(m, Min, opex_nuc* (P_nuc_old + P_nuc) + capex_nuc * P_nuc + capex_gas * P_gas + opex_gas * sum(gen_gas[1:8760]) + capex_solar * solarSize + opex_solar * solarSize + capex_wind * windSize + opex_wind * windSize ) 



for i = 1:8760
    @NLconstraint(m, gen_gas[i] <= P_gas + P_gas_old)
    @NLconstraint(m,gen_solar[i] <= gen_solar_av[i,3])
    @NLconstraint(m, gen_wind[i] <= gen_wind_av[i,3])
end
#variable constraints
for i = 1:8760

    @NLconstraint(m,P_nuc_old + P_nuc + gen_gas[i] + solarSize * gen_solar[i] + windSize * gen_wind[i] == demandrow[i, 2])
end

#@constraint(m, maximum(gen_gas,1) == P_gas)


#@NLconstraint(m, eq10, marginal_cost == 180 + 10 * G_bio)

optimize!(m)

hourInvest = 12

println("P_nuc NEW:")
println(JuMP.value.(P_nuc))
println("P_gas NEW:")
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