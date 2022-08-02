{
  description = "shell flake for VSCode and RStudio";
  inputs = {
    nixpkgs.url = "github:sepiabrown/nixpkgs/rserver_test4"; # rserver init + icu50
    flake-utils.url = "github:numtide/flake-utils";
    nixgl = {
      #url = "github:guibou/nixGL";
      #flake = false;
      url = "github:sepiabrown/nixGL";
      #sha256 = "1g6ycnji10q5dd0avm6bz4lqpif82ppxjjq4x7vd8xihpgg3dm91";
      # flake = false;
      # url = "https://example.org/downloads/source-code.zip";
    };
  };

  outputs = { self, nixpkgs, flake-utils, nixgl }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        #config.allowBroken = true;
      };
    in
      with pkgs; with rPackages;
    let
      #bmis_list = [
      #  R
      #  Rcpp
      #  RcppArmadillo
      #  BiocManager
      #];
      #vbmis = buildRPackage { # rPackages.buildRPackage
      #  name = "vbmis";
      #  src = ./samsungDS/vbmis_1.0.1.tar;
      #  buildInputs = bmis_list;
      #};
      #bmis = buildRPackage { # rPackages.buildRPackage
      #  name = "bmis";
      #  src = ./samsungDS/code/bmis_1.0.1.tar.gz;
      #  buildInputs = bmis_list;
      #};
      rpackage_list = [
      #develop
      devtools
      httr
      librarian
      remotes
      roxygen2

      ##basic
      Biobase
      pacman
      librarian
      tidyverse
      ggplot2
      plotly
      stringr

      ##ML
      mlbench
      lightgbm
      xgboost
      RSSL

      ##OpenClass
      rstan
      GGally
      ggmosaic
      reshape2

      ##DPNB
      #bmis
      #vbmis
      caret
      missForest
      mice
      VIM
      e1071
      mvtnorm
      ROSE
      imbalance
      #rattle_data #broken?
      future
      gridExtra
      reactable

      #vscode
      languageserver
      ];

      customR = rWrapper.override { packages = # pkgs.rWrapper
        rpackage_list;
      };
      #customRStudio = rstudioWrapper.override { packages = # pkgs.rstudioWrapper
      #  rpackage_list;
      #};
      customRStudioForServer = rstudio-server.overrideAttrs (old: { 
        postFixup = ''
          patchelf --add-needed ${lib.getLib gfortran6.cc}/lib/libgfortran.so.3 $out/bin/rsession
          patchelf --add-needed ${lib.getLib pcre2}/lib/libpcre2-8.so.0 $out/bin/rsession
          patchelf --add-needed ${lib.getLib xz}/lib/liblzma.so.5 $out/bin/rsession
          patchelf --add-needed ${lib.getLib bzip2}/lib/libbz2.so.1 $out/bin/rsession
          patchelf --add-needed ${lib.getLib icu50}/lib/libicuuc.so.50 $out/bin/rsession
          patchelf --add-needed ${lib.getLib icu50}/lib/libicui18n.so.50 $out/bin/rsession
          patchelf --add-needed ${lib.getLib gcc.cc.lib}/lib/libgomp.so.1 $out/bin/rsession
        '';
      });
      customRStudioServer = rstudioServerWrapper.override { 
        rstudio = customRStudioForServer;
        packages = rpackage_list; #[ e1071 lightgbm ]; 
      };
      homeDir = "/data/sepiabrown/OpenClass";
      rserver_conf = builtins.toFile "rserver.conf" ''
server-data-dir=${homeDir}/rstudio-server
database-config-file=${homeDir}/rstudio-server/database.conf
www-port=5555
# rserver --config-file ${homeDir}/rstudio-server/rserver.conf
      '';
      database_conf = builtins.toFile "database.conf" ''
provider=sqlite
directory=${homeDir}/rstudio-server
      '';
    in {
    inherit pkgs;
    packages.rstudio-server = customRStudioServer;
    devShell = mkShell { # see cowsay; pkgs.mkShell
      nativeBuildInputs = [ bashInteractive ]; # pkgs.bashInteractive
      buildInputs =
      [
        # git push glibc-2.33 not found error when nixos version is 21.05. fixed by changing nixos to unstable
        customR # for Rscript
        #customRStudio
        customRStudioServer
        gdb
        nixgl.defaultPackage.${system} # pkgs.system
        #(lib.getLib gfortran6.cc.lib)
        #cowsay
        #cowsay # pkgs.cowsay, pkgs.rPackages.cowsay both exist. Thus the order: 'with pkgs.rPackages; with pkgs;' revert to `with pkgs; with rPackages;`
      ];
      shellHook = 
      #let 
      #  PROJECT_ROOT = builtins.getEnv "pwd";# builtins.toString ./.; # gets /nix/store
      #in
      ''
        #export LD_LIBRARY_PATH=$LD_LIBRARY_PATH${lib.getLib xz}:
        #export PPP=${lib.getLib gfortran6.cc}:${gfortran6.cc.lib}
        export XDG_CONFIG_HOME=''${PWD}
        export XDG_RUNTIME_DIR=''${PWD}
        mkdir -p ''${PWD}/rstudio/RStudio
        export RSTUDIO_CHROMIUM_ARGUMENTS="--disable-gpu" # needed for 'nixGL rstudio' with 
        if [ -z "$RSTUDIO_CHROMIUM_ARGUMENTS" ]
        then
          ln -sf ''${PWD}/desktop.ini ''${PWD}/rstudio/RStudio/desktop.ini
        else
          ln -sf ''${PWD}/desktop_fixed.ini ''${PWD}/rstudio/RStudio/desktop.ini
        fi
        mkdir -p ''${PWD}/rstudio-server
        cp ${rserver_conf} ''${PWD}/rstudio-server/rserver.conf
        cp ${database_conf} ''${PWD}/rstudio-server/database.conf
      '';
    };
  });
}
# How to use RStudio remotely
#
# rserver --config-file /home/sepiabrown/vbmis_4th_year/rstudio-server/rserver.conf
# (deprecated) ssh -X -p 7777 -t sepiabrown@snubayes.duckdns.org '.cargo/bin/nix-user-chroot ~/.nix bash -l'
