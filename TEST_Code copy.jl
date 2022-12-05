# Code for exporting to CSV

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

overall_opt = DataFrame(hour= 1:tfinal,Nuc_Capacity_MW = nuc_cap_opt_list, Nuc_generation_in_hour=JuMP.value.(P_nuc),Gas_Capacity_MW = gas_cap_opt_list, Gas_generation_in_hour=JuMP.value.(gen_gas),Solar_Capacity_MW = solar_cap_opt_list, Solar_available_in_hour=solar_avalable_opt, Solar_Curtailment_in_hour=solar_curt_opt,Solar_injected_in_hour = solar_gen_inject_opt,wind_Capacity_MW = wind_cap_opt_list, wind_available_in_hour=wind_avalable_opt, wind_Curtailment_in_hour=wind_curt_opt,wind_injected_in_hour = wind_gen_inject_opt)

CSV.write("data/optimal/Optimal_Values_A.csv", overall_opt)