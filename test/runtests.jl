
tmpf = () -> begin
    pop!(LOAD_PATH)
    push!(LOAD_PATH, joinpath(pwd(), "test/"))
    push!(LOAD_PATH, expanduser("~/julia/devtools_$(VERSION.major).$(VERSION.minor)"))
end

using Test, SafeTestsets
const GROUP = get(ENV, "GROUP", "All") # defined in in CI.yml
@show GROUP

@time begin
    if GROUP == "All" || GROUP == "Basic"
        #@safetestset "Tests" include("test/test_r_helpers.jl")
        @time @safetestset "test_r_helpers" include("test_r_helpers.jl")
        #@safetestset "Tests" include("test/test_example_funs.jl")
        @time @safetestset "test_example_funs" include("test_example_funs.jl")
        #@safetestset "Tests" include("test/test_SobolSensitivityEstimator.jl")
        @time @safetestset "test_SobolSensitivityEstimator" include("test_SobolSensitivityEstimator.jl")
        #@safetestset "Tests" include("test/test_subglobalsens.jl")
        @time @safetestset "test_subglobalsens" include("test_subglobalsens.jl")
    end
    if GROUP == "All" || GROUP == "JET"
        #@safetestset "Tests" include("test/test_JET.jl")
        @time @safetestset "test_JET" include("test_JET.jl")
        #@safetestset "Tests" include("test/test_aqua.jl")
        @time @safetestset "test_Aqua" include("test_aqua.jl")
    end
end

