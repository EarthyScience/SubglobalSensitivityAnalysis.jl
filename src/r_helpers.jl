function install_R_dependencies(packages; lib = rcopy(R"Sys.getenv('R_LIBS_USER')"))
    # prepend lib path
    new_lib_paths = vcat(lib, setdiff(rcopy(R".libPaths()"), lib))
    rcopy(R".libPaths(unlist($(new_lib_paths)))")
    # check which packages need to be installed
    is_pkg_installed = rcopy(R"sapply($(packages), requireNamespace)")
    all(is_pkg_installed) && return(0)
    pkgs_inst = packages[.!is_pkg_installed]
    @show pkgs_inst
    retcode = rcopy(R"""
        retcode = 0
        packages = $(packages)
        lib = $(lib)
        suppressWarnings(dir.create(lib,recursive=TRUE))
        withCallingHandlers(
            tryCatch({
                install.packages(packages, lib)
            }, error=function(e) {
                retcode <<- 1
            }), warning=function(w) {
                retcode <<- 2
            })
        if (retcode != 0) {
            print("retrying install.packages with method curl")
            retcode <- 0
            withCallingHandlers(
                tryCatch({
                    install.packages(packages, lib, method='curl')
                }, error=function(e) {
                    retcode <<- 1
                }), warning=function(w) {
                    retcode <<- 2
                })
        } 
        retcode
      """)
      Integer(retcode)
end

