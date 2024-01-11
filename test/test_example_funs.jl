using SubglobalSensitivityAnalysis
using Test

@testset "ishigami_fun" begin
    ans = ishigami_fun(0.2,0.3,0.6)
    @test isapprox(ans, 0.81; atol=0.1)
end

