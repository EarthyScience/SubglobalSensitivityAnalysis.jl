parmsModeUpperRows = [
    (:a, LogNormal, 0.1 , 0.5),
    (:b, LogitNormal, 0.3 , 0.9),
]
df_dist = df_dist_opt = fit_distributions(parmsModeUpperRows)
p0 = Dict(:a => 0.2, :b => 0.4)
set_reference_parameters!(df_dist, p0)

CP.calculate_parbounds!(df_dist)
n_sample = 10
X1 = CP.get_uniform_cp_sample(df_dist, n_sample);
X2 = CP.get_uniform_cp_sample(df_dist, n_sample);

@testset "generate design matrix" begin
    sens_estimator2 = CP.SobolTouati(
        ;rest = RSobolEstimator("sens_touati2", tempname()*".rds"))
    cp_design = generate_design_matrix(sens_estimator2, X1, X2)
    npar = nrow(df_dist)
    @test size(cp_design) == ((npar+2)*n_sample, npar) 
end;

sens_estimator = SobolTouati()
cp_design = generate_design_matrix(sens_estimator, X1, X2);
q_design = CP.transform_cp_design_to_quantiles(df_dist, cp_design);
fsens = (a,b) -> (;s1 = a + b -1, s2 = a + b -0.5)
res = map(r -> fsens(r...), eachrow(q_design))
target = :s1
y = [tup[target] for tup in res];

@testset "estimate_sobol_indices" begin
    df_sobol = estimate_sobol_indices(sens_estimator, y, df_dist.par)
    @test df_sobol.par == [:a,:b,:a,:b]
    @test df_sobol.index == [:first_order, :first_order, :total, :total]
    @test all([:value, :cf_lower, :cf_upper] .∈ Ref(propertynames(df_sobol)))
end;

@testset "reload_design_matrix" begin
    @test supports_reloading(3) == SupportsReloadingNo()
    @test supports_reloading(sens_estimator) == SupportsReloadingNo()
    @test_throws ErrorException reload_design_matrix(sens_estimator)
    mktempdir() do dir
        tmpfname = joinpath(dir,"sensobject.rds")
        estim2 = SobolTouati(;rest=RSobolEstimator("sens_touati2", tmpfname))
        @test supports_reloading(estim2) == SupportsReloadingYes()
        @test_throws Exception reload_design_matrix(estim2) # from R file not found
        generate_design_matrix(estim2, X1, X2);
        cp_design2 = reload_design_matrix(estim2);
        @test cp_design2 isa Matrix
    end
end;

i_tmp_inspecttrait = () -> begin
    # @code_llvm isnothing(sens_estimator.rest.filename)
    # @code_llvm supports_reloading(sens_estimator.rest) 

    # @code_llvm supports_reloading(estim2.rest) 
    # @code_llvm supports_reloading(estim2) 

    # @code_llvm supports_reloading(sens_estimator) # does not optimize
    # @code_llvm (x -> supports_reloading(x))(sens_estimator)
    # @code_llvm reload_design_matrix(sens_estimator)
end
