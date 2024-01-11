
using SubglobalSensitivityAnalysis
using Test
using Distributions
using DataFrames

paramsModeUpperRows = [
    (:a, LogNormal, 0.1 , 0.5),
    (:b, LogitNormal, 0.3 , 0.9),
    (:nonopt, LogitNormal, 0.3 , 0.9),
]
df_dist = fit_distributions(paramsModeUpperRows)
p0 = Dict(:a => 0.2, :b => 0.4)

@testset "fitDistr tups" begin
    df2 = @inferred fit_distributions(paramsModeUpperRows)
    @test df2 isa DataFrame
    @test all([:par, :dType, :mode, :upper, :dist] .∈ Ref(propertynames(df2)))
    @test df2.dist[2] isa LogitNormal
    # 
    @test_throws Exception fit_distributions([(:a, :not_a_Distribution, 0.001*365 , 0.005*365),])
    @test_throws Exception fit_distributions([(:a, LogNormal, :not_a_number , 0.005*365),])
    @test_throws Exception fit_distributions([(:a, LogNormal, :0.006*365 , 0.005*365),])
end;

@testset "set_reference_parameters" begin
    df2 = copy(df_dist)
    # no b -> missing, key c is irrelevant
    set_reference_parameters!(df2, Dict(:a => 1.0, :c => 3.0))
    @test isequal(df2.ref, [1.0, missing, missing])
end;

using SubglobalSensitivityAnalysis: SubglobalSensitivityAnalysis as CP

@testset "calculate_parbounds" begin
    (par,dist) = df_dist[1,[:par,:dist]]
    x = p0[par]
    (sens_lower, sens_upper, cp_ref, cp_sens_lower, cp_sens_upper) = CP.calculate_parbounds(dist, x)
    @test cp_sens_lower == cp_ref - 0.1
    @test cp_sens_upper == cp_ref + 0.1
    @test sens_lower < x
    @test sens_upper > x
end;

@testset "calculate_parbounds dataframe" begin
    df2 = copy(df_dist)
    CP.set_reference_parameters!(df2, p0)
    CP.calculate_parbounds!(df2)
    @test all([:sens_lower, :sens_upper, :cp_ref, :cp_sens_lower, :cp_sens_upper] .∈ Ref(propertynames(df2)))
    #
    # omit ref for parameter b
    CP.set_reference_parameters!(df2, Dict(:a => 0.2))
    CP.calculate_parbounds!(df2)
    @test ismissing(df2.ref[2])
end;

names_opt = [:a, :b]
df_dist_ext = copy(df_dist)
CP.set_reference_parameters!(df_dist_ext, p0)
CP.calculate_parbounds!(df_dist_ext)
estim=CP.SobolTouati()
df_dist_opt = subset(df_dist_ext, :par => ByRow(x -> x ∈ names_opt))
n_sample = 20
X1 = CP.get_uniform_cp_sample(df_dist_opt, n_sample);
X2 = CP.get_uniform_cp_sample(df_dist_opt, n_sample);
cp_design = generate_design_matrix(SobolTouati(), X1, X2)

@testset "transform_cp_design_to_quantiles" begin
    q_design = CP.transform_cp_design_to_quantiles(df_dist_opt, cp_design)
    @test size(q_design) == size(cp_design)
end

# for each row compute multiple results
q_design = CP.transform_cp_design_to_quantiles(df_dist_opt, cp_design);
fsens = (a,b) -> (;s1 = a + b -1, s2 = a + b -0.5)
res = map(r -> fsens(r...), eachrow(q_design));

@testset "estimate_subglobal_sobol_indices" begin
    fsens = (a,b) -> (;target1 = a + b -1, target2 = a + b -0.5)
    df_sobol = estimate_subglobal_sobol_indices(fsens, paramsModeUpperRows, p0; 
        n_sample = 10, names_opt=[:a,:b])
    @test nrow(df_sobol) == 8
    # repeat without the names_ope
    df_sobol2 = estimate_subglobal_sobol_indices(fsens, df_dist_opt, p0; n_sample = 10)
    @test nrow(df_sobol2) == 8
end;
