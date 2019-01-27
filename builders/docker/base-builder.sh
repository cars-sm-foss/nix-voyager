#!/bin/bash
set -e
# use the base directory name in the nix store as the
# base of the build image name, alternatively we could
# use the plain hash to have a single name (repo) with
# a changing tag depending on the nix store hash
BUILD_ID="${out##*/}"
DOCKER_IMG_NAME="$BUILD_ID-build-env"
DOCKER_CONTEXT="docker-context"
DOCKER_PRODUCT="docker-product"

dockerWrapper(){
    docker $*
}

ARGS_DIR="\$HOME/_arguments"
CUSTOM_ARGS_NAMES_FILE="_arg_names"
CUSTOM_ARGS_FILE="_args"

configureBuildArgument(){
    local arg_name=$1
    local arg_value="$2"
    declare -a commands
    echo "Configuring build argument '$arg_name'"
    if [[ -x $arg_value ]]; then
	# if it exists in the filesystem we assume is a file
	local arg_path_dest="$ARGS_DIR/$(basename $arg_value)"
	cp -r $arg_value $DOCKER_CONTEXT
	# forge the dockerfile commands
	commands=("${commands[@]}" "COPY \"$(basename $arg_value)\" \"$arg_path_dest\"")
	commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name \"$arg_path_dest\"")
    else
	if [[ $arg_value == "1" ]]; then # we asume the intention was "true"
	    commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name true")
	elif [[ -z $arg_value ]]; then
	    commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name false")
	elif [[ $arg_value =~ "^[0-9]+$" ]]; then # is an integer
	    commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name $arg_value")
	else # assume the original value was a string
	    commands=("${commands[@]}" "ENV UNHOLY_ARG_$arg_name '\"$arg_value\"'")
	fi

    fi
    echo "$arg_name" >> $CUSTOM_ARGS_NAMES_FILE
    # append it to the global var
    printf '%s\n' "${commands[@]}"  >> $CUSTOM_ARGS_FILE
}


setupCustomArguments(){
    # we are consuming the argument two at a time,
    # on a SUB-SHELL therefore... we are not sharing
    # the same variable space (in terms of writing into
    # the one at the top-level), all the argument
    # processing is done indirectly by appending to
    # CUSTOM_ARGS_NAMES_FILE and CUSTOM_ARGS_FILE
    echo $buildArgs | sed 's/ /\n/g' | {
	local arg_name
	local arg_value
	while read arg_name
	do
	    read arg_value
	    configureBuildArgument $arg_name "$arg_value"
	done
    }
    local names=$(cat $CUSTOM_ARGS_NAMES_FILE | tr "\n" " " | head -c -1)
    echo "ENV UNHOLY_ARGUMENTS \"$names\"" >>  $CUSTOM_ARGS_FILE
}


setupNixBinaryInstaller(){
    if [[ $nixInstallerComp == ".tar.bz2" ]]; then
	cp $nixInstaller nix-installer.tar.bz2
	local nix_dir_name=$(tar -tjf nix-installer.tar.bz2 | head -1 | cut -f1 -d"/")
	tar -xjf nix-installer.tar.bz2
	mv $nix_dir_name $DOCKER_CONTEXT/nix-binary-installer
    elif [[ -z $nixInstallerComp ]]; then # assume is a directory
	cp -R $nixInstaller $DOCKER_CONTEXT/nix-binary-installer
    else
	echo "Unable to determine how to obtain the nix binary installer" > /dev/stderr
	exit 1
    fi
}


makeDockerBuild(){
    mkdir $DOCKER_CONTEXT
    #cp -r $unholySrc $DOCKER_CONTEXT/unholy
    cp $dockerFile $DOCKER_CONTEXT/Dockerfile
    # this can be a single file or a directory with default.nix
    cp -r $unholyExpression $DOCKER_CONTEXT/unholy-expression
    cp $entryPoint $DOCKER_CONTEXT/entrypoint.sh
    cp $buildScript $DOCKER_CONTEXT/build.sh
    setupNixBinaryInstaller
    setupCustomArguments
    chmod +w $DOCKER_CONTEXT/Dockerfile
    # get the dockerfile fragment configuration of the
    # custom arguments, and remove the last line break
    CUSTOM_ARGS="$(cat $CUSTOM_ARGS_FILE | head -c -1)"
    substituteInPlace $DOCKER_CONTEXT/Dockerfile \
                      --subst-var out \
                      --subst-var targetSystemBuildDependencies \
		      --subst-var CUSTOM_ARGS \
                      --subst-var ARGS_DIR
    echo "Final dockerfile"
    echo "============================"
    cat $DOCKER_CONTEXT/Dockerfile
    echo "============================"
    pushd $DOCKER_CONTEXT
    dockerWrapper build -t $DOCKER_IMG_NAME .
    popd
}

extractBuildFromDockerImage(){
    mkdir $DOCKER_PRODUCT
    dockerWrapper run --rm "$DOCKER_IMG_NAME" tar  > build.tar
    tar --directory $DOCKER_PRODUCT --extract -f build.tar
    # we have to make writiable some of the directories
    # that are comming from the tar, because they were
    # extracted from a nix store (with read-only on
    # pretty much everything)
    chmod +w $DOCKER_PRODUCT
    if [[ -e $DOCKER_PRODUCT/nix-support ]]; then
        chmod +w $DOCKER_PRODUCT/nix-support/
        mv $DOCKER_PRODUCT/nix-support $out/nix-support/in-docker
        local hydra_products_in_docker=$out/nix-support/in-docker/hydra-build-products
        if [[ -e $hydra_products_in_docker ]]; then
            # copy over the products from the docker build
            # that were built in our 'out' path
            grep "$out" $hydra_products_in_docker >> $HYDRA_BUILD_PRODUCTS_FILE
        fi
    fi
    # if we have an internal log, copy it
    if [[ -e $DOCKER_PRODUCT/var/log ]]; then
        mkdir -p $out/var/log/in-docker
        chmod +w $DOCKER_PRODUCT/var $DOCKER_PRODUCT/var/log
        mv $DOCKER_PRODUCT/var/log/* $out/var/log/in-docker/
        rm -rf $DOCKER_PRODUCT/var/log/
    fi
    cp -a $DOCKER_PRODUCT/* $out/

    if [[ -n "$keepBuildImage" ]]; then
        echo "Keeping build image: '$DOCKER_IMG_NAME'"
    else
        dockerWrapper image rm "$DOCKER_IMG_NAME"
    fi
}


makeDockerBuild && extractBuildFromDockerImage