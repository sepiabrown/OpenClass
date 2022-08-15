{
  description = "shell flake for VSCode and RStudio";
  inputs = {
    nixpkgs.url = "github:sepiabrown/nixpkgs/rserver_test4"; # rserver init + icu50
    nixos_2111.url = "nixpkgs/nixos-21.11";
    #nixpkgs_local.url = "/Users/bayeslab/SW/OpenClass/nixpkgs";
    #nixpkgs_local.url = "path:../nixpkgs"; # relative path deprecated
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

  outputs = inputs: with inputs;#{ self, nixpkgs, flake-utils, nixgl }:
    flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.allowUnsupportedSystem = true;
        #config.allowBroken = true;
        overlays = [
          (self: super: {
            libsForQt512 = super.libsForQt512.overrideScope' (qt5self: qt5super: {  
              qtwebengine = qt5super.qtwebengine.overrideAttrs (oldAttrs: {  
                # qtwebengine : Apple is non case-sensitive. VERSION file interfere with version.h while building
                postPatch = oldAttrs.postPatch + self.lib.optionalString self.stdenv.isDarwin ''
                  mv src/3rdparty/chromium/third_party/libsrtp/VERSION src/3rdparty/chromium/third_party/libsrtp/VERSION.txt
                '';
              });  
            });
            rstudio = (super.rstudio.override {
              boost = nixos_2111.legacyPackages.x86_64-darwin.boost;
            }).overrideAttrs (old: {
              cmakeFlags = # old.cmakeFlags ++
              [
                "-DRSTUDIO_TARGET=Desktop"
                "-DCMAKE_BUILD_TYPE=Release"

                "-DQT_QMAKE_EXECUTABLE=${self.qt512.qttools.dev}/bin/qmake" ### macdeployqt found at qttools not qmake
                #"-DQT_QMAKE_EXECUTABLE=${self.qt512.qmake}/bin/qmake" ### Wrong

                #"-DTEST1=${super.rstudio}"
                #"-DTEST1=${self.vulkan-loader}"
                #"-DTEST2=${self.qt512.qtbase.bin}/bin/qmake" ### Wrong
                #"-DTEST3=${self.qt512.qtbase.out}/bin/qmake" ### Wrong
                #"-DTEST4=${self.qt512.qtbase}/bin/qmake" ### Wrong
                #"-DTEST4=${self.qt512.qmake}/bin/qmake" ### Wrong
                #"-DRSTUDIO_USE_SYSTEM_SOCI=ON"
                #"-DRSTUDIO_USE_SYSTEM_BOOST=ON"
                "-DRSTUDIO_USE_SYSTEM_YAML_CPP=ON" # Needed. search DYAML_CPP_INCLUDE_DIR in this file.
                "-DPANDOC_VERSION=${self.pandoc.version}"
                "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}/lib/rstudio"

                "-DLIBR_LIBRARIES=${self.lib.getLib self.R}/lib/R"
                "-DRSTUDIO_CRASHPAD_ENABLED=FALSE"
                #"-DCMAKE_CXX_FLAGS=-H"
              ];
                #"-DBoost_USE_STATIC_LIBS=OFF" # Doesn't work. Use substituteInPlace
                #"-DYAML_CPP_INCLUDE_DIR=${self.lib.getLib self.libyamlcpp}/include" # Better for find_package() enabled by -DRSTUDIO_USE_SYSTEM_YAML_CPP=ON to find packages because it finds packages for different OS.
              postPatch = # old.postPatch +
              ''
                substituteInPlace src/cpp/core/r_util/REnvironmentPosix.cpp --replace '@R@' '${self.R}/lib/R'
                substituteInPlace src/gwt/build.xml \
                  --replace '/usr/bin/node' '${self.nodejs}/bin/node'
                substituteInPlace src/cpp/core/libclang/LibClang.cpp \
                  --replace '@libclang@' ${self.llvmPackages.libclang.lib} \
                  --replace '@libclang.so@' ${self.llvmPackages.libclang.lib}/lib/libclang.so
                substituteInPlace src/cpp/session/include/session/SessionConstants.hpp \
                  --replace "bin/pandoc" "${self.pandoc}/bin/pandoc"

                sed -e '/set(Boost_USE_STATIC_LIBS/a set(Boost_USE_STATIC_LIBS OFF)' -i src/cpp/CMakeLists.txt
                sed -e '/set(SOCI_LIBRARY_DIR/a set(SOCI_LIBRARY_DIR "${self.soci}/lib")' -i src/cpp/CMakeLists.txt

                substituteInPlace src/cpp/core/r_util/REnvironmentPosix.cpp --replace '/Library/Frameworks/R.framework/Resources' '${self.R}/lib/R'
                '';
                #substituteInPlace src/cpp/core/r_util/RVersionsPosix.cpp --replace '#define kRFrameworkVersions "/Library/Frameworks/R.framework/Versions"' '#define kRFrameworkVersions "${self.R}"'
                #substituteInPlace src/cpp/core/r_util/RVersionsPosix.cpp --replace 'if (!versionPath.isHidden() && (versionPath.getFilename() != "Current"))' 'if (!versionPath.isHidden() && (versionPath.getFilename() == "lib"))'
                #substituteInPlace src/cpp/core/r_util/RVersionsPosix.cpp --replace 'FilePath rHomePath = versionPath.completeChildPath("Resources");' 'FilePath rHomePath = versionPath.completeChildPath("R");'
                #substituteInPlace src/cpp/desktop/CMakeLists.txt \
                #  --replace 'install(CODE "execute_process(COMMAND install_name_tool -add_rpath \"@executable_path/../Frameworks\" \"''${RSTUDIO_APP_BIN}\")")' ""
              postInstall = ''
                echo "#################################"
                echo "Start"
                mkdir -p $out/bin $out/share
                mkdir -p $out/share/icons/hicolor/48x48/apps
                ln $out/lib/rstudio/RStudio.app/Contents/Resources/www/images/rstudio.png $out/share/icons/hicolor/48x48/apps
                for f in {diagnostics,rpostback,rstudio}; do
                  ln -s $out/lib/rstudio/RStudio.app/Contents/MacOS/$f $out/bin
                done
                for f in .gitignore .Rbuildignore LICENSE README; do
                  find . -name $f -delete
                done
                rm -r $out/lib/rstudio/RStudio.app/Contents/Resources/{INSTALL,COPYING,NOTICE,README.md,SOURCE,VERSION}
                rm -r $out/lib/rstudio/RStudio.app/Contents/MacOS/{pandoc/pandoc,pandoc}
                cp -a src/cpp/desktop/RStudio.app/Contents/MacOS/RStudio $out/lib/rstudio/RStudio.app/Contents/MacOS/RStudio

                echo "Fin"
                echo "#################################"
                echo "#################################"
              '';
                #install_name_tool -change @executable_path/../Frameworks/libQt5Core.5.dylib ${self.qt512.qtbase.out}/lib/libQt5Core.5.dylib $out/lib/rstudio/RStudio.app/Contents/MacOS/RStudio
                /* 
                pwd
                echo $PWD
                echo "$PWD"
                # All works
                */
            });
            rPackages = super.rPackages.override {
              overrides = {
                kernlab = super.rPackages.kernlab.overrideDerivation (old: {
                  buildInputs = old.buildInputs ++ self.lib.optionals self.stdenv.isDarwin [ self.libiconv ];
                });
                bnlearn = super.rPackages.bnlearn.overrideDerivation (old: {
                  buildInputs = old.buildInputs ++ self.lib.optionals self.stdenv.isDarwin [ self.libiconv ];
                });
                conquer = super.rPackages.conquer.overrideDerivation (old: {
                  buildInputs = old.buildInputs ++ self.lib.optionals self.stdenv.isDarwin [ self.libiconv ];
                });
                lmtest = super.rPackages.lmtest.overrideDerivation (old: {
                  buildInputs = old.buildInputs ++ self.lib.optionals self.stdenv.isDarwin [ self.libiconv ];
                });
                tmvnsim = super.rPackages.tmvnsim.overrideDerivation (old: {
                  buildInputs = old.buildInputs ++ self.lib.optionals self.stdenv.isDarwin [ self.libiconv ];
                });
                Hmisc = super.rPackages.Hmisc.overrideDerivation (old: {
                  buildInputs = old.buildInputs ++ self.lib.optionals self.stdenv.isDarwin [ self.libiconv ];
                });
              };
            };
          })
        ];
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
      #RSSL #kernlab : libiconv

      ##OpenClass
      rstan # put gettext in the devShell for stan object compilation
      GGally
      ggmosaic
      reshape2
      Hmisc
      psych

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
      #imbalance #bnlearn : libiconv
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
      customRStudio = rstudioWrapper.override { packages = # pkgs.rstudioWrapper
        rpackage_list;
      };
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
    #inherit pkgs customR customRStudio rstudio pkgs_2111;
    packages.rstudio-server = customRStudioServer;
    devShell = mkShell { # see cowsay; pkgs.mkShell
      nativeBuildInputs = [
        bashInteractive
      ];
      packages = [
        customR
        customRStudio
        #customRStudioServer
        #libintl
        gettext # must needed for rstan
        #gdb
        #nixgl.defaultPackage.${system} # pkgs.system
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
        cp -f ${rserver_conf} ''${PWD}/rstudio-server/rserver.conf
        cp -f ${database_conf} ''${PWD}/rstudio-server/database.conf
      '';
    };
  });
}
# How to use RStudio remotely
#
# rserver --config-file /home/sepiabrown/vbmis_4th_year/rstudio-server/rserver.conf
# (deprecated) ssh -X -p 7777 -t sepiabrown@snubayes.duckdns.org '.cargo/bin/nix-user-chroot ~/.nix bash -l'
