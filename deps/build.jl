using CxxWrap
using BinaryProvider
using Base.Filesystem
import Pkg
using Pkg: depots1
import CMake

using GMP_jll
using MPFR_jll
using FLINT_jll
using boost_jll
using perl_jll
using polymake_jll
using Ninja_jll

user_dir = ENV["POLYMAKE_USER_DIR"] = abspath(joinpath(depots1(),"polymake_user"))
if Base.Filesystem.isdir(user_dir)
  del = filter(i -> Base.Filesystem.isdir(i) && startswith(i, "wrappers."), readdir(user_dir))
  for i in del
    Base.Filesystem.rm(user_dir * "/" * i, recursive = true)
  end
end

minimal_polymake_version = v"4.0"

perl() do perl_path
  polymake() do polymake_path
  polymake_config() do polymake_config_path
    ninja() do ninja_path

      pm_version = read(`$perl_path $polymake_config_path --version`, String) |> chomp |> VersionNumber
      if pm_version < minimal_polymake_version
        error("Polymake version $pm_version is older than minimal required version $minimal_polymake_version")
      end

      pm_includes = chomp(read(`$perl_path $polymake_config_path --includes`, String))
      pm_cflags = chomp(read(`$perl_path $polymake_config_path --cflags`, String))
      pm_ldflags = chomp(read(`$perl_path $polymake_config_path --ldflags`, String))
      pm_libraries = chomp(read(`$perl_path $polymake_config_path --libs`, String))
      pm_cxx = chomp(read(`$perl_path $polymake_config_path --cc`, String))

      # Remove the -I prefix of all includes
      pm_include_dirs = join(map(i -> i[3:end], split(pm_includes)), " ")

      # add includes and lib dirs for dependencies
      libdirs = polymake_jll.LIBPATH_list
      foreach(libdirs) do libdir
        pm_ldflags *= " -L" * libdir
        pm_include_dirs *= " " * replace(libdir, r"/lib[^/]*$" => s"/include")
      end

      jlcxx_cmake_dir = joinpath(dirname(CxxWrap.jlcxx_path), "cmake", "JlCxx")

      julia_exec = joinpath(Sys.BINDIR , "julia")

      cd(joinpath(@__DIR__, "src"))

      include("type_setup.jl")

      json_script = joinpath(@__DIR__,"rules","apptojson.pl")
      json_folder = joinpath(@__DIR__,"json")

      if Sys.islinux() && Sys.BINDIR == "/usr/bin"
         # remove system-paths from LD_LIBRARY_PATH
         syslibdir = abspath(joinpath(Sys.BINDIR,Base.LIBDIR))
         libdirs = filter(s->(s!=syslibdir),map(abspath,libdirs))
      end
      ENV[polymake_jll.LIBPATH_env] = join(libdirs,":")

      mkpath(json_folder)
      run(`$perl_path $polymake_path --iscript $json_script $json_folder`)

      run(`$(CMake.cmake) -DJulia_EXECUTABLE=$julia_exec -DJlCxx_DIR=$jlcxx_cmake_dir -Dpolymake_includes=$pm_include_dirs -Dpolymake_ldflags=$pm_ldflags -Dpolymake_libs=$pm_libraries -Dpolymake_cflags=$pm_cflags -DCMAKE_CXX_COMPILER=$pm_cxx  -DCMAKE_INSTALL_LIBDIR=lib .`)
      cpus = max(div(Sys.CPU_THREADS,2), 1)
      run(`make -j$cpus`)
      
    end
  end
  end
end
