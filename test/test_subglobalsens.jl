#using RegionalSensitivityAnalysis
#import RegionalSensitivityAnalysis as CP
#using Distributions
#push!(LOAD_PATH, "~/julia/devtools")

parmsModeUpperRows = [
    (:a, LogNormal, 0.1 , 0.5),
    (:b, LogitNormal, 0.3 , 0.9),
]
df_dist = CP.fit_distributions(parmsModeUpperRows)
p0 = Dict(:a => 0.2, :b => 0.4)

@testset "fitDistr tups" begin
    df2 = @inferred CP.fit_distributions(parmsModeUpperRows)
    @test df2 isa DataFrame
    @test all([:par, :dType, :mode, :upper, :dist] .∈ Ref(propertynames(df2)))
    @test df2.dist[2] isa LogitNormal
    # 
    @test_throws Exception CP.fit_distributions([(:a, :not_a_Distribution, 0.001*365 , 0.005*365),])
    @test_throws Exception CP.fit_distributions([(:a, LogNormal, :not_a_number , 0.005*365),])
    @test_throws Exception CP.fit_distributions([(:a, LogNormal, :0.006*365 , 0.005*365),])
end;

@testset "set_reference_parameters" begin
    df2 = copy(df_dist)
    # no b -> missing, key c is irrelevant
    CP.set_reference_parameters!(df2, Dict(:a => 1.0, :c => 3.0))
    @test isequal(df2.ref, [1.0, missing])
end;

@testset "calculate_parbounds" begin
    (par,dist) = df_dist[1,[:par,:dist]]
    x = p0[par]
    (sens_lower, sens_upper, cp_par, cp_sens_lower, cp_sens_upper) = CP.calculate_parbounds(dist, x)
    @test cp_sens_lower == cp_par - 0.1
    @test cp_sens_upper == cp_par + 0.1
    @test sens_lower < x
    @test sens_upper > x
end;

@testset "calculate_parbounds dataframe" begin
    df2 = copy(df_dist)
    CP.set_reference_parameters!(df2, p0)
    CP.calculate_parbounds!(df2)
    @test all([:sens_lower, :sens_upper, :cp_par, :cp_sens_lower, :cp_sens_upper] .∈ Ref(propertynames(df2)))
    #
    # omit ref for parameter b
    CP.set_reference_parameters!(df2, Dict(:a => 0.2))
    CP.calculate_parbounds!(df2)
    @test ismissing(df2.ref[2])
end;

@testset "compute_cp_design_matrix" begin
    df2 = copy(df_dist)
    CP.set_reference_parameters!(df2, p0)
    CP.calculate_parbounds!(df2)
    (cp_design, df_cfopt, path_sens_object) = CP.compute_cp_design_matrix(df2, df2.par, 10)
    np = nrow(df2)
    @test size(cp_design) == ((2*np)*10,2)
end;

df_dist_ext = copy(df_dist)
CP.set_reference_parameters!(df_dist_ext, p0)
CP.calculate_parbounds!(df_dist_ext)
(cp_design, df_cfopt, path_sens_object) = CP.compute_cp_design_matrix(df_dist_ext, df_dist_ext.par, 10)

@testset "transform_cp_design_to_quantiles" begin
    q_design = CP.transform_cp_design_to_quantiles(df_cfopt, cp_design)
    @test size(q_design) == size(cp_design)
end

# for each row compute multiple results
q_design = CP.transform_cp_design_to_quantiles(df_cfopt, cp_design)
fsens = (a,b) -> (;s1 = a + b -1, s2 = a + b -0.5)
res = map(r -> fsens(r...), eachrow(q_design))

@testset "compute_sobol_indices" begin
    target = :s1
    y = [tup[target] for tup in res]
    df_sobol =  CP.compute_sobol_indices(y, path_sens_object, df_cfopt.par)
    @test df_sobol.par == [:a,:b,:a,:b]
    @test df_sobol.index == [:first_order, :first_order, :total, :total]
    @test all([:value, :cf95_lower, :cf95_upper] .∈ Ref(propertynames(df_sobol)))
end

@testset "estimate_subglobal_sobol_indices" begin
    fsens = (a,b) -> (;target1 = a + b -1, target2 = a + b -0.5)
    df_sobol = estimate_subglobal_sobol_indices(fsens, parmsModeUpperRows, p0; n_sample = 10)
    @test nrow(df_sobol) == 8
end
