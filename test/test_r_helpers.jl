i_debug = () -> begin
    packages = pkgs_inst = ["sensitivity","units","measurements"]
    pkgs_inst = ["units","measurements"]
    lib = rcopy(R"file.path(tempdir(),'session-library')")

    rcopy(R"str($(packages))")
    rcopy(R"remove.packages(c('measurements'))")
    rcopy(R"remove.packages(c('measurements'),$(lib))")
    retcode = install_R_dependencies(["measurements"]; lib)

    rcopy(R"system.file(package='measurements')")
    rcopy(R"requireNamespace('measurements')")
    rcopy(R"tmpf = function(){ return(1) }; tmpf()")

    new_lib_paths = vcat(lib, setdiff(rcopy(R".libPaths()"), lib))
    rcopy(R".libPaths(unlist($(new_lib_paths)))")
    rcopy(R".libPaths()")

    install_R_dependencies(packages; lib)
    readdir(lib)
end

@testset "install packages to temporary directory" begin
    #packages = pkgs_inst = ["sensitivity","units","measurements"]
    packages = ["sensitivity"]
    lib = rcopy(R"file.path(tempdir(),'session-library')")
    retcode = install_R_dependencies(packages; lib)
    @test retcode == 0
end

