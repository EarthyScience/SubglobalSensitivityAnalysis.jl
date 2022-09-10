"""
    install_R_dependencies(packages; lib = rcopy(R"Sys.getenv('R_LIBS_USER')"))

Install R packages, vector `packages`, into R library, `lib`.
The `lib` directory is created, if it does not exist yet, and prepended to
the R library path. 
`lib` defaults to the user R-library. 

CAUTION: Installing packages to the R user library may interfere with other
R projects, because it changes from where libraries and its versions are loaded.

Alternatively, install into a R-session specific library path, by using
`lib = lib = rcopy(R"file.path(tempdir(),'session-library')")`.
This does not intefere, but needs to be re-done on each new start of R.
"""
function install_R_dependencies(packages; lib = rcopy(R"Sys.getenv('R_LIBS_USER')"))
    # prepend lib path
    new_lib_paths = vcat(lib, setdiff(rcopy(R".libPaths()"), lib))
    rcopy(R".libPaths(unlist($(new_lib_paths)))")
    # check which packages need to be installed
    # edge case of sapply not returning a vector but a scalar
    res_sapply = rcopy(R"sapply($(packages), requireNamespace)")
    is_pkg_installed = res_sapply isa AbstractVector ? res_sapply : SA[res_sapply] 
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

