#!/bin/bash

# fail on first error or unset env variables
set -eu

echo "Beginning setup for building python wheel(s)"

WHEELDIR=/home/nixvoyager-user/wheel
RESULT=/home/nixvoyager-user/output/result
VIRTUALENV_TAR=/home/nixvoyager-user/virtualenv

mkdir -p $RESULT
mkdir $WHEELDIR
mkdir $VIRTUALENV_TAR

# TODO: we should not assume --strip 1 here, but it works
# with all recent virtualenv distributions
cd $VIRTUALENV_TAR
tar -xf $NIXVOYAGER_ARG_virtualEnvSrc --strip 1
$systemPython $VIRTUALENV_TAR/virtualenv.py --never-download _env/

# ran into issues with some virtualenv versions setting the prompt in a container.
# disabling it completely since we don't need it
VIRTUAL_ENV_DISABLE_PROMPT=1 source _env/bin/activate

# make sure we use pip to pre-install any build dependencies needed to build the wheels
for python_build_dep in $(echo $NIXVOYAGER_ARG_pythonBuildDependencies | tr ':' ' ')
do
  # the assumption for now is we either have a directory of whl files (i.e. the output
  # from another package using `mkPythonWheel`), or we have an installable source of some
  # kind (e.g. a `fetchurl { }` containing a python dist of anything pip installable)
  if [ -d $python_build_dep ];
    then
      pip install $python_build_dep/*.whl --no-deps --no-index
    else
      pip install $python_build_dep --no-deps --no-index
    fi
done

cd $WHEELDIR

for source_dist in $(echo $NIXVOYAGER_ARG_sources | tr ':' ' ')
do
  TMP_WHEEL_DIR=$(mktemp --directory --tmpdir="/tmp")

  cd $TMP_WHEEL_DIR
  if [ -d $source_dist ];
  then
    cp -r $source_dist/* $TMP_WHEEL_DIR;
  else
    cp $source_dist $TMP_WHEEL_DIR
  fi

  echo "Building wheel for source '${source_dist}'"

  # NOTE: we could use `$systemPython setup.py bdist_wheel` instead of pip wheel,
  # but pip has more helpful build options (such as --no-deps) and has been
  # consistent so far. it can also build .tar.gz sources without requiring
  # extra steps to untar and find the setup.py file.
  # this command will place the built `.whl` file into $RESULT
  pip wheel --no-index --no-deps $source_dist -v --wheel-dir $RESULT/

done
