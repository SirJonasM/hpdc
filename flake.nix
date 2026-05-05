{
  description = "High Performance and Distributed Computing Repo";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;

      # Helper to build a single typst folder with custom naming
      buildExercise =
        dirName:
        let
          # Extracts the number from "exercise-01" -> "01"
          # This assumes your folders are named "exercise-XX"
          exNumber = lib.last (lib.splitString "-" dirName);
          outputName = "hpdc-${exNumber}.pdf";
        in
        pkgs.stdenv.mkDerivation {
          pname = dirName;
          version = "0.1.0";
          src = ./.;

          buildInputs = [ pkgs.typst ];

          buildPhase = ''
            cd ${dirName}
            # Compile main.typ into the specifically formatted hpdc-XX.pdf
            typst compile main.typ ${outputName}
          '';

          installPhase = ''
            mkdir -p $out
            cp ${outputName} $out/
          '';
        };

      # Automatically find directories named "exercise-*" containing "main.typ"
      exerciseDirs = builtins.filter (
        name: (lib.hasPrefix "exercise-" name) && (builtins.pathExists (./. + "/${name}/main.typ"))
      ) (builtins.attrNames (builtins.readDir ./.));

      exercisePackages = lib.genAttrs exerciseDirs (name: buildExercise name);
      new-exercise = pkgs.writeShellScriptBin "new-exercise" ''
                # Direnv sets the DIRENV_DIR variable. 
                # We strip the leading '-' to get the actual path.
                PROJECT_ROOT="''${DIRENV_DIR#-}"

                # Fallback: if script is run outside direnv, use git
                if [ -z "$PROJECT_ROOT" ]; then
                  PROJECT_ROOT=$( ${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd )
                fi

                echo "Creating new exercise from $PROJECT_ROOT ..."
        		EX="test"
        		mkdir $EX
        		mkdir $EX/code
        		mkdir $EX/plots
        		mkdir $EX/abgabe
        		mkdir $EX/code/mpi
        		mkdir $EX/code/plot
        		mkdir $EX/code/data

        		cp backup/main.typ $EX/main.typ
        		cp backup/main.py $EX/code/plot/main.py

        		unzip backup/template.zip  -d $EX/code/mpi
        	  '';

      # Define the sync script as a standalone executable
      sync-script = pkgs.writeShellScriptBin "sync-project" ''
        # Direnv sets the DIRENV_DIR variable. 
        # We strip the leading '-' to get the actual path.
        PROJECT_ROOT="''${DIRENV_DIR#-}"

        # Fallback: if script is run outside direnv, use git
        if [ -z "$PROJECT_ROOT" ]; then
          PROJECT_ROOT=$( ${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || pwd )
        fi

        echo "🚀 Syncing from $PROJECT_ROOT to HPC..."

        # Perform rsync using the absolute path of the project root
        ${pkgs.rsync}/bin/rsync -azP \
          --exclude='.git/' \
          --exclude='flake.*' \
          --exclude='*.typ' \
          --exclude='*.pdf' \
          --exclude='backup/' \
          --exclude='.direnv/' \
          --exclude='*.png' \
          --exclude='*.svg' \
          --exclude='.cache/' \
          --exclude='.envrc' \
          --exclude='.gitignore' \
          --exclude='.venv' \
          --exclude='compile_commands.json' \
          "$PROJECT_ROOT/" "hpc:/csghome/hpdc06/jonas/exercises/"

        echo "✅ Sync complete."
      '';

    in
    {
      # Output packages: nix build .#exercise-01 or nix build
      packages.${system} = exercisePackages // {
        default = pkgs.symlinkJoin {
          name = "all-exercises";
          paths = builtins.attrValues exercisePackages;
        };
      };

      devShells.${system} = {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            openmpi
            rsync
            sync-script
            new-exercise
            bear
            typst
            (python3.withPackages (
              ps: with ps; [
                pandas
                matplotlib
                numpy
              ]
            ))
          ];

          shellHook = ''
                      echo "--- MPI Development Shell ---"
            		  echo "Commands: "
            		  echo "- sync-project"
            		  echo "- new-exercise"
          '';
        };
      };
	  ci = pkgs.mkShell {
		buildInputs = [ pkgs.typst ];
		shellHook = '' echo --- CI Build Shell ---'';
	  };
    };
}
